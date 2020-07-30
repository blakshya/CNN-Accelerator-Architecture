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
# Get Kernel here
#-----------------------------------------------------------------------------

kernelShape = (N,M,K,K)
kernel = np.zeros(kernelShape,dtype='int')
# add steps to convert this to / load as desired fixed point
    #-------------------------------------------------------------------------
    # Divide kernel to banks
    #-------------------------------------------------------------------------
kernelDepthPerBank = int(np.ceil(K/tj))*tj * int(np.ceil(K/ti))*ti /(tr*tc)
kernelDepthPerBank = int(np.ceil(kernelDepthPerBank))
bankedKernelShape = (D,kernelDepthPerBank*int(np.ceil(N/tn))*int(np.ceil(M/tm)))
bankedKernel = np.zeros(bankedKernelShape,dtype='int')

#-----------------------------------------------------------------------------
# Instructions for Loading Kernel Buffer
#-----------------------------------------------------------------------------

# INIT = 0
# INCR = 1
# HOLD = 2
# JUMP = 3

INIT = 'INIT'
INCR = 'INCR'
HOLD = 'HOLD'
JUMP = 'JUMP'

kCtrl = INIT
ins = []
for bankSelect in range(D):
    for data in bankedKernel[bankSelect,:]:
        # ins += ['{:03b}{0:016b}'.format(kCtrl,data)]
        ins += ['{}{0:016b}'.format(kCtrl,data)]
        # print(ins[-1],bankSelect, data, kCtrl)
        kCtrl = INCR    # col ++
    kCtrl = JUMP        # bank sel ++. col =0

