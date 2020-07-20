'''
input ports

'''
'''
order of ports
    {controlSignal,initSettings,peConfig}
'''

W = 16
A = 7
depth = 2
D = 2**depth
FP_LOC = 5

controlString = '''\
{:03b}{:01b}{:03b}{:01b}\
{:0%db}\
{:0%db}{:0%db}{:0%db}{:0%db}'''%(
    depth,              # initSettings
    depth, depth, A, A, # {Tc, Tr, kernelStep}{neuronStep}
)
# controlString.format(kControl, klWrite, nControl, nWrite, initSettings, Tc, Tr,kernelStep,neuronStep)

def getTestInsToLoad(initSettings,Tc,Tr,kernelStep,neuronStep):
    ins = []
    kWrite = 1
    nWrite = 1
    kControl = 0
    nControl = 0
    ins += [controlString.format(kControl, kWrite, nControl, nWrite, initSettings, Tc, Tr,kernelStep,neuronStep) for kControl in (4,5)]
    ins += [controlString.format(kControl, kWrite, nControl, nWrite, initSettings, Tc, Tr,kernelStep,neuronStep) for nControl in (6,7)]
    kControl = 0
    nControl = 0
    ins += [controlString.format(kControl, kWrite, nControl, nWrite, initSettings, Tc, Tr,kernelStep,neuronStep) for (kernelIn,neuronIn) in zip(range(D),range(D))]
    kControl = 2
    nControl = 2
    ins += [controlString.format(kControl, kWrite, nControl, nWrite, initSettings, Tc, Tr,kernelStep,neuronStep) for (kernelIn,neuronIn) in zip(range(D),range(D))]

    kWrite = 0
    nWrite = 0
    kControl = 0
    nControl = 0
    ins += [controlString.format(kControl, kWrite, nControl, nWrite, initSettings, Tc, Tr,kernelStep,neuronStep)]
    kControl = 2
    nControl = 2
    ins += [controlString.format(kControl, kWrite, nControl, nWrite, initSettings, Tc, Tr,kernelStep,neuronStep)]*D

    return ins

initSettings = 0
Tc = 2
Tr = 2
kernelStep = 0
neuronStep = 0

ins = getTestInsToLoad(initSettings,Tc,Tr,kernelStep,neuronStep)

print(ins)

filename = 'instructions'
with open(filename+'.txt','w') as f:
        for i in ins:
            f.write('%s\n'%i)