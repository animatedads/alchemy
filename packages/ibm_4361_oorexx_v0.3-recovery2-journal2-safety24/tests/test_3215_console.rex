numeric digits 30
s=.IBM370Storage~new(65536)
c=.IBM370ChannelSubsystem~new
d=.IBM3215Device~new(x2d('001F'))
c~attach(d)
/* NOP proves an attached/connected console can complete channel I/O. */
s~storeHex(x2d('48'),'00000100')
s~storeHex(x2d('100'),'0300000000000000')
call ae 0,c~startIO(x2d('001F'),s),'SIO NOP'
c~stepProgram(x2d('001F'),s)
call ae 1,c~completedStatusCount,'NOP completion'
call ae 1,c~testIO(x2d('001F'),s),'TIO NOP'
call ae '0C',s~fetchHex(x2d('44'),1),'NOP unit status'
/* Empty Read Inquiry remains an active CCW, then completes when keyboard data arrives. */
s~storeHex(x2d('48'),'00000108')
s~storeHex(x2d('108'),'0A00020000000008')
call ae 0,c~startIO(x2d('001F'),s),'SIO read inquiry'
c~stepProgram(x2d('001F'),s)
call ae 1,c~hasActiveProgram(x2d('001F')),'read remains pending'
call ae 0,c~completedStatusCount,'no completion while pending'
d~queueInputHex('C8C5D3D3D6')
c~stepProgram(x2d('001F'),s)
call ae 0,c~hasActiveProgram(x2d('001F')),'read completed'
call ae 1,c~completedStatusCount,'read completion queued'
call ae 'C8C5D3D3D6',s~fetchHex(x2d('200'),5),'keyboard bytes'
call ae 1,c~testIO(x2d('001F'),s),'TIO read'
call ae '0003',s~fetchHex(x2d('46'),2),'read residual'
/* Sense ID follows Hercules 2.17.1 3215 device identity. */
s~storeHex(x2d('48'),'00000110')
s~storeHex(x2d('110'),'E400030000000007')
call ae 0,c~startIO(x2d('001F'),s),'SIO sense ID'
c~stepProgram(x2d('001F'),s)
call ae 'FF321500321500',s~fetchHex(x2d('300'),7),'sense id'
say 'PASS test_3215_console'
exit 0
ae: procedure
 parse arg e,a,l
 if e\==a then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end
return
::requires 'IBM370Architecture.cls'
::requires 'IBM370IO.cls'
