'''
io ports:
 *      ioSelect - if io is enabled
 *      ioWrite - if io write is enabled
 *      ioBankSelect -  bank number selected for io
 *      ioInput - W-bit input
 *      ioOut - W-bit output
'''

'''
Order of control signal for IO
    address,ioSelect,write,ioBankSelect,ioInput
'''



def saveInstructions(filename, strList):
    with open(filename+'.txt','w') as f:
        for i in strList:
            for j in i:
                f.write('%s\n'%j)

def getTestInsToLoad(W,A,depth,FP_LOC):
    ins = []
    D = 2**depth
    #bank select
    BANK_NUMBER = [('{:0%db}'%depth).format(i) for i in range(D)]
    # arbitrary data to be loaded
    NUMBERS = [[('{:0%db}{:0%db}'%(W-FP_LOC,FP_LOC)).format(i,j) for j in range(D)] for i in range(2**A)]
    ADDRESS = [('{:0%db}'%A).format(i) for i in range(2**A)]

    ins = [[ADDRESS[i]+'11'+BANK_NUMBER[j]+NUMBERS[i][j] for j in range(2**depth)] for i in range (2**A)]
    return ins

def getInsToReadFromBuffer(W,A,depth):
    ins = []
    D = 2**depth
    BANK_NUMBER = [('{:0%db}'%depth).format(i) for i in range(D)]
    ADDRESS = [('{:0%db}'%A).format(i) for i in range(2**A)]
    ZERO = ('{:0%db}'%(W)).format(0)
    ins = [[ADDRESS[i]+'10'+BANK_NUMBER[j]+ZERO for j in range(D)] for i in range(2**A)]
    return ins


## instructions for IO Test

W = 16
A = 7
depth = 2
FP_LOC = 5

ins = getTestInsToLoad(W,A,depth,FP_LOC)
# ins = getInsToReadFromBuffer(W,A,depth)
ins += getInsToReadFromBuffer(W,A,depth)
# ins = ins.extend(getInsToReadFromBuffer(W,A,depth))
saveInstructions('bufferIOTest_instructions',ins)
# print(ins)

