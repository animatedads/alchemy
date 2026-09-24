numeric digits 50
parts=.CommonParts~standardBenchSet
if parts~items < 30 then call fail 'expected at least 30 bench parts, got' parts~items
r=parts['R_1K_5_025W']
if r~family <> 'RESISTOR' then call fail 'resistor family'
if r~material('LEAD') <> 'CU-C110-REFERENCE' then call fail 'resistor lead material'
if r~manufacturing['TERMINATION'] <> 'THROUGH-HOLE' then call fail 'manufacturing metadata'
b=.CommonParts~boltM6x30
if b~family <> 'FASTENER' then call fail 'bolt family'
if b~parameter('PITCH') <> '1 mm' then call fail 'bolt pitch'
p=.CommonParts~plateAl6061T6
if p~material('BODY') <> 'AL-6061-T6' then call fail 'plate material'
br=.CommonParts~bearing608
if br~parameter('BORE_DIAMETER') <> '8 mm' then call fail 'bearing bore'
say 'PARTS CATALOG: OK' parts~items 'bench entries'
exit 0
fail: procedure
  parse arg m
  say 'FAIL:' m
  exit 1
::requires 'PartsCatalog.cls'
