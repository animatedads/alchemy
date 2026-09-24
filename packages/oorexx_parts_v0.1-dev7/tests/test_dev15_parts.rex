call assertFamily .CommonParts~inductor('10 mH'), 'INDUCTOR'
call assertFamily .CommonParts~potentiometer('10 kOhm'), 'POTENTIOMETER'
call assertFamily .CommonParts~switchSPST, 'SWITCH'
call assertFamily .CommonParts~transistor2N2222, 'BJT'
call assertFamily .CommonParts~sevenSegmentRed, 'SEVEN_SEGMENT_DISPLAY'

b=.CommonParts~standardBenchSet
if b~items < 13 then call fail 'bench set should contain expanded dev15 parts'

x=.RexxTronicsPartFactory~instantiate(.CommonParts~transistor2N2222,'Q1')
if x~polarity <> 'NPN' then call fail 'BJT projection polarity'
y=.RexxTronicsPartFactory~instantiate(.CommonParts~sevenSegmentRed,'D1')
if y~commonType <> 'COMMON_CATHODE' then call fail 'display projection common type'
z=.RexxTronicsPartFactory~instantiate(.CommonParts~inductor('10 mH'),'L1')
if z~inductanceHenrys <= 0 then call fail 'inductor projection inductance'
say 'PASS dev15 common-parts projections'
exit 0
assertFamily: procedure
  use arg p,e
  if p~family <> e then call fail 'expected family' e
  return
fail: procedure
  use arg m
  say 'FAIL:' m
  exit 1
::requires 'PartsCatalog.cls'
