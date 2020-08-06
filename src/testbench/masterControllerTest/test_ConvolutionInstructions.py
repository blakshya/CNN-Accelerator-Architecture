import numpy as np
#-----------------------------------------------------------------------------
# Define Architecture parameters
#-----------------------------------------------------------------------------

depth = 2
D = 2**depth
W = 16
Ab = 8

#-----------------------------------------------------------------------------
# Define FMs & Kernel
#-----------------------------------------------------------------------------

N, M = 1, 1
S = 8
K = 3

Si = S
So = S-K+1

#-----------------------------------------------------------------------------
# Define Unrolling Factors
#-----------------------------------------------------------------------------

tr, tc = 2, 2
ti, tj = 2, 2
tm, tn = 1, 1

#-----------------------------------------------------------------------------
# Auxilary Relations
#-----------------------------------------------------------------------------

neuronStep = int(np.ceil(Si/tj)) # number of columns in
kernelStep = int(np.ceil(K/tj)) # conflicting name, change something

neuronRows = int(np.ceil(Si/ti))
kernelRows = int(np.ceil(K/ti))

#-----------------------------------------------------------------------------
# Instructions for Convolution
#-----------------------------------------------------------------------------

'''
    instructions:
        1 INIT - 3'b000
        2 INCR - 3'b001
        3 HOLD - 3'b010
        4 JUMP - 2'b011
'''

INIT = 0
INCR = 1
HOLD = 2
JUMP = 3

# INIT = 'INIT'
# INCR = 'INCR'
# HOLD = 'HOLD'
# JUMP = 'JUMP'

def getKernelRowRange(nRow,neuronRows,kernelRows):
    return range(nRow+1) if nRow<kernelRows else \
        (range(nRow-neuronRows+kernelRows,kernelRows) \
            if nRow>neuronRows-kernelRows else range(kernelRows))

def getKernelColumnRange(nCol,neuronStep,kernelStep):
    return range(nCol+1) if nCol<kernelStep \
        else (range(nCol-neuronStep+kernelStep,kernelStep) \
            if nCol>neuronStep-kernelStep else range(kernelStep) )

def getInstuctionString(kernelControl,neuronControl):
    ins = ['''{:03b}{:03b}'''.format(kernelControl,neuronControl)]
    # ins = ['''k:{}. n:{}'''.format(kernelControl,neuronControl)]
    print (ins, end="")
    return ins

def updateKernelposition(kernelControl,kPosn): # replace with switcher
    if kernelControl == INIT:
        kPosn = [0,0]
    elif kernelControl == INCR:
        # kPosn = [kPosn[0],kPosn[1]+tj]
        kPosn = [kPosn[0],kPosn[1]+1]
    elif kernelControl == HOLD:
        kPosn = [kPosn[0], kPosn[1]]
    elif kernelControl == JUMP:
        # kPosn = [kPosn[0]+ti,0]
        kPosn = [kPosn[0]+1,0]
    print(kPosn, end="")
    return kPosn

def updateNeuronposition(neuronControl,nPosn): # replace with switcher
    if neuronControl == INIT:
        nPosn = [0,0]
    elif neuronControl == INCR:
        nPosn = [nPosn[0], nPosn[1]+1]
    elif neuronControl == HOLD:
        nPosn = [nPosn[0], nPosn[1]]
    elif neuronControl == JUMP:
        nPosn = [nPosn[0]+1,0]
    print(nPosn)
    return nPosn

def needsAuxInstrForCol(kPosn,kcol, kernelControl):
    # false iff we reach kCol with the kernelControl
    if kernelControl == INCR:
        # return kPosn[1]<kcol and kPosn[1]+1 != kcol
        return kPosn[1] < kcol -1
    if kernelControl == INIT or kernelControl == JUMP:
        return kcol != 0        
    return kPosn [0] < kRow -1

def needsAuxInstrForRow(kPosn,kRow, kernelControl):
    # false iff we reach kRow with the kernelControl
    if kernelControl == JUMP:
        # return kPosn[0] < kRow and kPosn[0]+1 != kRow
        return kPosn [0] < kRow -1
    if kernelControl == INIT or kernelControl == INIT:
        return kRow != 0
    return False
    # return kRow - kPosn[0] > 1
kPosn = [0,0] # row, col
nPosn = [0,0] # row, col
kctrl, nctrl = INIT, INIT
ins = []

for nRow in range(neuronRows):
    kernelRowRange = getKernelRowRange(nRow,neuronRows, kernelRows)
    for nCol in range(neuronStep):
        kernelColRange = getKernelColumnRange(nCol,neuronStep, kernelStep)
        for kRow in kernelRowRange:
            while needsAuxInstrForRow(kPosn,kRow,kctrl):
                # print(('updating Row- kRow:{} kposn[{},{}] '+kctrl)\
                #     .format(kRow,kPosn[0],kPosn[1]))
                ins += getInstuctionString(kctrl, nctrl)
                kPosn = updateKernelposition(kctrl,kPosn)
                nPosn = updateNeuronposition(nctrl,nPosn)
                kctrl, nctrl = JUMP, HOLD
            for kcol in kernelColRange: # assumes we are in correct row
                while needsAuxInstrForCol(kPosn,kcol,kctrl):
                    # print(('updating Col- kcol:{} kposn[{},{}] '+kctrl)\
                    #     .format(kcol,kPosn[0],kPosn[1]))
                    ins += getInstuctionString(kctrl,nctrl)
                    kPosn = updateKernelposition(kctrl,kPosn)
                    nPosn = updateNeuronposition(nctrl,nPosn)
                    kctrl,nctrl = INCR, HOLD
                ins += getInstuctionString(kctrl,nctrl)
                kPosn = updateKernelposition(kctrl,kPosn)
                nPosn = updateNeuronposition(nctrl,nPosn)
                kctrl,nctrl = INCR, HOLD
            kctrl,nctrl = JUMP, HOLD
        kctrl,nctrl = INIT, INCR
    kctrl,nctrl = INIT, JUMP


# print (ins)

# filename = 'convolutionInstructions'
# with open(filename+'.txt','w') as f:
#         for i in ins:
#             f.write('%s\n'%i)

