numeric digits 50
c=.Circuit~new
r1=c~add(.Resistor~new('R1','1 kohm'))
r2=c~add(.Resistor~new('R2','2 kohm'))
c~connect('SIG',.array~of(r1~pins[2],r2~pins[1]))
fp=.PCBFootprintDefinition~new('R_AXIAL')
fp~addPad(.PCBPadDefinition~new('1','A',-2.5,0))
fp~addPad(.PCBPadDefinition~new('2','B', 2.5,0))
p1=.PCBPlacement~new(r1,fp,10,10); p1~bind(r1~pins[1],'1')~bind(r1~pins[2],'2')
p2=.PCBPlacement~new(r2,fp,30,10); p2~bind(r2~pins[1],'1')~bind(r2~pins[2],'2')
b=.PCBBoard~new('INTENT-BOARD',50,30); b~addPlacement(p1)~addPlacement(p2)

s=.PCBIntentionSession~new(b,c)
call assertEquals '0.1-dev11',s~service~version,'current Intention Service contract'
call assertTrue s~hasCapability('VERIFY_BOARD'),'board surface discovered'
call assertFalse s~hasCapability('ROUTE_NETS'),'routing surface absent without manufacturing evidence'
g1=s~generation
unknown=s~input('route board')
call assertEquals 'UNKNOWN',unknown~status,'undiscovered route cannot be selected'

rules=.PCBManufacturingRules~new('PhysicalManufacturing:test-fab',0.20,0.20,0.30,0.60)
b~qualifyForManufacturing(rules)
s~refresh
call assertTrue s~generation>g1,'native discovery generation advanced'
call assertTrue s~hasCapability('ROUTE_NETS'),'routing surface appears after evidence refresh'
call assertEquals 2,s~service~discoverySurfaces~items,'board plus routing surfaces active'
call assertEquals 1,s~service~evidenceFacts(b~id,'MANUFACTURING_RULES')~items,'manufacturing fact is current discovery evidence'
d=s~input('route board')
call assertEquals 'READY',d~status,'route intent ready through transient surface'
call assertEquals s~generation,d~discoveryGeneration,'decision stamped with discovery generation'
tracks=s~dispatch(d)
call assertTrue tracks~items>0,'route intent executes retained PCB objects'

s~refresh
call assertTrue s~hasCapability('VERIFY_ROUTING'),'verification surface appears after routing changes state'
call assertEquals 3,s~service~discoverySurfaces~items,'routing verification surface is transiently active'

b~qualifyForManufacturing(.nil)
s~refresh
call assertFalse s~hasCapability('ROUTE_NETS'),'routing surface disappears when manufacturing evidence withdrawn'
call assertEquals 0,s~service~evidenceFacts(b~id,'MANUFACTURING_RULES')~items,'stale manufacturing discovery evidence removed'
unknown=s~input('route board')
call assertEquals 'UNKNOWN',unknown~status,'withdrawn routing surface cannot propose meaning'
call assertTrue s~hasCapability('VERIFY_ROUTING'),'existing copper remains independently verifiable'

say 'PASS pcb Intention Service dev11 discovery surfaces/evidence freshness'
exit 0
assertTrue: procedure; use arg value,label; if value then return; say 'FAIL' label; exit 1
assertFalse: procedure; use arg value,label; if \value then return; say 'FAIL' label; exit 1
assertEquals: procedure; use arg expected,actual,label; if expected==actual then return; say 'FAIL' label 'expected='expected 'actual='actual; exit 1
::requires 'RexxTronicsDC.cls'
::requires 'PCBIntentions.cls'
