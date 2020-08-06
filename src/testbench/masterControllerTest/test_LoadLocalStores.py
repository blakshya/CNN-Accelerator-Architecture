import numpy as np
#-----------------------------------------------------------------------------
# Define Architecture parameters
#-----------------------------------------------------------------------------

depth = 3
D = 2**depth
W = 16
Ab = 8

#-----------------------------------------------------------------------------
# Define FMs & Kernel
#-----------------------------------------------------------------------------

N, M = 2, 2
S = 8
K = 3

Si = S
So = S-K+1

#-----------------------------------------------------------------------------
# Define Unrolling Factors
#-----------------------------------------------------------------------------

tr, tc = 2, 2
ti, tj = 2, 2
tm, tn = 2, 2

#-----------------------------------------------------------------------------
# Auxilary Relations
#-----------------------------------------------------------------------------

neuronStep = int(np.ceil(Si/tj)) # number of columns in
kernelStep = int(np.ceil(K/tj)) # conflicting name, change something

neuronRows = int(np.ceil(Si/ti))
kernelRows = int(np.ceil(K/ti))

kernelShape = (N,M,K,K)
kernelDepthPerBank = int(np.ceil((kernelStep*tj*kernelRows*ti)/(tr*tc)))
numKernelsPerBank = int(np.ceil(N/tn))*int(np.ceil(M/tm))
bankedKernelShape = (D,kernelDepthPerBank*numKernelsPerBank)

fmShape = (N,Si,Si)
neuronDepthPerBank = neuronRows*neuronStep
numFMPerBank = int(np.ceil(N/tn))
bankedFMShape = (D,neuronDepthPerBank*numFMPerBank)

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

# INIT = '{:03}'.format(0)
# INCR = '{:03}'.format(1)
# HOLD = '{:03}'.format(2)
# JUMP = '{:03}'.format(3)

INIT = 'INIT'
INCR = 'INCR'
HOLD = 'HOLD'
JUMP = 'JUMP'

'''
Contol
    controlSignal*D

controlSignal (per PE)
    kernelControl[3], kernelWrite[1], neuronControl[3], neuronWrite[1]

kernel write is common to the column (just like the control signal)
neuron write is common to the row (not bundeled in control)
'''
kIns=[]
nCtrl, kCtrl = INIT, INIT
nWrite, kWrite = 0, 1
bankSelectIns = INIT
# loading kernels
for bankRow in range(numKernelsPerBank):
    for peGroup in range(tn):
        for col in range(kernelDepthPerBank):
            for bankSelect in range(tr*tc):
                nWIns = ['0']*D
                kWIns = ['0']*peGroup*ti*tj+['1']*ti*tj+['0']*(D-(peGroup+1)*ti*tj)
                kIns += [[nCtrl,kCtrl,''.join(nWIns),''.join(kWIns),bankSelect,bankSelectIns] ]
                # kIns += [[nCtrl,kCtrl,nWrite,kWrite,bankSelect, bankSelectIns]]
                print(kIns[-1])
                nCtrl, kCtrl = HOLD, HOLD
                bankSelectIns = INCR
            nCtrl, kCtrl = HOLD, INCR
            bankSelectIns = INIT
    nCtrl, kCtrl = HOLD, JUMP

# loaing feature maps
nIns = []
nCtrl, kCtrl = INIT, INIT
nWrite, kWrite = 1, 0

for row in range(numFMPerBank):
    for col in range(neuronDepthPerBank):
        kWIns = ['0']*D
        nWIns = ['1']*D
        nIns += [[nCtrl, kCtrl,''.join(nWIns), ''.join(kWIns)]]
        nCtrl,kCtrl = INCR,HOLD
        print(nIns[-1])
    nCtrl, kCtrl = JUMP, HOLD
