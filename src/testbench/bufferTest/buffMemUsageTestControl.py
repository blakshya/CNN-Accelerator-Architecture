'''
io ports:
 *      ioSelect - if io is enabled
 *      ioWrite - if io write is enabled
 *      ioBankSelect -  bank number selected for io
 *      ioInput - W-bit input
 *      ioOut - W-bit output
'''
'''
Order of control signal for Usage
    address,write,input
'''

def saveInstructions(filename, strList):
    with open(filename+'.txt','w') as f:
        for i in strList:
            f.write('%s\n'%i)

def getInsForUseAsWriteBuffer(W,A,depth):
    ins = []
    D = 2**depth
    ADDRESS = [('{:0%db}'%A).format(i) for i in range(2**A)]
    INPUT = [('{:0%db}'%(D*W)).format(2**(i*W)) for i in range(D)]
    ins = [ADDRESS[i]+'01'+INPUT[i] for i in range(D)]
    return ins

def getInsForUseAsReadBuffer(W,A,depth):
    ins = []
    D = 2**depth
    ADDRESS = [('{:0%db}'%A).format(i) for i in range(2**A)]
    ZERO = ('{:0%db}'%(D*W)).format(0)
    ins = [ADDRESS[i]+'00'+ZERO for i in range(D)]
    return ins

## instructions for normal usage test

W = 3
A = 7
depth = 3
FP_LOC = 1

ins = []
ins = getInsForUseAsWriteBuffer(W,A,depth)
ins += getInsForUseAsReadBuffer(W,A,depth)

saveInstructions('bufferUsageTest_instructions',ins)

# print(ins)
