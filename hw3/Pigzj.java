import achen2289.pigzj.Block;
import achen2289.pigzj.Executor;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.PrintStream;
import java.lang.Runtime;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;
import java.util.List;
import java.util.zip.CRC32;
import java.util.zip.Deflater;

import static achen2289.pigzj.Constant.BLOCK_SIZE;
import static achen2289.pigzj.Constant.TRAILER_SIZE;
import static achen2289.pigzj.ErrorCode.INPUT_ERROR;
import static achen2289.pigzj.ErrorCode.INTERNAL_ERROR;

public final class Pigzj 
{
    private final int threadCount;
    private final byte[] inputBuffer;
    private final int blockCount;
    private final BlockingQueue<Block> uncompressedBlocks;
    private final BlockingQueue<Block> compressedBlocks;
    private final Deflater deflater;

    private final static byte[] DEFAULT_HEADER = {
		(byte) 0x1f,                      // ID1
		(byte) 0x8b,                      // ID2
		Deflater.DEFLATED,                // CM (compression method)
		0,                                // FLG (flags)
		0,                                // MTIME (modification time)
		0,                                // MTIME (modification time)
		0,                                // MTIME (modification time)
		0,                                // MTIME (modification time)
		(byte) 4,                         // EXFLG (extra flags)
		(byte) 0xff                          // OS (operating system)
	};

    public Pigzj(int threadCount, byte[] inputBuffer) throws InterruptedException
    {
        this.threadCount = threadCount;
        this.inputBuffer = inputBuffer.clone();
        this.blockCount = (int) Math.ceil((float) inputBuffer.length / BLOCK_SIZE);
        this.uncompressedBlocks = new ArrayBlockingQueue<>(this.blockCount);
        this.compressedBlocks = new ArrayBlockingQueue<Block>(this.blockCount);
        this.deflater = new Deflater(Deflater.SYNC_FLUSH, true);

        populateQueue();
    }

    private void populateQueue() throws InterruptedException
    {
        Block currBlock;
        for (int i=0; i<blockCount; i++) {
            int startByte = i * BLOCK_SIZE;
            int lastByte = Math.min((i+1) * BLOCK_SIZE, inputBuffer.length);
            byte[] currBlockContent = Arrays.copyOfRange(inputBuffer, startByte, lastByte);
            currBlock = new Block(currBlockContent, i, blockCount);
            uncompressedBlocks.put(currBlock);
        }
    }

    public void compress(PrintStream out) throws InterruptedException, IOException
    {
        writeHeader(out);
        // compressBlocks(out);
        compressBlocksParallel();
        writeBlocks(out);
        writeTrailer(out);
        deflater.end();
    }

    private void writeHeader(PrintStream out) throws IOException
    {
        out.write(DEFAULT_HEADER);
    }

    private void compressBlocks(PrintStream out) throws InterruptedException, IOException
    {
        for (int i=0; i<blockCount; i++) {
            Block block = uncompressedBlocks.take();
            compressBlock(block, out);
        }
    }

    private void compressBlocksParallel() throws InterruptedException
    {
        List<Thread> threads = new ArrayList<>();
        for (int i=0; i<threadCount; i++) {
            Thread thread = new Thread(new Executor(deflater, uncompressedBlocks, compressedBlocks, i));
            thread.start();
            threads.add(thread);
        }

        for (Thread thread : threads) {
            thread.join();
        }
    }

    private void writeBlocks(PrintStream out) throws IOException, InterruptedException
    {
        Block[] reorderedBlocks = new Block[blockCount];
        for (int i=0; i<blockCount; i++) {
            Block block = compressedBlocks.take();
            reorderedBlocks[block.getBlockNum()] = block;
        }

        for (Block block : reorderedBlocks) {
            byte[] compressedBytes = block.getContent();
            out.write(compressedBytes, 0, compressedBytes.length);
        }
    }

    private void compressBlock(Block block, PrintStream out) throws IOException
    {
        byte[] uncompressedBytes = block.getContent();
        byte[] compressedBytes = new byte[BLOCK_SIZE];

        deflater.setInput(uncompressedBytes);
        int compressedDataLength;
        if (block.isLastBlock()) {
            deflater.finish();
            compressedDataLength = deflater.deflate(compressedBytes);
        }
        else {
            compressedDataLength = deflater.deflate(compressedBytes, 0, compressedBytes.length, Deflater.SYNC_FLUSH);
        }
        out.write(compressedBytes, 0, compressedDataLength);
    }

    private void writeTrailer(PrintStream out) throws IOException
    {
        CRC32 crc = new CRC32();
        crc.update(inputBuffer);
        int crcValue = (int) crc.getValue();

        byte[] trailer = new byte[TRAILER_SIZE];
        writeTrailer(trailer, 0, crcValue, deflater.getTotalIn());
        out.write(trailer);
    }

    // TAKEN FROM MessAdmin repo: https://github.com/MessAdmin/MessAdmin-Core
	public static void writeTrailer(byte[] buf, int offset, int crc32, int uncompressedBytes) throws IOException {
		writeInt(crc32, buf, offset); // CRC-32 of uncompr. data
		writeInt(uncompressedBytes, buf, offset + 4); // Number of uncompr. bytes
	}

	/**
     * TAKEN FROM MessAdmin repo: https://github.com/MessAdmin/MessAdmin-Core
	 * Writes integer in Intel byte order to a byte array, starting at a
	 * given offset.
	 */
	private static void writeInt(int i, byte[] buf, int offset) throws IOException {
		writeShort(i & 0xffff, buf, offset);
		writeShort((i >> 16) & 0xffff, buf, offset + 2);
	}

	/**
     * TAKEN FROM MessAdmin repo: https://github.com/MessAdmin/MessAdmin-Core
	 * Writes short integer in Intel byte order to a byte array, starting
	 * at a given offset
	 */
	private static void writeShort(int s, byte[] buf, int offset) throws IOException {
		buf[offset] = (byte)(s & 0xff);
		buf[offset + 1] = (byte)((s >> 8) & 0xff);
	}

    private static List<Byte> boxPrimitive(byte[] input)
    {
        List<Byte> output = new ArrayList<>();
        for (byte inp : input) {
            output.add(inp);
        }
        return output;
    }

    public static void main(String[] args) throws InterruptedException, IOException, NumberFormatException
    {
        if (args.length != 0 && args.length != 2) {
            System.err.println("Input error: Incorrect argument count.");
            System.exit(INPUT_ERROR);
        }

        int threadCount, availableProcessors = Runtime.getRuntime().availableProcessors();
        if (args.length == 0) {
            threadCount = availableProcessors;
        }
        else { // args.length == 2
            if (!args[0].equals("-p")) {
                System.err.println("Input error: Must provide no arguments, or a -p option followed by thread count.");
                System.exit(INPUT_ERROR);
            }
            threadCount = Integer.parseInt(args[1]);
        }

        if (threadCount > 4 * availableProcessors) {
            System.err.println("Input error: cannot use more than 4x the number of available processors.");
            System.exit(INPUT_ERROR);
        }

        byte[] inputBuffer = new byte[32 * 1024];
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        
        int bytesRead;
        while ((bytesRead = System.in.read(inputBuffer)) > 0) {
            outputStream.write(inputBuffer, 0, bytesRead);
        }
        byte[] bytes = outputStream.toByteArray();

        Pigzj pigzj = new Pigzj(threadCount, bytes);
        PrintStream out = new PrintStream(System.out);
        pigzj.compress(out);
        out.close();
    }
}