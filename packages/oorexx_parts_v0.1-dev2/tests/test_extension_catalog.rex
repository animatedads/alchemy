numeric digits 50
b=.CommonParts~boltM6x30
if b~family <> 'FASTENER' then call fail 'bolt family'
if b~parameter('TENSILE_STRENGTH') <> '800 MPa' then call fail 'bolt tensile strength'
ss=.CommonParts~boltM6x30('SS-304-REFERENCE')
al=.CommonParts~boltM6x30('AL-6061-T6')
st=.CommonParts~boltM6x30('STEEL-8.8-REFERENCE')
if ss~parameter('MATERIAL_ID') <> 'SS-304-REFERENCE' then call fail 'stainless bolt material'
if al~parameter('MATERIAL_ID') <> 'AL-6061-T6' then call fail 'aluminium bolt material'
if ss~parameter('HEAD_SHEAR_CAPACITY') = al~parameter('HEAD_SHEAR_CAPACITY') then call fail 'head shear material selection'
if st~parameter('HEAD_SHEAR_CAPACITY') <= ss~parameter('HEAD_SHEAR_CAPACITY') then call fail 'head shear steel reference'
if ss~parameter('HEAD_SHEAR_CAPACITY') <= 0 then call fail 'head shear capacity'
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
