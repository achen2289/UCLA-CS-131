from collections import defaultdict
import json
import sys
import time

import aiohttp
import asyncio

LOG_FILE_NAME = "global_log.log"
LOG_FILE = None
PORT_NOS = [15200, 15201, 15202, 15203, 15204]
# PORT_NOS = [10000, 10001, 10002, 10003, 10004]
SERVER_NAME = None
API_KEY = "nah get yo own"

CLIENTS = {}

SERVERS = {
    "Bailey": PORT_NOS[0],
    "Bona": PORT_NOS[1],
    "Campbell": PORT_NOS[2],
    "Clark": PORT_NOS[3],
    "Jaquez": PORT_NOS[4],
}

CONNECTIONS = {
    "Clark": ["Jaquez", "Bona"],
    "Campbell": ["Bailey", "Bona", "Jaquez"],
    "Bona": ["Bailey"],
}

CONNECTIONS = defaultdict(list, CONNECTIONS)

# Update for bidirectional connections
for serv, conns in CONNECTIONS.copy().items():
    for conn in conns:
        if serv not in CONNECTIONS[conn]:
            CONNECTIONS[conn].append(serv)


def isfloat(num):
    """Taken from online.
    
    https://www.programiz.com/python-programming/examples/check-string-number"""
    try:
        float(num)
        return True
    except ValueError:
        return False


def is_valid_IAMAT(msg):
    content = msg.split(" ")
    if len(content) != 4:
        return False
    if not isfloat(content[3]):
        return False
    coords = content[2].replace("-", "+")
    coords_split = list(filter(None, coords.split("+")))
    if len(coords_split) != 2 or not isfloat(coords_split[0]) or not isfloat(coords_split[1]):
        return False
    return True


def is_valid_WHATSAT(msg):
    content = msg.split(" ")
    if len(content) != 4:
        return False
    _, _, radius, num_results = content
    if not isfloat(radius) or not isfloat(num_results):
        return False
    if int(radius) < 0 or int(radius) > 50:
        return False
    if int(num_results) < 0 or int(num_results) > 20:
        return False
    return True
    

def get_request_type(msg):
    if msg.find("IAMAT") == 0 and is_valid_IAMAT(msg):
        return "IAMAT"
    if msg.find("WHATSAT") == 0 and is_valid_WHATSAT(msg):
        return "WHATSAT"
    if msg.find("UPDATE") == 0:
        return "UPDATE"
    return "INVALID"


def get_lat_and_long(location):
    signs = []
    for i, coord in enumerate(location):
        if coord == "+" or coord == "-":
            signs.append(i)

    if len(signs) != 2:
        return None

    if 0 not in signs or (len(location) - 1) in signs:
        return None

    sign_0, sign_1 = signs
    latitude = location[sign_0 : sign_1]
    longitude = location[sign_1:]

    return latitude, longitude


async def make_api_request(latitude, longitude, radius, num_results):
    async with aiohttp.ClientSession() as session:
        base = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
        location = f"{latitude}%2C{longitude}"

        endpoint = f"{base}?location={location}&radius={radius}&key={API_KEY}"
        async with session.get(endpoint) as resp:
            places = await resp.json()
        
        places["results"] = places["results"][:num_results]
        return places


async def flood(message):
    for connection in CONNECTIONS[SERVER_NAME]:
        LOG_FILE.write(f"Flooding from {SERVER_NAME} to {connection}.\n")
        try:
            _, writer = await asyncio.open_connection("127.0.0.1", SERVERS[connection])
            LOG_FILE.write(f"Successfully connected from {SERVER_NAME} to {connection}.\n")
            
            writer.write(message.encode())
            await writer.drain()

            writer.close()
            await writer.wait_closed()
            LOG_FILE.write(f"Flooding from {SERVER_NAME} to {connection} successful.\n")
        except Exception as e:
            LOG_FILE.write(str(e))


async def handle_IAMAT_request(message, rcvd_time):
    contents = message.split(" ")
    client, location, sent_time = contents[1:]
    sent_time = sent_time.rstrip()
    CLIENTS[client] = [client, SERVER_NAME, location, sent_time, str(rcvd_time)]
    time_diff = str(float(rcvd_time) - float(sent_time))
    if time_diff[0] != "-":
        time_diff = f"+{time_diff}"
    
    flood_message = "UPDATE " + " ".join(CLIENTS[client])
    await flood(flood_message)

    return f"AT {SERVER_NAME} {time_diff} {client} {location} {sent_time}"


async def handle_WHATSAT_request(message):
    client, radius, num_results = message.split(" ")[1:]
    radius = int(radius) * 1000
    num_results = int(num_results)
    if client not in CLIENTS:
        return f"? {message}"
    
    _, server, location, sent_time, rcvd_time = CLIENTS[client]
    lat, long = get_lat_and_long(location)
    results = await make_api_request(lat, long, radius, num_results)
    results_formatted = str(json.dumps(results, sort_keys=True, indent=4)).rstrip("\n") + "\n\n"

    time_diff = str(float(rcvd_time) - float(sent_time))
    if time_diff[0] != "-":
        time_diff = f"+{time_diff}"
    
    return f"AT {server} {time_diff} {client} {location} {sent_time}\n{results_formatted}"


async def handle_UPDATE_request(message):
    client, server, location, sent_time, rcvd_time = message.split(" ")[1:]
    if client not in CLIENTS or CLIENTS[client][4] < rcvd_time:
        CLIENTS[client] = message.split(" ")[1:]
        await flood(message)
    

async def accept_tcp_conn(reader, writer):
    """Based off of sample code. Called when client connection is created with server.
    
    https://docs.python.org/3/library/asyncio-stream.html#tcp-echo-server-using-streams.
    """
    LOG_FILE.write(f"TCP connection established.\n")

    while not reader.at_eof():
        data = await reader.readline()
        message = data.decode()
        if message == "":
            continue
        rcvd_time = time.time()

        addr = writer.get_extra_info("peername")
        LOG_FILE.write(f"Received from {addr!r}: {message!r}\n")

        request_type = get_request_type(message)

        if request_type == "UPDATE":
            await handle_UPDATE_request(message)
        else:
            if request_type == "INVALID":
                res = f"? {message}"
            elif request_type == "IAMAT":
                res = await handle_IAMAT_request(message, rcvd_time)
            else: # if request_type == "WHATSAT"
                res = await handle_WHATSAT_request(message)

            LOG_FILE.write(f"Sending: {res!r}\n")
            writer.write(res.encode())
            await writer.drain()

    writer.close()
    await writer.wait_closed()


async def main():
    server = await asyncio.start_server(accept_tcp_conn, "127.0.0.1", SERVERS[SERVER_NAME])

    addrs = ', '.join(str(sock.getsockname()) for sock in server.sockets)
    LOG_FILE.write(f"Serving on {addrs}.\n")

    async with server:
        await server.serve_forever()
    
    LOG_FILE.write("Closing server")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Incorrect number of arguments.")
    SERVER_NAME = sys.argv[1]
    if SERVER_NAME not in CONNECTIONS:
        sys.exit(f"{SERVER_NAME} not valid server.")
    LOG_FILE = open(LOG_FILE_NAME, "w+")
    LOG_FILE.truncate(0)
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
    LOG_FILE.close()