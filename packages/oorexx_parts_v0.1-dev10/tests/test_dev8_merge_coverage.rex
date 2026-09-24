checks=.directory~new
checks['NUT']=.CommonParts~metricNut('M6')
checks['NYLOC']=.CommonParts~nylocNut('M6')
checks['THREADED_ROD']=.CommonParts~threadedRod('M8','1 m')
checks['KEY']=.CommonParts~keyStock('6 mm','6 mm','40 mm')
checks['COUPLER']=.CommonParts~jawCoupler('8 mm','8 mm')
checks['LEADSCREW']=.CommonParts~leadScrew('8 mm','2 mm','300 mm')
checks['BELT']=.CommonParts~gt2Belt('400 mm','6 mm')
checks['RACK']=.CommonParts~rack(1,'200 mm')
checks['EXT_SPRING']=.CommonParts~extensionSpring
checks['TORSION_SPRING']=.CommonParts~torsionSpring
checks['SHS']=.CommonParts~squareHollowSection
checks['DIP']=.CommonParts~packageDIP(14)
checks['MOTOR']=.CommonParts~brushedDCMotor
checks['SERVO']=.CommonParts~hobbyServo
checks['RELAY']=.CommonParts~relayPCB
checks['THERMAL_PAD']=.CommonParts~thermalPad
checks['LATHE_INSERT']=.CommonParts~latheInsert
checks['PT100']=.CommonParts~rtdPT100
checks['LOADCELL']=.CommonParts~loadCell
checks['AA']=.CommonParts~batteryAA
checks['18650']=.CommonParts~battery18650
do k over checks
  if checks[k]=.nil then do; say 'FAIL missing merged family' k; exit 1; end
  checks[k]~validate
end
ball=.CommonParts~rugbyLeagueBall
if ball~family<>'SPORTS_BALL' then do; say 'FAIL rugby regression'; exit 1; end
say 'PASS dev8 Grok merge coverage' checks~items 'families plus rugby regression'
exit 0
::requires 'PartsCatalog.cls'
