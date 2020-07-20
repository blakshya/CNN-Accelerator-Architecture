'''
input ports

'''
'''
order of ports
    adderIn,controlSignal,initSettings,peConfig,kernelIn,neuronIn
'''

def getTestInsToLoad(W,A,depth,D,adderIn,initSettings,Tc,Tr,kernelStep,neuronStep):
    ins = []
    kWrite = 0
    nWrite = 0
    kControl = 0
    nControl = 0
    kernelIn = 0
    neuronIn = 0
    ins += [controlString.format(adderIn, kControl, kWrite, nControl, nWrite, initSettings, Tc, Tr,kernelStep,neuronStep,kernelIn,neuronIn) for kControl in (4,5)]
    ins += [controlString.format(adderIn, kControl, kWrite, nControl, nWrite, initSettings, Tc, Tr,kernelStep,neuronStep,kernelIn,neuronIn) for nControl in (6,7)]
    kWrite = 1
    nWrite = 1
    kControl = 0
    nControl = 0
    ins += [controlString.format(adderIn, kControl, kWrite, nControl, nWrite, initSettings, Tc, Tr,kernelStep,neuronStep,kernelIn,neuronIn)]
    kControl = 2
    nControl = 2
    # ins += [controlString.format(adderIn, kControl, kWrite, nControl, nWrite, initSettings, Tc, Tr,kernelStep,neuronStep,kernelIn,neuronIn) for (kernelIn,neuronIn) in zip(reversed(range(2*A)),reversed(range(2*A)))]
    kernelIn = 1
    ins += [controlString.format(adderIn, kControl, kWrite, nControl, nWrite, initSettings, Tc, Tr,kernelStep,neuronStep,kernelIn,neuronIn) for (neuronIn) in (range(2**A))]

    kWrite = 0
    nWrite = 0
    kControl = 0
    nControl = 0
    kernelIn = 0
    neuronIn = 0
    ins += [controlString.format(adderIn, kControl, kWrite, nControl, nWrite, initSettings, Tc, Tr,kernelStep,neuronStep,kernelIn,neuronIn)]
    kControl = 2
    nControl = 2
    ins += [controlString.format(adderIn, kControl, kWrite, nControl, nWrite, initSettings, Tc, Tr,kernelStep,neuronStep,kernelIn,neuronIn) for (kernelIn,neuronIn) in zip(reversed(range(2**A)),reversed(range(2**A)))]
    return ins

W = 16
A = 7
depth = 4
D = 2**depth
FP_LOC = 0

controlString = '''{:0%db}\
{:03b}{:01b}{:03b}{:01b}\
{:0%db}\
{:0%db}{:0%db}{:0%db}{:0%db}\
{:0%db}{:0%db}'''%(
    W,    # adderIn
    depth,              # initSettings
    depth, depth, A, A, # {Tc, Tr, kernelStep}{neuronStep}
    W, W                # {kernelIn}{neuronIn}
)

# print(controlString)

adderIn = 0
initSettings = 0
Tc = 1
Tr = 1
kernelStep = 5
neuronStep = 5

# controlString.format(adderIn, kControl, kWrite, nControl, nWrite, initSettings, Tc, Tr,kernelStep,neuronStep,kernelIn,neuronIn)


ins = getTestInsToLoad(W,A,depth,D,adderIn,initSettings,Tc,Tr,kernelStep,neuronStep)

print(ins)

filename = 'instructions'
with open(filename+'.txt','w') as f:
        for i in ins:
            f.write('%s\n'%i)