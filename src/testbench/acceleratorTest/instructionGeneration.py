import numpy as np
from enum import Enum
import itertools as itr

class FlexFowAccelerator:
    class FSMControl(Enum):
        INIT = 0
        HOLD = 1
        INCR = 2
        JUMP = 3
        K_ROW_OFFSET = 0
        K_COL_OFFSET = 1
        N_ROW_OFFSET = 2
        N_COL_OFFSET = 3

    class Opcodes(Enum):
        LOAD_N_BUFFER    = '0000'
        LOAD_K_BUFFER    = '0001'
        LOAD_CONSTANTS   = '0010'
        READ_N_BUFFER    = '0011'
        CHANGE_READ_BUFF = '0100'
        LOAD_LOCAL_N         = 'b1000'
        LOAD_LOCAL_K         = 'b1001'
        CONVOLVE             = 'b1010'
        POOL                 = 'b1011'
        DIVIDE_CONV_UNIT     = 'b1100'
        RESET_POOLING_REG    = 'b1110'

    def __init__(self,depth,dataWidth,localStoreDepth,localBufferDepth):
        self.depth = depth
        self.D = 2**depth
        self.Al = localStoreDepth
        self.Ab = localBufferDepth if (localBufferDepth>localStoreDepth+depth)\
            else localStoreDepth+depth
        self.instruction = '{0}{1:02b}{2:0%db}{3:0%db}{4:0%db}' % \
                                    (max(2,depth),max(2,depth),max(D,W))

    def getInstructionString(self,opcode:Opcodes,ins1:int,ins2:int,ins3:int,insLast:int or str):        
        return self.instruction.format(opcode,ins1,ins2,ins3,insLast)

    def loadKernelBufferInstruction(self,kernel :np.ndarray):
        (N,M,K,K) = kernel.shape # expecting np.ndarray (N,M,K,K)
        self.kernelsPerBank=kernelsPerBank = int(np.ceil(M/self.Tm)*np.ceil(N/self.Tn)*self.Tn)
        self.kernelDepthPerBank=kernelDepthPerBank = int(np.ceil((np.ceil(K/self.Tj)*self.Tj*np.ceil(K/self.Ti)*self.Ti)/(self.Tr*self.Tc)))
        if (kernelPerBanks*kernelDepthPerBank) > 2**self.Al:
            raise NotImplemented
        # Prepare banked kernel
        bankedKernel = np.zeros((D,kernelsPerBank,kernelDepthPerBank),dtype=int)
        for n, m in itr.product(range(N),range(M)):
            tn = n%Tn
            tm = m%Tm
            # we first cycle through M
            mCycle = int(m/Tm)
            nCycle = int(n/Tn)
            getBankNumber = lambda tr,tc: tm*self.Tr*self.Tc+tr*self.Tr+tc
            kernelNumberInBank = self.Tn*int(np.ceil(M/self.Tm))*nCycle+self.Tn*mCycle+tn
            for tr,tc in itr.product(range(self.Tr),range(self.Tc)):
                bankedKernel[getBankNumber(tr,tc), kernelNumberInBank,:] = kernel[n,m,:,:].flat[tr*self.Tc+tc:-1:self.Tr*self.Tc]
        # instructions to load banked kernel
        kCtrl,bankSelIns = self.FSMControl.INIT, self.FSMControl.INIT
        getInstruction = lambda kCtrl,bankSelIns,data: self.instruction.format(self.Opcodes.LOAD_K_BUFFER,kCtrl,bankSelIns,self.FSMControl.HOLD,data)
        ins = []
        for bankSelect in range(D):
            for data in [bankedKernel[bankSelect,i,j] for i,j in itr.product(range(kernelsPerBank),range(kernelDepthPerBank))] :
                ins += [getInstruction(kCtrl,bankSelIns,data)]
                kCtrl,bankSelIns = self.FSMControl.INCR, self.FSMControl.HOLD
            kCtrl,bankSelIns = self.FSMControl.INCR, self.FSMControl.INCR
        return ins

    def loadNeuronBufferInstruction(self, featureMap: np.ndarray):
        (N,S,S) = featureMap.shape
        neuronStep = int(np.ceil(S/Tj)) # number of columns in
        neuronRows = int(np.ceil(S/Ti))
        self.depthPerFMPerBank=depthPerFMPerBank = neuronStep*neuronRows
        self.fmsPerBank=fmsPerBank = int(np.ceil(N/Tn))
        if depthPerFMPerBank*fmsPerBank > 2**self.Al:
            raise NotImplemented
        # Prepare banked feature map
        bankedFM = np.zeros((D,fmsPerBank,depthPerFMPerBank),dtype=int)
        for n in range(N):
            tn = n%Tn
            nCycle = int(n/Tn)
            getBankNumber = lambda ti,tj: tn*Ti*Tj+Tj*ti+tj
            for ti,tj in itr.product(range(Ti),range(Tj)):
                bankedFM[getBankNumber(ti,tj),nCycle,:] = featureMap[n,ti:-1:Ti,tj:-1:Tj]
        # instructions to load banked kernel
        getInstruction = lambda nCtrl, bankSelIns, data: self.instruction.format(self.Opcodes.LOAD_N_BUFFER,nCtrl,bankSelIns,self.Opcodes.HOLD,data)
        nCtrl, bankSelectIns = self.FSMControl.INIT, self.FSMControl.INIT
        ins = []
        for bankSelect in range(D):
            for data in [bankedFM[bankSelect,i,j]]:
                ins += [getInstruction(nCtrl,bankSelIns,data)]
                nCtrl,bankSelectIns = self.FSMControl.INCR, self.FSMControl.HOLD
            nCtrl,bankSelectIns = self.FSMControl.INCR, self.FSMControl.INCR
        return ins

    def loadLocalStores(self,resumeFromPrevious:bool):
        # loading kernel
        kBuffCtrl, bankIns, kLocalCtrl = (self.FSMControl.JUMP,self.FSMControl.INIT,self.FSMControl.INIT) \
            if resumeFromPrevious else (self.FSMControl.INIT,self.FSMControl.INIT,self.FSMControl.INIT) 
        getInstruction = lambda kBuffCtrl, bankIns, kLocalCtrl, kernelColumnSel: self.instruction.format(self.Opcodes.LOAD_LOCAL_K,kBuffCtrl,bankIns, kLocalCtrl, kernelColumnSel)
        kIns = []
        # at a time we will only have 1 kernel in a PE local store
        # for bankRow in range(self.kernelsPerBank):
        for peGroup in range(Tn):
            for col in range(self.kernelDepthPerBank):
                for bankSel in range(Tr*Tc):
                    kColSelect = ['0']*peGroup*Ti*Tj+['1']*Ti*Tj+['0']*(self.D-(peGroup+1)*Ti*Tj)
                    kIns += [getInstruction(kBuffCtrl,bankIns, kLocalCtrl, ''.join(kColSelect))]
                    kBuffCtrl, bankIns, kLocalCtrl = self.FSMControl.HOLD,self.FSMControl.INCR,self.FSMControl.INCR
            kBuffCtrl, bankIns, kLocalCtrl = self.FSMControl.INCR,self.FSMControl.INIT,self.FSMControl.INCR
        # loading neurons
        nBuffCtrl, nLocalCtrl = (self.FSMControl.JUMP,self.FSMControl.INIT) \
            if resumeFromPrevious else (self.FSMControl.INIT,self.FSMControl.INIT) 
        getInstruction = lambda nBuffCtrl, nLocalCtrl: self.instruction.format(self.Opcodes.LOAD_LOCAL_N,nBuffCtrl,self.FSMControl.HOLD, nLocalCtrl, 0)
        nIns = []
        for row in range(self.fmsPerBank):
            for col in range(self.depthPerFMPerBank):
                nIns+=[getInstruction(nBuffCtrl,nLocalCtrl)]
                nBuffCtrl, nLocalCtrl = self.FSMControl.INCR, nLocalCtrl.INCR
            nBuffCtrl, nLocalCtrl = self.FSMControl.INCR, nLocalCtrl.INCR
        return [kIns]+[nIns]

    def convolutionInstructions(self):
        neuronStep = int(np.ceil(Si/tj)) # number of columns in
        kernelStep = int(np.ceil(K/tj)) # conflicting name, change something
        neuronRows = int(np.ceil(S/Ti))
        kernelRows = int(np.ceil(K/Ti))
        needsAuxInsForRow = lambda kPosn,kRow,kCtrl: \
            (kCtrl==self.FSMControl.JUMP)*(kPosn[0]<kRow-1) or \
                (kRow)*(kCtrl==self.FSMControl.INIT)
        needsAuxInsForCol = lambda kpos,kCol, kCtrl: \
            (kCtrl==self.FSMControl.INCR)*(kpos[1]<kCol-1) or \
                (kCol!=0)*(kCtrl in [self.FSMControl.INIT,self.FSMControl.JUMP])
        getKernelRowRange = lambda nRow: range(nRow+1) if nRow<kernelRows \
            else (range(nRow-neuronRows+kernelRows,kernelRows) \
                if nRow>neuronRows-kernelRows else range(kernelRows))
        getKernelColumnRange = lambda nCol: range(nCol+1) if nCol<kernelStep \
            else (range(nCol-neuronStep+kernelStep,kernelStep) \
                if nCol>neuronStep-kernelStep else range(kernelStep) )
        getInstruction = lambda kLCtrl, nLCtrl: self.instruction \
            .format(self.Opcodes.CONVOLVE,kLCtrl,nLCtrl,self.FSMControl.HOLD,0)

        updateKernelPosn = lambda kPos,kCtrl: (kCtrl != self.FSMControl.INIT)*\
            [kPos[0]+(kCtrl==self.FSMControl.JUMP),\
                (kPos[1]+(kCtrl==self.FSMControl.INCR)*\
                    (kCtrl!=self.FSMControl.JUMP)) ]
        kCtrl, nCtrl = self.FSMControl.INIT, self.FSMControl.INIT
        ins = []
        kPos = [0,0]
        for nRow in range(neuronRows):
            kerneRowlRange = getKernelRowRange(nRow)
            for nCol in range(neuronStep):
                kernelColRange = getKernelColumnRange(nCol)
                for kRow in kerneRowlRange:
                    while needsAuxInsForRow(kPos,kRow,kCtrl):
                        ins += [getInstruction(kCtrl,nCtrl)]
                        kPos = updateKernelPosn(kPos,kCtrl)
                        kCtrl, nCtrl = self.FSMControl.JUMP, self.FSMControl.HOLD    
                    for kcol in kernelColRange:
                        while needsAuxInsForCol(kPos,kcol,kCtrl):
                            ins += [getInstruction(kCtrl,nCtrl)]
                            kPos = updateKernelPosn(kPos,kCtrl)
                            kCtrl, nCtrl = self.FSMControl.INCR, self.FSMControl.HOLD    
                        ins += [getInstruction(kCtrl,nCtrl)]
                        kPos = updateKernelPosn(kPos,kCtrl)
                        kCtrl, nCtrl = self.FSMControl.INIT, self.FSMControl.HOLD    
                    kCtrl, nCtrl = self.FSMControl.JUMP, self.FSMControl.HOLD
                kCtrl, nCtrl = self.FSMControl.INIT, self.FSMControl.INCR
            kCtrl, nCtrl = self.FSMControl.INIT, self.FSMControl.JUMP
        return ins

    def poolingInstructions(self):
        setUseLower = lambda useLower: self.instruction.format(self.Opcodes.POOL,self.FSMControl.HOLD,self.FSMControl.HOLD,0,useLower)
        setUseCurrent = lambda useCurr: self.instruction.format(self.Opcodes.POOL,self.FSMControl.HOLD,self.FSMControl.HOLD,1,useCurr)
        setUseUpper = lambda useUpper: self.instruction.format(self.Opcodes.POOL,self.FSMControl.HOLD,self.FSMControl.HOLD,2,useUpper)
        setPoolWrite = lambda nCtrl, pCtrl, poolWrite: self.instruction.format(self.Opcodes.POOL,nCtrl,pCtrl,3,poolWrite)

        ins = [self.getInstructionString(self.Opcodes.RESET_POOLING_REG,0,0,0,0)]
        nCtrl, pCtrl = self.FSMControl.INIT, self.FSMControl.INIT
        useLower = ''.join((['1']*(Tr*Tc-1)+['0'])*Tm+['0']*(D-Tm*Tr*Tc))
        useUpper = ''.join((['0']+['1']*(Tr*Tc-1))*Tm+['0']*(D-Tm*Tr*Tc))
        ins += [setUseLower(useLower),setUseUpper(useUpper)]
        for nRow in range(int(np.ceil(So/(P*tc)))):
            for nCol in range(int(np.ceil(So/(P*tr)))):
                pass
                for pRow in range(P):
                    for pCol in range(P):
                        # this block is supposed to cover every row output
                        top = (pRow*Tc, pCol*Tr)
                        poolRowRange = range(  int(top[0]/P), \
                            int(np.ceil((top[0]+tc)/P)) )
                        poolColRange = range(  int(top[1]/P), \
                                    int(np.ceil((top[1]+tr)/P)) )
                        # list of PEs for which write is possible
                        for x,y in itr.product(poolRowRange,poolColRange):
                            useCurrent = ['1' if int((top[0]*x+i)/P) == x and \
                                int((top[1]*y+j)/P) == y else '0' for i,j \
                                    in itr.product(range(Tc), range(Tr))]*Tm +\
                                        [0]*(D-Tm*Tr*Tc)
                            poolWrite = [0]*tr*tc
                            poolWrite[x*Tc+y] = 1
                            poolWrite = poolWrite*D + [0]*(D-Tm*Tr*Tc)
                            ins +=[setUseCurrent(useCurrent), \
                                setPoolWrite(nCtrl,pCtrl,poolWrite)]
                            nCtrl, pCtrl = self.FSMControl.HOLD, self.FSMControl.HOLD
                        nCtrl, pCtrl = self.FSMControl.HOLD, self.FSMControl.INCR
                    nCtrl, pCtrl = self.FSMControl.HOLD, self.FSMControl.JUMP
                ins += [ins[0]] # reset pooling registers
                nCtrl, pCtrl = self.FSMControl.INCR, self.FSMControl.INIT
            nCtrl, pCtrl = self.FSMControl.JUMP, self.FSMControl.INIT
        return ins
    
    def divideConvUnitInstructions(self):
        ins = []
        groups = int(D/(Ti*Tj))
        getInstruction = lambda ins1,value,rowSel,colSel: self.instruction\
            .format(self.Opcodes.DIVIDE_CONV_UNIT, ins1, value, rowSel, colSel)
        rowForTj = np.array([j for j in range(Tj)]*groups*Ti+[0]*(D-Ti*Tj*Tn))
        rowForTi = np.array([i for i in range(Ti) for x in range(Tj)]*groups+[0]*(D-Ti*Tj*Tn))
        # Neuron Col offset
        ins1 = self.FSMControl.N_COL_OFFSET
        for j in range(Tj):
            colSel = ['0']*D
            colSel[rowForTj == j] = '1'
            colSel = ''.join(colSel)
            valueByRow = [int((Tj+x%Tc-j-1)/Tj) for x in range(Tc)]*Tm*Tr+[0]*(D-Tr*Tc*Tm)
            for rowSel in range(D):
                ins += [getInstruction(ins1,valueByRow[rowSel],rowSel,colSel)]
        # neuron Row offset
        ins1 = self.FSMControl.N_ROW_OFFSET
        for i in range(Ti):
            colSel = ['0']*D
            colSel[rowForTi == i] = '1'
            colSel = ''.join(colSel)
            valueByRow = [int((Tc+int(x/Tc)-i-1)/tc) for x in range(Tc*Tr)]*Tm+[0]*(D-Tr*Tc*Tm)
            for rowSel in range(D):
                ins += [getInstruction(ins1,valueByRow[rowSel],rowSel,colSel)]
        # Kernel Col Offset
        ins1 = self.FSMControl.K_COL_OFFSET
        for j in range(Tj):
            colSel = ['0']*D
            colSel[rowForTj == j] = '1'
            colSel = ''.join(colSel)
            valueByRow = [0]*D # add correct expression here
            for rowSel in range(D):
                ins += [getInstruction(ins1,valueByRow[rowSel],rowSel,colSel)]
        # Kernel Row offset
        ins1 = self.FSMControl.K_ROW_OFFSET
        for i in range(Ti):
            colSel = ['0']*D
            colSel[rowForTi == i] = '1'
            colSel = ''.join(colSel)
            valueByRow = [0]*D # add correct expression here
            for rowSel in range(D):
                ins += [getInstruction(ins1,valueByRow[rowSel],rowSel,colSel)]
        return ins



depth = 3
W = 16
Al = 7
Ab = 11

accelerator = FlexFowAccelerator(depth,W,Al,Ab)
