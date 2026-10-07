numeric digits 50
c=.Circuit~new
r=c~add(.Resistor~new('R1','1 kohm'))
fp=.PCBFootprintDefinition~new('R_AXIAL')
fp~addPad(.PCBPadDefinition~new('1',r~pins[1]~name,-5,0))
fp~addPad(.PCBPadDefinition~new('2',r~pins[2]~name,5,0))
p=.PCBPlacement~new(r,fp,10,20,180,'TOP')
p~bind(r~pins[1],'1')~bind(r~pins[2],'2')
rep=.PCBIdentityVerifier~verify(p)
if \rep~ok then call fail 'valid mapping rejected'
pos=p~transformedPad('1')
if pos['X_MM'] <> 15 | pos['Y_MM'] <> 20 then call fail 'placement transform wrong'
bad=.PCBPlacement~new(r,fp)
bad~bind(r~pins[1],'2')~bind(r~pins[2],'1')
rep=.PCBIdentityVerifier~verify(bad)
if rep~ok | rep~errorCount <> 2 then call fail 'reversed mapping was not rejected'
say 'PASS pcb identity/orientation foundation'
exit 0
fail: procedure
  parse arg message
  say 'FAIL:' message
  exit 1
::requires 'RexxTronicsDC.cls'
::requires 'PCBPlanner.cls'
