import numpy as np
from enum import Enum, IntEnum
import itertools as itr

class FlexFowAccelerator:
    class FSMControl(IntEnum):
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
        LOAD_LOCAL_N         = '1000'
        LOAD_LOCAL_K         = '1001'
        CONVOLVE             = '1010'
        POOL                 = '1011'
        DIVIDE_CONV_UNIT     = '1100'
        RESET_POOLING_REG    = '1110'

    def __init__(self,depth,dataWidth,localStoreDepth,localBufferDepth):
        self.depth = depth
        self.W = dataWidth
        self.D = 2**depth
        self.Al = localStoreDepth
        self.Ab = localBufferDepth if (localBufferDepth>localStoreDepth+depth)\
            else localStoreDepth+depth
        
        # self.instruction = '{0}{1:02b}{2:0%db}{3:0%db}{4:0%db}' % (max(2,depth),max(2,depth),max(self.D,W))
        # self.instruction = '{0} {1:02b} {2:0%db} {3:0%db} {4:0%db}' %     (max(2,depth),max(2,depth),max(self.D,W))
        self.instruction = '{0}{1:02b}{2:0%db}{3:0%db}{4:0%db}' % (max(2,depth),max(2,depth),max(self.D,W))

        # self.instruction_LastString = ('{} {:02b} {:0%db} {:0%db} ' % (max(2,depth),max(2,depth))) + ''.join(['0']*max(0,W-self.D)) +'{}'
        self.instruction_LastString = ('{}{:02b}{:0%db}{:0%db}' % (max(2,depth),max(2,depth))) + ''.join(['0']*max(0,W-self.D)) +'{}'
        
        self.Ti = self.Tj  = self.Tr = self.Tc = 2
        self.Tm = self.Tn = 1
        self.fmShape = (2,8,8)
        self.kShape = (2,2,3,3)
        self.P = 2
        self.kernelsPerBank = int(np.ceil(self.kShape[1]/self.Tm)*np.ceil(self.fmShape[0]/self.Tn)*self.Tn)
        self.kernelDepthPerBank = int(np.ceil((np.ceil(self.kShape[2]/self.Tj)*self.Tj*np.ceil(self.kShape[2]/self.Ti)*self.Ti)/(self.Tr*self.Tc)))
        self.neuronStep = 4
        self.neuronRows = 4
        self.depthPerFMPerBank = 20
        self.fmsPerBank = 1

    def setUnrollingParams(self,Ti,Tj,Tn,Tr,Tc,Tm):
        self.Ti = Ti
        self.Tj = Tj
        self.Tn = Tn
        self.Tr = Tr
        self.Tc = Tc
        self.Tm = Tm

    def getUnrollingParams(self):
        # Ti, Tj, Tn, Tr, Tc, Tm = self.getUnrollingParams()
        return self.Ti, self.Tj, self.Tn, self.Tr, self.Tc, self.Tm

    def getInstructionString(self,opcode:Opcodes,ins1:int,ins2:int,ins3:int,insLast:int or str):        
        return self.instruction.format(opcode,ins1,ins2,ins3,insLast)

    def loadConstants(self, kernelShape, neuronShape, P):
        self.P = P
        self.kShape = (N,M,K,K) = kernelShape
        self.fmShape = neuronShape

        self.kernelStep = kernelStep = int(np.ceil(K/Tj)) # not to be confused with uploaded value
        self.kernelRows = kernelRows = int(np.ceil(K/Ti))
        self.kernelsPerBank = kernelsPerBank = int(np.ceil(M/Tm)*np.ceil(N/Tn)*Tn)
        self.kernelDepthPerBank=kernelDepthPerBank = int(np.ceil((kernelStep*Tj*kernelRows*Ti)/(Tr*Tc)))
        
        self.fmShape = (N,S,S) = featureMap.shape
        self.neuronStep = neuronStep = int(np.ceil(S/Tj)) # number of columns in
        self.neuronRows = neuronRows = int(np.ceil(S/Ti))
        self.depthPerFMPerBank=depthPerFMPerBank = neuronStep*neuronRows
        self.fmsPerBank=fmsPerBank = int(np.ceil(N/Tn))

        ins = []
        getInstruction = lambda ins1, ins2, data: self.instruction.format(self.Opcodes.LOAD_CONSTANTS.value,ins1,ins2,self.FSMControl.HOLD,data)
        ins += [ getInstruction(0,0,self.Tr), \
                getInstruction(0,1,self.Tc), \
                getInstruction(0,2,self.kernelStep*Tj), \
                getInstruction(0,3,self.neuronStep ), \
                getInstruction(1,0,self.P), \
                getInstruction(1,1,int(np.ceil((S-K+1)/(P*self.Tc))))]
        return ins

    def loadKernelBufferInstruction(self,kernel :np.ndarray):
        Ti, Tj, Tn, Tr, Tc, Tm = self.getUnrollingParams()
        D = self.D
        (N,M,K,K) = kernel.shape # expecting np.ndarray (N,M,K,K)
        kernelStep = self.kernelStep
        kernelRows = self.kernelRows
        kernelsPerBank = self.kernelsPerBank
        kernelDepthPerBank = self.kernelDepthPerBank
        if (kernelsPerBank*kernelDepthPerBank) > 2**self.Al:
            raise NotImplemented
        # Prepare banked kernel
        paddingDimensions = (0,0),(0,0),(0,kernelRows*Ti-K),(0,kernelStep*Tj-K)
        # print(kernel)
        kernel = np.pad(kernel,paddingDimensions,'constant', constant_values=0)
        # print(kernel)
        bankedKernel = np.zeros((D,kernelsPerBank,kernelDepthPerBank),dtype=int)
        for n, m in itr.product(range(N),range(M)):
            tn = n%Tn
            tm = m%Tm
            # we first cycle through M
            mCycle = int(m/Tm)
            nCycle = int(n/Tn)
            getBankNumber = lambda tr,tc: tm*Tr*Tc+tr*Tr+tc
            kernelNumberInBank = Tn*int(np.ceil(M/Tm))*nCycle+Tn*mCycle+tn
            for tr,tc in itr.product(range(Tr),range(Tc)):
                # print(tr,tc)
                bankedKernel[getBankNumber(tr,tc), kernelNumberInBank,:] = kernel[n,m,:,:].flat[tr*Tc+tc::Tr*Tc]
        # instructions to load banked kernel
        # print(kernel)
        # print(bankedKernel)
        kCtrl,bankSelIns = self.FSMControl.INIT, self.FSMControl.INIT
        getInstruction = lambda kCtrl,bankSelIns,data: self.instruction.format(self.Opcodes.LOAD_K_BUFFER.value,kCtrl,bankSelIns,self.FSMControl.HOLD,data)
        ins = []
        for bankSelect in range(D):
            for data in [bankedKernel[bankSelect,i,j] for i,j in itr.product(range(kernelsPerBank),range(kernelDepthPerBank))] :
                ins += [getInstruction(kCtrl,bankSelIns,data if data >= 0 else (1<<(self.W)) + data )]
                kCtrl,bankSelIns = self.FSMControl.INCR, self.FSMControl.HOLD
            kCtrl,bankSelIns = self.FSMControl.INIT, self.FSMControl.INCR
        return ins

    def loadNeuronBufferInstruction(self, featureMap: np.ndarray):
        Ti, Tj, Tn, Tr, Tc, Tm = self.getUnrollingParams()
        D = self.D
        fmShape = (N,S,S) = featureMap.shape
        neuronStep = self.neuronStep
        neuronRows = self.neuronRows
        depthPerFMPerBank = self.depthPerFMPerBank
        fmsPerBank = self.fmsPerBank
        if (neuronDepthPerBank:= depthPerFMPerBank*fmsPerBank) > 2**self.Al:
            raise NotImplemented
        self.neuronDepthPerBank = neuronDepthPerBank
        # Prepare banked feature map
        paddingDimensions = (0,0),(0,neuronRows*Ti-S),(0,neuronStep*Tj-S)
        # paddingDimensions = (0,0),(0,neuronRows*Ti-S+Ti),(0,neuronStep*Tj-S+Tj)
        featureMap = np.pad(featureMap, paddingDimensions,'constant',constant_values=0)
        bankedFM = np.zeros((D,fmsPerBank,depthPerFMPerBank),dtype=int)
        for n in range(N):
            tn = n%Tn
            nCycle = int(n/Tn)
            getBankNumber = lambda ti,tj: tn*Ti*Tj+Tj*ti+tj
            for ti,tj in itr.product(range(Ti),range(Tj)):
                bankedFM[getBankNumber(ti,tj),nCycle,:] = featureMap[n,ti::Ti,tj::Tj].flat[:]
        # print(bankedFM )
        # instructions to load banked kernel
        getInstruction = lambda nCtrl, bankSelIns, data: self.instruction.format(self.Opcodes.LOAD_N_BUFFER.value,nCtrl,bankSelIns,self.FSMControl.HOLD,data if data >= 0 else (1<<(self.W)) + data)
        nCtrl, bankSelectIns = self.FSMControl.INIT, self.FSMControl.INIT
        ins = []
        for bankSelect in range(D):
            for data in [bankedFM[bankSelect,i,j] for i,j in itr.product(range(fmsPerBank),range(depthPerFMPerBank))] :
                ins += [getInstruction(nCtrl,bankSelectIns,data)]
                # print([bankSelect], data, ins[-1])
                nCtrl,bankSelectIns = self.FSMControl.INCR, self.FSMControl.HOLD
            nCtrl,bankSelectIns = self.FSMControl.INIT, self.FSMControl.INCR
        return ins

    def readNeuronBufferInstructions(self):
        D = self.D
        getInstruction = lambda nCtrl, bankSelIns, data: self.instruction.format(self.Opcodes.READ_N_BUFFER.value,nCtrl,bankSelIns,self.FSMControl.HOLD,data if data >= 0 else (1<<(self.W)) + data)
        nCtrl, bankSelectIns = self.FSMControl.INIT, self.FSMControl.INIT
        ins = []
        for bankSelect in range(D):
            for x in range(self.neuronDepthPerBank):
                ins += [getInstruction(nCtrl,bankSelectIns,0)]
                nCtrl,bankSelectIns = self.FSMControl.INCR, self.FSMControl.HOLD
            nCtrl,bankSelectIns = self.FSMControl.INIT, self.FSMControl.INCR
        return ins

    def loadLocalStores(self,resumeFromPrevious:bool):
        Ti, Tj, Tn, Tr, Tc, Tm = self.getUnrollingParams()
        # loading kernel
        kBuffCtrl, bankIns, kLocalCtrl = (self.FSMControl.JUMP,self.FSMControl.INIT,self.FSMControl.INIT) \
            if resumeFromPrevious else (self.FSMControl.INIT,self.FSMControl.INIT,self.FSMControl.INIT) 
        getInstruction = lambda kBuffCtrl, bankIns, kLocalCtrl,kernelColumnSel:\
            self.instruction_LastString.format( \
                self.Opcodes.LOAD_LOCAL_K.value,kBuffCtrl,bankIns, \
                    kLocalCtrl, kernelColumnSel)
        kIns = []
        # at a time we will only have 1 kernel in a PE local store
        # for bankRow in range(self.kernelsPerBank):
        for peGroup in range(Tn):
            kColSelect = ['0']*peGroup*Ti*Tj+['1']*Ti*Tj+['0']*(self.D-(peGroup+1)*Ti*Tj)
            kColSelect = (''.join(kColSelect))[::-1]
            for col in range(self.kernelDepthPerBank):
                for bankSel in range(Tr*Tc):
                    kIns += [getInstruction(kBuffCtrl,bankIns, kLocalCtrl, kColSelect)]
                    kBuffCtrl, bankIns, kLocalCtrl = self.FSMControl.HOLD,self.FSMControl.INCR,self.FSMControl.INCR
                kBuffCtrl, bankIns, kLocalCtrl = self.FSMControl.INCR,self.FSMControl.INIT,self.FSMControl.INCR
        # loading neurons
        nBuffCtrl, nLocalCtrl = (self.FSMControl.JUMP,self.FSMControl.INIT) \
            if resumeFromPrevious else (self.FSMControl.INIT,self.FSMControl.INIT) 
        getInstruction = lambda nBuffCtrl, nLocalCtrl: self.instruction.format\
            (self.Opcodes.LOAD_LOCAL_N.value,nBuffCtrl,self.FSMControl.HOLD,\
                nLocalCtrl, 0)
        nIns = []
        for row in range(self.fmsPerBank):
            for col in range(self.depthPerFMPerBank):
                nIns+=[getInstruction(nBuffCtrl,nLocalCtrl)]
                nBuffCtrl, nLocalCtrl = self.FSMControl.INCR, nLocalCtrl.INCR
            nBuffCtrl, nLocalCtrl = self.FSMControl.INCR, nLocalCtrl.INCR
        return kIns+nIns

    def convolutionInstructions(self):
        Ti, Tj, Tn, Tr, Tc, Tm = self.getUnrollingParams()
        K = self.kShape[2]
        neuronStep = self.neuronStep
        kernelStep = self.kernelStep
        neuronRows = self.neuronRows
        kernelRows = self.kernelRows
        needsAuxInsForRow = lambda kPosnRow,kRow,kCtrl: \
            (kCtrl==self.FSMControl.JUMP)*(kPosnRow < kRow-1) or \
                (kRow != 0)*(kCtrl==self.FSMControl.INIT)
        needsAuxInsForCol = lambda kpos,kCol, kCtrl: \
            (kCtrl==self.FSMControl.INCR)*(kpos[1]<kCol-1) or \
                (kCol!=0)*(kCtrl in [self.FSMControl.INIT,self.FSMControl.JUMP])
        getKernelRowRange = lambda nRow: range(nRow+1) if nRow<kernelRows \
            else (range(nRow-neuronRows+kernelRows,kernelRows) \
                if nRow>neuronRows-kernelRows else range(kernelRows))
        getKernelColumnRange = lambda nCol: range(nCol+1) if nCol<kernelStep \
            else (range(nCol-neuronStep+kernelStep,kernelStep) \
                if nCol>neuronStep-kernelStep else range(kernelStep) )
        getInstruction = lambda kLCtrl, nLCtrl, ins3: self.instruction \
            .format(self.Opcodes.CONVOLVE.value,kLCtrl,nLCtrl,ins3,0)

        updateKernelPosn = lambda kPos,kCtrl: \
            [(a:=(kCtrl != self.FSMControl.INIT))*(kPos[0]+(kCtrl==self.FSMControl.JUMP)), a*(kPos[1]+(kCtrl==self.FSMControl.INCR)*(kCtrl!=self.FSMControl.JUMP)) ]
        kCtrl, nCtrl = self.FSMControl.INIT, self.FSMControl.INIT
        ins = []
        kPos = np.zeros(2,dtype=int)
        for nRow in range(neuronRows):
            kerneRowlRange = getKernelRowRange(nRow)
            for nCol in range(neuronStep):
                kernelColRange = getKernelColumnRange(nCol)
                for kRow in kerneRowlRange:
                    while needsAuxInsForRow(kPos[0],kRow,kCtrl):
                        ins3 = 0
                        ins += [getInstruction(kCtrl,nCtrl,ins3)]
                        kPos = updateKernelPosn(kPos,kCtrl)
                        kCtrl, nCtrl = self.FSMControl.JUMP, self.FSMControl.HOLD    
                    for kcol in kernelColRange:
                        while needsAuxInsForCol(kPos,kcol,kCtrl):
                            ins3 = 1
                            ins += [getInstruction(kCtrl,nCtrl,ins3)]
                            kPos = updateKernelPosn(kPos,kCtrl)
                            kCtrl, nCtrl = self.FSMControl.INCR, self.FSMControl.HOLD    
                        ins3 = 3
                        ins += [getInstruction(kCtrl,nCtrl,ins3)]
                        kPos = updateKernelPosn(kPos,kCtrl)
                        kCtrl, nCtrl = self.FSMControl.INCR, self.FSMControl.HOLD    
                    kCtrl, nCtrl = self.FSMControl.JUMP, self.FSMControl.HOLD
                kCtrl, nCtrl = self.FSMControl.INIT, self.FSMControl.INCR
            kCtrl, nCtrl = self.FSMControl.INIT, self.FSMControl.JUMP
        return ins

    def poolingInstructions(self):
        Ti, Tj, Tn, Tr, Tc, Tm = self.getUnrollingParams()
        D = self.D
        So = self.fmShape[1] - self.kShape[2] + 1
        P = self.P
        setUseLower = lambda useLower: self.instruction_LastString.format(self.Opcodes.POOL.value,self.FSMControl.HOLD,self.FSMControl.HOLD,0,useLower)
        setUseCurrent = lambda nCtrl, pCtrl,useCurr: self.instruction_LastString.format(self.Opcodes.POOL.value,nCtrl,pCtrl,1,useCurr)
        setUseUpper = lambda useUpper: self.instruction_LastString.format(self.Opcodes.POOL.value,self.FSMControl.HOLD,self.FSMControl.HOLD,2,useUpper)
        setPoolWrite = lambda  poolWrite: self.instruction_LastString.format(self.Opcodes.POOL.value,self.FSMControl.HOLD,self.FSMControl.HOLD,3,poolWrite)

        ins = [self.getInstructionString(self.Opcodes.RESET_POOLING_REG.value,0,0,0,0)]
        nCtrl, pCtrl = self.FSMControl.INIT, self.FSMControl.INIT
        # useLower = ''.join((['1']*(Tr*Tc-1)+['0'])*Tm+['0']*(D-Tm*Tr*Tc))
        # useUpper = ''.join((['0']+['1']*(Tr*Tc-1))*Tm+['0']*(D-Tm*Tr*Tc))
        # ins += [setUseLower(useLower),setUseUpper(useUpper)]
        for nRow in range(int(np.ceil(So/(P*Tr)))):
            for nCol in range(int(np.ceil(So/(P*Tc)))):
                pass
                for pRow in range(P):
                    for pCol in range(P):
                        # this block is supposed to cover every row output
                        top = (pRow*Tc, pCol*Tr)
                        poolRowRange = range(  int(top[0]/P), \
                            int(np.ceil((top[0]+Tc)/P)) )
                        poolColRange = range(  int(top[1]/P), \
                                    int(np.ceil((top[1]+Tr)/P)) )
                        # list of PEs for which write is possible
                        for x,y in itr.product(poolRowRange,poolColRange):
                            useCurrent = ['1' if int((top[0]*x+i)/P) == x and \
                                int((top[1]*y+j)/P) == y else '0' for i,j \
                                    in itr.product(range(Tc), range(Tr))]*Tm +\
                                        ['0']*(D-Tm*Tr*Tc)
                            poolWrite = ['0']*Tr*Tc
                            poolWrite[x*Tc+y] = '1'
                            poolWrite = poolWrite*Tm + ['0']*(D-Tm*Tr*Tc)
                            useLower = ['1' if i >= x*Tc+y else '0' for i in range(Tr*Tc)]*Tm+['0']*(D-Tm*Tr*Tc)
                            useUpper = ['1' if i <= x*Tc+y else '0' for i in range(Tr*Tc)]*Tm+['0']*(D-Tm*Tr*Tc)
                            poolWrite   = (''.join(poolWrite))[::-1]
                            useUpper    = (''.join(useUpper))[::-1]
                            useCurrent  = (''.join(useCurrent))[::-1]
                            useLower    = (''.join(useLower))[::-1]
                            ins += [setUseCurrent(nCtrl,pCtrl,useCurrent)]
                            ins += [setUseUpper(useUpper)]
                            ins += [setUseLower(useLower)]
                            ins +=[setPoolWrite(poolWrite)]
                            nCtrl, pCtrl = self.FSMControl.HOLD, self.FSMControl.HOLD
                        nCtrl, pCtrl = self.FSMControl.HOLD, self.FSMControl.INCR
                    nCtrl, pCtrl = self.FSMControl.HOLD, self.FSMControl.JUMP
                ins += [ins[0]] # reset pooling registers
                nCtrl, pCtrl = self.FSMControl.INCR, self.FSMControl.INIT
            nCtrl, pCtrl = self.FSMControl.JUMP, self.FSMControl.INIT
        return ins
    
    def divideConvUnitInstructions(self):
        Ti, Tj, Tn, Tr, Tc, Tm = self.getUnrollingParams()
        D = self.D
        ins = []
        groups = Tn
        getInstruction = lambda ins1, value, rowSel, colSel: self.instruction_LastString.format(self.Opcodes.DIVIDE_CONV_UNIT.value, ins1, value, rowSel, colSel)
        rowForTj = np.array([j for j in range(Tj)]*groups*Ti+[0]*(D-Ti*Tj*Tn))
        rowForTi = np.array([i for i in range(Ti) for x in range(Tj)]*groups+[0]*(D-Ti*Tj*Tn))
        # Neuron Col offset
        ins1 = self.FSMControl.N_COL_OFFSET
        for j in range(Tj):
            colSel = np.array(['0']*D)
            colSel[rowForTj == j] = '1'
            colSel = (''.join(colSel))[::-1]
            # valueByRow = [int((Tj+x%Tc-j-1)/Tj) for x in range(Tc)]*Tm*Tr+[0]*(D-Tr*Tc*Tm)
            valueByRow = [int(tc>j) for tc in range(Tc)]*Tm*Tr+[0]*(D-Tr*Tc*Tm)
            for rowSel in range(D):
                ins += [getInstruction(ins1,valueByRow[rowSel],rowSel,colSel)]
        # neuron Row offset
        ins1 = self.FSMControl.N_ROW_OFFSET
        for i in range(Ti):
            colSel = np.array(['0']*D)
            colSel[rowForTi == i] = '1'
            colSel = (''.join(colSel))[::-1]
            # valueByRow = [int((Tc+int(x/Tc)-i-1)/Tc) for x in range(Tc*Tr)]*Tm+[0]*(D-Tr*Tc*Tm)
            valueByRow = [int(tr>i) for tr,tc in itr.product(range(Tr),range(Tc))]*Tm+[0]*(D-Tr*Tc*Tm)
            for rowSel in range(D):
                ins += [getInstruction(ins1,valueByRow[rowSel],rowSel,colSel)]
        # Kernel Col Offset
        ins1 = self.FSMControl.K_COL_OFFSET
        for j in range(Tj):
            colSel = np.array(['0']*D)
            colSel[rowForTj == j] = '1'
            colSel = (''.join(colSel))[::-1]
            valueByRow = [(j-tc)%Tc for tc in range(Tc)]*Tr*Tm +[0]*(D-Tr*Tc*Tm)
            for rowSel in range(D):
                ins += [getInstruction(ins1,valueByRow[rowSel],rowSel,colSel)]
        # Kernel Row offset
        ins1 = self.FSMControl.K_ROW_OFFSET
        for i in range(Ti):
            colSel = np.array(['0']*D)
            colSel[rowForTi == i] = '1'
            colSel = (''.join(colSel))[::-1]
            valueByRow = [(i-tr)%Ti for tr,tc in itr.product(range(Tr),range(Tc))]*Tm+[0]*(D-Tr*Tc*Tm)
            for rowSel in range(D):
                ins += [getInstruction(ins1,valueByRow[rowSel],rowSel,colSel)]
        return ins

    def getInstructions(self, kernel: np.ndarray, featureMap: np.ndarray,P:int):
        ins = []
        ins += self.loadConstants(kernel.shape, featureMap.shape, P)
        ins += self.loadKernelBufferInstruction(kernel)
        # ins += self.loadNeuronBufferInstruction(np.zeros(featureMap.shape, dtype=int))
        # ins += self.readNeuronBufferInstructions()
        # ins += [self.getInstructionString(self.Opcodes.CHANGE_READ_BUFF.value,0,0,0,0) ]
        ins += self.loadNeuronBufferInstruction(featureMap)
        # ins += self.readNeuronBufferInstructions()
        ins += self.loadLocalStores(False)
        ins += self.divideConvUnitInstructions()
        ins += self.convolutionInstructions()
        ins += [self.getInstructionString(self.Opcodes.CHANGE_READ_BUFF.value,0,0,0,0) ]
        ins += self.readNeuronBufferInstructions()
        ins += self.poolingInstructions()
        ins += [self.getInstructionString(self.Opcodes.CHANGE_READ_BUFF.value,0,0,0,0) ]
        ins += self.readNeuronBufferInstructions()
        return ins


depth = 2
W = 16
Al = 7
Ab = 11
Tr, Tc = 2, 2
Ti, Tj = 2, 2
Tm, Tn = 1, 1
P = 2

# edgeDetectionKernel = np.array([[[[-1,-1,-1],[-1,9,-1],[-1,-1,-1]]]],dtype=int)
# edgeDetectionKernel = np.array([[[[1,0,0],[0,0,0],[0,0,0]]]])
# edgeDetectionKernel = np.array([[[[1,1,1],[1,1,1],[1,1,1]]]],dtype=int)
edgeDetectionKernel = np.array([[[[1,2,3],[4,5,6],[7,8,9]]]])
# print(edgeDetectionKernel.shape)
fmShape = (1,8,8)
featureMap = np.arange(np.prod(fmShape),dtype=int).reshape(fmShape)

print(featureMap)
accelerator = FlexFowAccelerator(depth,W,Al,Ab)
accelerator.setUnrollingParams(Ti, Tj, Tn, Tr, Tc, Tm)

ins = [0]
# ins = accelerator.getInstructions(edgeDetectionKernel,featureMap, P)
# ins = [0]

for i in ins:
    print(i)
