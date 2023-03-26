package achen2289.pigzj;

import java.util.Arrays;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.zip.Deflater;

import static achen2289.pigzj.Constant.BLOCK_SIZE;

public class Executor implements Runnable 
{
    private final Deflater deflater;
	private final BlockingQueue<Block> uncompressedBlocks;
    private final BlockingQueue<Block> compressedBlocks;
	private static volatile boolean finished = false;
    private int id;

	public Executor(Deflater deflater, BlockingQueue<Block> uncompressedBlocks, BlockingQueue<Block> compressedBlocks, int id) 
    {
        this.deflater = deflater;
        this.uncompressedBlocks = uncompressedBlocks;
        this.compressedBlocks = compressedBlocks;
        this.id = id;
	}

	public void run()
    {
		while (!finished) {
			try {

                Block block = uncompressedBlocks.poll(1, TimeUnit.SECONDS);
                if (block == null) {
                    continue;
                }
                if (block.isLastBlock()) {
                    finished = true;
                }
                compressBlock(block);
			} 
            catch (InterruptedException ignore) {
				// Same player try again. Hopefully finished == true
			} 
            catch (Exception e) {
				throw (e instanceof RuntimeException) ? (RuntimeException) e : new RuntimeException(e);
			}
		}
	}

    private void compressBlock(Block block) throws InterruptedException
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

        Block compressedBlock = new Block(
            Arrays.copyOfRange(compressedBytes, 0, compressedDataLength), 
            block.getBlockNum(), 
            block.getBlockCount());
        compressedBlocks.put(compressedBlock);
    }
}