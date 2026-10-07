numeric digits 50
c=.Circuit~new
r1=c~add(.Resistor~new('R1','1 kohm'))
r2=c~add(.Resistor~new('R2','2 kohm'))
c~connect('SIG', .array~of(r1~pins[2],r2~pins[1]))
fp=.PCBFootprintDefinition~new('R_AXIAL')
fp~addPad(.PCBPadDefinition~new('1','A',-2.5,0))
fp~addPad(.PCBPadDefinition~new('2','B', 2.5,0))
p1=.PCBPlacement~new(r1,fp,10,10,0,'TOP')
p1~bind(r1~pins[1],'1')~bind(r1~pins[2],'2')
p2=.PCBPlacement~new(r2,fp,25,10,180,'TOP')
p2~bind(r2~pins[1],'1')~bind(r2~pins[2],'2')
b=.PCBBoard~new('BOARD1',40,20)
b~addPlacement(p1)~addPlacement(p2)
e1=b~endpointForPin(r1~pins[2]); e2=b~endpointForPin(r2~pins[1])
if e1 == .nil | e2 == .nil then call fail 'net endpoints not materialized'
b~route(c~net('SIG'),e1,e2,'F.Cu',0.25)
rep=.PCBBoardVerifier~verify(b,c)
if \rep~ok then call fail 'valid board graph rejected: errors=' || rep~errorCount
bad=.PCBBoard~new('BAD',40,20)
bad~addPlacement(p1)~addPlacement(p2)
rep=.PCBBoardVerifier~verify(bad,c)
if rep~ok then call fail 'unrouted electrical net accepted'
say 'PASS pcb board graph/connectivity foundation'
exit 0
fail: procedure
 parse arg message
 say 'FAIL:' message
 exit 1
::requires 'RexxTronicsDC.cls'
::requires 'PCBPlanner.cls'
