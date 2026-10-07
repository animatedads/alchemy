numeric digits 50
c=.Circuit~new
r1=c~add(.Resistor~new('R1','1 kohm'))
r2=c~add(.Resistor~new('R2','2 kohm'))
r3=c~add(.Resistor~new('R3','3 kohm'))
c~connect('SIG',.array~of(r1~pins[2],r2~pins[1],r3~pins[1]))
fp=.PCBFootprintDefinition~new('R_AXIAL')
fp~addPad(.PCBPadDefinition~new('1','A',-2.5,0))
fp~addPad(.PCBPadDefinition~new('2','B', 2.5,0))
p1=.PCBPlacement~new(r1,fp,10,10); p1~bind(r1~pins[1],'1')~bind(r1~pins[2],'2')
p2=.PCBPlacement~new(r2,fp,25,15); p2~bind(r2~pins[1],'1')~bind(r2~pins[2],'2')
p3=.PCBPlacement~new(r3,fp,40,20); p3~bind(r3~pins[1],'1')~bind(r3~pins[2],'2')
b=.PCBBoard~new('ROUTER',50,30)
b~qualifyForManufacturing(.PCBManufacturingRules~new('physical-manufacturing:test-process',0.20,0.20,0.30,0.80))
b~addPlacement(p1)~addPlacement(p2)~addPlacement(p3)
made=.PCBDeterministicRouter~routeNet(b,c~net('SIG'),'F.Cu')
if made~items<>2 then call fail 'three endpoint tree should create two deterministic tracks'
do t over made
 if t~widthMm<>0.20 then call fail 'router did not consume process minimum trace width'
 if t~routePoints~items<2 | t~routePoints~items>3 then call fail 'unexpected Manhattan route geometry'
end
rep=.PCBBoardVerifier~verify(b,c)
if \rep~ok then call fail 'manufacturing-qualified deterministic route rejected: ' || rep~errorCount
/* A too-small explicit trace is allowed as a candidate but must fail qualification. */
bad=.PCBBoard~new('BAD',50,30)
bad~qualifyForManufacturing(.PCBManufacturingRules~new('physical-manufacturing:test-process',0.20,0.20,0.30,0.80))
bad~addPlacement(p1)~addPlacement(p2)~addPlacement(p3)
.PCBDeterministicRouter~routeNet(bad,c~net('SIG'),'F.Cu',0.10)
rep=.PCBBoardVerifier~verify(bad,c)
if rep~ok then call fail 'sub-process-minimum copper accepted'
say 'PASS pcb manufacturing projection/deterministic router'
exit 0
fail: procedure
 parse arg message
 say 'FAIL:' message
 exit 1
::requires 'RexxTronicsDC.cls'
::requires 'PCBPlanner.cls'
