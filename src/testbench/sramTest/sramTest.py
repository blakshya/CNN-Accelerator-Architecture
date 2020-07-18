import numpy as np
from ctypes import *

def file_float_to_fixed(filename):
	#pass the name of read_file, one line header assumed
	write_file = filename[:-4]+"_fp.txt"
	rf = open(filename,'r')
	wf = open(write_file,'w')
	# rf.readline()
	for l in rf:
		# num = float(l[:-2])
		# num = c_double(float(l[:-2]))
		# fix = c_uint16(clib.float_to_fixed(num))
		# bn = '{0:016b}'.format(fix.value)
		# print(l[:-2]+"\t:"+str(num)+"\t:"+str(fix)+"\t:"+bn)
		bn = '{0:016b}'.format(c_uint16(clib.float_to_fixed(
			c_double(float(l[:-2])))).value)
		wf.write(bn+"\n")

	rf.close()
	wf.close()
	pass

def file_fixed_to_float(filename):
	write_file=filename[:-4]+"_float.txt"
	rf = open(filename,'r')
	wf = open(write_file,'w')
	for l in rf:
		# bn = l[:-1]
		# uint = c_short(int(bn,2))
		# flt = c_double(clib.fixed_to_float(uint))
		# print(l[:-1]+"\t:"+str(uint)+"\t:"+str(flt))
		flt = c_double(clib.fixed_to_float(c_short(int(l[:-1],2)))).value
		wf.write(str(flt)+"\n")
	rf.close()
	wf.close()
	pass
 # cc -fPIC -shared -o my_func.so txt-to-fp.c  -lm

so_file = "/media/lakshya/New Volume/COP/nets/my_func.so"
# so_file = "F:\\COP\\nets\\my_func.so"
# clib = CDLL(so_file) #windows
clib = cdll.LoadLibrary(so_file) #linux

clib.float_to_fixed.restype = c_uint16
clib.fixed_to_float.restype = c_double

file='in.txt'

sz=(64,1)

o=np.random.uniform(low=-1,high=1,size=sz)*8
np.savetxt(file,o,fmt='%0.6f')

file_float_to_fixed(file)
file_fixed_to_float(file[:-4]+"_fp.txt")