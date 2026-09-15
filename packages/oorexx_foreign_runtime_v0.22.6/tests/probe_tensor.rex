np=.ForeignPython~import('numpy')
kw=.ForeignPython~keywords; kw~put('dtype','uint8')
arr=np~arange(8,kw)
t=arr~asTensor
say 'numpy dtype='t~dtype 'device='t~device 'type='t~deviceType 'id='t~deviceId 'shape='t~shape[1]
torch=t~toDLPack('torch')
t2=torch~asTensor
say 'torch dtype='t2~dtype 'device='t2~device 'type='t2~deviceType 'id='t2~deviceId 'shape='t2~shape[1]
np2=t2~toDLPack('numpy')
t3=np2~asTensor
say 'np2 dtype='t3~dtype 'device='t3~device 'type='t3~deviceType 'id='t3~deviceId
::requires '../rexx/python_foreign.cls'
