In my tests, I will be making a few different measurements, as suggested by the spec. 

First, I will measure the average build times for Pigzj and pigzj, over 10 runs, along with
their program sizes. I automated this by using a shell script which accepts a command 
as well as number of trials as input. 

Pigzj
    real 0m742000s
    user 1m653000s
    sys  0m116000s

pigzj
    real 2m654000s
    user 7m088000s
    sys  0m468000s

As expected, building with GraalVM's native-image takes longer than building with 
OpenJDK. One thing I found interesting was that the user time is larger than 
real time. After doing some research, this is because user time is the total 
amount of time spent within user-mode for the build process, and there may be 
multiple processes executing simultaneously to multiply the user-time.

Next, I will measure the average run times for Pigzj, pigzj, pigz, and gzip. I am 
running these programs against the input of the file 
/usr/local/cs/graalvm-ce-java17-22.3.1/lib/modules.

Again, I will use the average time shell script, and redirect the output to 
a trivial .gz file. I expect gzip to be the slowest, since it does not have 
parallelism, while Pigzj, pigzj, and pigz all use multiple threads.

Pigzj
    real    0m4.996s
    user    0m4.396s
    sys     0m0.403s

pigzj
    real    0m5.715s
    user    0m4.492s
    sys     0m0.714s

pigz
    real    0m2.499s
    user    0m9.213s
    sys     0m0.139s

gzip
    real    0m9.341s
    user    0m9.068s
    sys     0m0.164s

My pigzj implementations did beat the gzip implementation, although pigz is the fastest 
by a margin. My implementations beat gzip by approximately a factor of 2, while pigz 
beat my implementation by roughly a factor of 2 as well.

Next, I will change the number of processors to 2, to see how a lower thread count
affects the efficiency, and use the same testing setup as previously. I predict 
the times will be slower since the default number of processors available on the 
current server I am testing on (lnxsrv13) is 4.

Pigzj
    real    0m5.006s
    user    0m4.418s
    sys     0m0.382s
    size    58420341
    ratio   35.97%

pigzj
    real    0m5.303s
    user    0m4.437s
    sys     0m0.674s
    size    58393314
    ratio   35.62%

pigz
    real    0m4.598s
    user    0m9.091s
    sys     0m0.138s
    size    52825651
    ratio   32.39%

In all cases, the performance decreases, which makes sense as processor count is going
down and decreasing the possible parallism. pigz does have a more noteable degrade in
performance, however. I think this may be because my implementation is not as dependent 
upon parallelism than pigz is. My implementation will compress the blocks in parallel, 
but it will still wait until all blocks have been compressed to write the blocks 
to the output stream serially. This was because I did not have the time to accomplish 
writing to output in parallel as well, which I was thinking could be accomplishable 
with another thread pool that goes through the compressed blocks and writes them out 
as soon as the earliest un-written block has been added to a compressed block pool.

I will also change the number of processors to 16, to see performance 
when the thread count is larger. Per the spec, 16 (4 times the available processors) 
is the maximum thread count allowed. I actually expect performance to potentially 
decrease if threads are waiting on each other and competing for resources.

Pigzj
    real    0m5.037s
    user    0m4.385s
    sys     0m0.446s
    size    58430341
    ratio   35.87%

pigzj
    real    0m5.325s
    user    0m4.426s
    sys     0m0.764s
    size    58373314
    ratio   35.84%

pigz
    real    0m2.672s
    user    0m9.088s
    sys     0m0.166s
    size    52826651
    ratio   32.43%

The times actual seem to stay around the same, which is surprising! I'd expect 
the performance to increase, but it didn't. It also didn't decrease, so it is likely 
that even with a greater number of threads, many may be staying idle and waiting for 
work, if for example, block count is not large enough for each thread to have 1.

Regarding the compression ratios, pigz has a better (lower) ratio. The compressed 
files, on average, are lower in ratio as compared to the original files than they 
are for my implementations. I believe this is because pigz takes advantage of 
priming the compression block by using a sub-portion of the previous block's input 
to make compression better. This could also be attributed to different compression 
algorithms used or block sizes. If block sizes are larger, for example, this could 
potentially make compression better, albeit at the cost of efficiency because 
each thread takes longer to complete and less parallelism can be extracted.

I also tested the programs as file size scales up -- pigz's performance does decently 
better than mine, which I was confused about, until running strace.

After running strace, one point of difference that makes sense is when I read from 
stdin, I read and write 1 byte at a time, due to a implementation decision I made 
to save programming time. This explains why my implementations have worse
performance, as there are a lot of write(, ... 1) and read(, ...1)s, while
the same isn't true for pigz. Also, I perform a lot of array clones, because I wasn't 
sure if I needed to for expected behavior, in case there was some garbage 
collection that was unexpected. This was clear from all the clone calls seen 
in the system trace. If I had more time, I would go back and make changes to 
optimize these inefficiencies. Overall, strace was extremely helpful in seeing the 
differences in my implementations and pigz.

I used MessAdmin's implementation when writing the bytes of the trailer (reversing 
byte order, formatting). I figured it would be easier to not reinvent the wheel 
in this case where it would save much time and is a simple feature.

