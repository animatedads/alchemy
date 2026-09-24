numeric digits 50
parts=.CommonParts~standardBenchSet
if parts~items <> 19 then call fail 'expected 19 starter parts'
r=parts['R_1K_5_025W']
if r~family <> 'RESISTOR' then call fail 'resistor family'
if r~material('LEAD') <> 'copper' then call fail 'resistor lead material'
if r~manufacturing['TERMINATION'] <> 'THROUGH-HOLE' then call fail 'manufacturing metadata'
b=.CommonParts~boltM6x30
if b~family <> 'FASTENER' then call fail 'bolt family'
if b~parameter('PITCH') <> '1 mm' then call fail 'bolt pitch'
p=.CommonParts~plateAl6061T6
if p~parameter('MASS') <> '40.5 g' then call fail 'plate mass'
br=.CommonParts~bearing608
if br~parameter('STATIC_LOAD_RATING') <> '1370 N' then call fail 'bearing rating'
say 'PARTS CATALOG: OK'
exit 0
fail: procedure
  parse arg m
  say 'FAIL:' m
  exit 1
::requires 'PartsCatalog.cls'
