import itertools
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

P = 4

Si = S
So = S-K+1

So = 24
SoPooled = int(np.ceil(So/P))

#-----------------------------------------------------------------------------
# Define Unrolling Factors
#-----------------------------------------------------------------------------

tr, tc = 3, 3
ti, tj = 3, 3
tm, tn = 1, 1

#-----------------------------------------------------------------------------
# Auxilary Relations
#-----------------------------------------------------------------------------

neuronStepPool = int(np.ceil(SoPooled/tc)) # number of columns in
neuronRowsPool = int(np.ceil(SoPooled/tr))

poolStep = int(np.ceil(P/tc))
poolRows = int(np.ceil(P/tr))

#-----------------------------------------------------------------------------
# Instructions for Loading to Neuron Buffer
#-----------------------------------------------------------------------------

INIT = '{:02b}'.format(0)
INCR = '{:02b}'.format(1)
HOLD = '{:02b}'.format(2)
JUMP = '{:02b}'.format(3)

# INIT = 'INIT'
# INCR = 'INCR'
# HOLD = 'HOLD'
# JUMP = 'JUMP'

doPooling = 1

'''
So is divisible by P

pooling Unit instructions
    {write, useUpper, useCurrent, useLower}

nCtrl used by both read and write buffer
pCtrl used by only the write buffer
'''

nCtrl, pCtrl = INIT, INIT

ins = []

for nRow in range(int(np.ceil(So/(P*tc)))):
    for nCol in range(int(np.ceil(So/(P*tr)))):
        pass
        for pRow in range(P):
            for pCol in range(P):
                # this block is supposed to cover every row output
                top = (pRow*tc, pCol*tr) # correct
                top1 = (nRow*P *tc+pRow*tc,nCol*P*tr+ pCol*tr) # temp only
                i = range(  int(top[0]/P), \
                            int(np.ceil((top[0]+tc)/P)) )
                j = range(  int(top[1]/P), \
                            int(np.ceil((top[1]+tr)/P)) )
                # print(top1,top,[x for x in i],[y for y in j])
                # list of PEs for which write is possible
                for x,y in itertools.product(i,j):
                    wIns = [0]*tr*tc
                    wIns[x*tc+y] = 1
                    wIns = wIns*D +[0]*(D-tm*tr*tc)
                    upIns = ([0]+[1]*(tr*tc-1))*tm+[0]*(D-tm*tr*tc)
                    downIns = ([1]*(tr*tc-1)+[0])*tm+[0]*(D-tm*tr*tc)
                    currIns = [1 if int((top[0]*x+i)/P) == x and \
                                int((top[1]*y+j)/P) == y else 0 \
                                    for i,j in itertools.product(range(tc), range(tr))]*tm+[0]*(D-tm*tr*tc)
                    ins += [[nCtrl,pCtrl]+
                                ['{}{}{}{}'.format(w,u,c,l) for w,u,c,l \
                                    in zip(wIns,upIns,currIns,downIns)]]
                    # print(ins[-1])
                    nCtrl, pCtrl = HOLD, HOLD
                nCtrl, pCtrl = HOLD, INCR
            nCtrl, pCtrl = HOLD, JUMP
        ins += [[HOLD, HOLD]+['1000']*D]
        nCtrl, pCtrl = INCR, INIT
    nCtrl, pCtrl = JUMP, INIT

filename = 'poolingInstructions'
with open(filename+'.txt','w') as f:
        for i in ins:
            i = ''.join(i)
            f.write('%s\n'%i)
