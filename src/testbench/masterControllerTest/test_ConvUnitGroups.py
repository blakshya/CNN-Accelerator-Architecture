import numpy as np
#-----------------------------------------------------------------------------
# Define Architecture parameters
#-----------------------------------------------------------------------------

depth = 3
# D = 2**depth
D = 9
W = 16
Ab = 8

#-----------------------------------------------------------------------------
# Define FMs & Kernel
#-----------------------------------------------------------------------------

N, M = 1, 1
S = 9
K = 3

Si = S
So = S-K+1

#-----------------------------------------------------------------------------
# Define Unrolling Factors
#-----------------------------------------------------------------------------

tr, tc = 2, 2
ti, tj = 3, 3
tm, tn = 2, 1

#-----------------------------------------------------------------------------
# Basic Instructions
#-----------------------------------------------------------------------------

HOLD = 'HOLD'
K_ROW_OFFSET = 'K_ROW_OFFSET'
K_COL_OFFSET = 'K_COL_OFFSET'
N_ROW_OFFSET = 'N_ROW_OFFSET'
N_COL_OFFSET = 'N_COL_OFFSET'

#-----------------------------------------------------------------------------
# Functions for initial setting
#-----------------------------------------------------------------------------

def getKernelOffsetInstructions(D,ti,tj,tn):
    '''these instructions are column wise '''
    ins = []
    groups = int(D/(ti*tj))
    # groups = tn
    rowForTj = np.array([j for j in range(tj)]*groups*ti)
    rowForTi = np.array([i for i in range(ti) for x in range(tj)]*groups)
    # kernel row offset = ti
    for i in range(ti):
        tempIns = np.array([HOLD]*D)
        tempIns[rowForTi == i] = K_ROW_OFFSET
        ins += [(tempIns,[i]*D)]
    # kernel col offset = tj
    for j in range(tj):
        tempIns = np.array([HOLD]*D)
        tempIns[rowForTj == j] = K_COL_OFFSET
        ins += [(tempIns,[j]*D)]
    return ins

def getNeuronOffsetInstructions(D,ti,tj,tr,tc,tn,tm):
    ''' '''
    k = []
    # groups = int(D/(ti*tj))
    groups = tn
    rowForTj = np.array([j for j in range(tj)]*groups*ti+[0]*(D-ti*tj*tn))
    rowForTi = np.array([i for i in range(ti) for x in range(tj)]*groups+[0]*(D-ti*tj*tn))
    # neuron col offset = (Tj+tc-tj-1)/Tj # check if its Tr??
    # for i in range(ti):
    for j in range(tj):
            tempIns = np.array([HOLD]*D)
            ins, value = [],[]
            # mask = np.ones(D,dtype='int')
            # mask = (rowForTi == i) & (rowForTj == j)
            mask = (rowForTj == j)
            tempIns[mask] = N_COL_OFFSET
            ins = tempIns
            value = [int((tj+x%tc-j-1)/tj) for x in range(tc)]*tm*tr+[0]*(D-tr*tc*tm)
            k += [(ins,value)]
    # neuron row offset = (Tc+tr-ti-1)/Tc
    for i in range(ti):
        # for j in range(tj):
            tempIns = np.array([HOLD]*D)
            ins, value = [],[]
            # tempIns[(rowForTi == i) & (rowForTj == j)] = N_COL_OFFSET
            tempIns[(rowForTi == i)] = N_ROW_OFFSET
            ins = tempIns
            # value = [int((tc+int(x/tc)-i-1)/tc) for x in range(tc*tr)]*groups
            value = [int((tc+int(x/tc)-i-1)/tc) for x in range(tc*tr)]*tm+[0]*(D-tr*tc*tm)
            k += [(ins,value)]
    return k

ins = []

ins += getKernelOffsetInstructions(D,ti,tj,tn)
ins += getNeuronOffsetInstructions(D,ti,tj,tr,tc,tn,tm)


for i in ins:
    print(i)

