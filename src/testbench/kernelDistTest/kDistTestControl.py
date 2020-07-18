"""
control
    {Trc,bankSelect}
    0 <= bankselect < Trc
"""

depth = 3
D = 2**depth
W = D

depth_str = '{:0%db}'%depth

filename = 'kernelDistributionTest_instructions'

control = [[depth_str.format(trc)+depth_str.format(bank) for bank in range(trc+1)] for trc in range(1,D)]

print(control)

with open(filename+'.txt', 'w') as f:
    for i in control:
        for j in i:
            f.write('%s\n'%j)