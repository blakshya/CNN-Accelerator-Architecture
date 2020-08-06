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
neuronRows = int(np.ceil(Si/ti))

#-----------------------------------------------------------------------------
# Get Feature Maps Here
#-----------------------------------------------------------------------------

bankedFMShape = (D,neuronRows*neuronStep*int(np.ceil(N/tn)))
bankedFM = np.zeros(bankedFMShape, dtype='int')

#-----------------------------------------------------------------------------
# Instructions for Reading from Neuron Buffer
#-----------------------------------------------------------------------------

INIT = '{:02b}'.format(0)
INCR = '{:02b}'.format(1)
HOLD = '{:02b}'.format(2)
JUMP = '{:02b}'.format(3)

# INIT = 'INIT'
# INCR = 'INCR'
# HOLD = 'HOLD'
# JUMP = 'JUMP'

nCtrl = INIT
ins = []
for bankSelect in range(D):
    for data in range(bankedFMShape[1]):
        # ins += ['{:03b}{:016b}'.format(nCtrl,data)]
        ins += ['{}{:016b}'.format(nCtrl,0)]
        print(ins[-1])
        nCtrl = INCR
    nCtrl = JUMP
