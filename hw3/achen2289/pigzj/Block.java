package achen2289.pigzj;

import static achen2289.pigzj.Constant.BLOCK_SIZE;
import static achen2289.pigzj.Constant.DICTIONARY_SIZE;
import static achen2289.pigzj.ErrorCode.NO_ERROR;
import static achen2289.pigzj.ErrorCode.INTERNAL_ERROR;

public final class Block
{
    private byte[] content;
    private int blockNum;
    private int blockCount;

    public Block(byte[] content, int blockNum, int blockCount)
    {   
        if (content.length > BLOCK_SIZE) {
            System.err.println("Internal error: attempting to create Block larger than maximum size.");
            System.exit(INTERNAL_ERROR);
        }
        this.content = content.clone();
        this.blockNum = blockNum;
        this.blockCount = blockCount;
    }

    public byte[] getContent()
    {
        return content;
    }

    public int getBlockNum()
    {
        return blockNum;
    }

    public int getBlockCount()
    {
        return blockCount;
    }

    public boolean isLastBlock()
    {
        return blockNum == blockCount - 1;
    }
}