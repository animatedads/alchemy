numeric digits 50
parts=.CommonParts~standardBenchSet
if parts~items <> 29 then call fail 'expected 29 starter parts'
r=parts['R_1K_5_025W']
if r~family <> 'RESISTOR' then call fail 'resistor family'
if r~material('LEAD') <> 'CU-C110-REFERENCE' then call fail 'resistor lead material'
if r~manufacturing['TERMINATION'] <> 'THROUGH-HOLE' then call fail 'manufacturing metadata'
b=.CommonParts~boltM6x30
if b~family <> 'FASTENER' then call fail 'bolt family'
if b~parameter('PITCH') <> '1 mm' then call fail 'bolt pitch'
p=.CommonParts~plateAl6061T6
if p~parameter('MASS') <> '40.5 g' then call fail 'plate mass'
br=.CommonParts~bearing608
if br~parameter('BORE_DIAMETER') <> '8 mm' then call fail 'bearing geometry'
say 'PARTS CATALOG: OK'
exit 0
fail: procedure
  parse arg m
  say 'FAIL:' m
  exit 1
::requires 'PartsCatalog.cls'
