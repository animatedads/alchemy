numeric digits 50
b=.CommonParts~boltM6x30
if b~family <> 'FASTENER' then call fail 'bolt family'
if b~parameter('TENSILE_STRENGTH') <> '800 MPa' then call fail 'bolt tensile strength'
p=.CommonParts~plateAl6061T6
if p~parameter('MASS') <> '40.5 g' then call fail 'plate mass'
br=.CommonParts~bearing608
if br~parameter('STATIC_LOAD_RATING') <> '1370 N' then call fail 'bearing static rating'
h=.CommonParts~heatsinkTO220
if h~parameter('THERMAL_RESISTANCE') <> '12 K/W' then call fail 'heatsink thermal resistance'
say 'PASS parts extension catalog'
exit 0
fail: procedure
  parse arg m
  say 'FAIL:' m
  exit 1
::requires 'PartsCatalog.cls'
