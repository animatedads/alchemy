numeric digits 50
catalog=.CommonPartFamilies~representativeCatalog
if catalog~items <> 13 then call fail 'representative family count'
do p over catalog
  if p~validate <> .true then call fail 'invalid part definition'
  if p~parameters~hasIndex('MATERIAL_ID') then do
    m=.CommonMaterials~byId(p~parameter('MATERIAL_ID'))
    if m=.nil then call fail 'unresolved material' p~parameter('MATERIAL_ID')
  end
  do role over p~materials~allIndexes
    m=.CommonMaterials~byId(p~materials[role])
    if m=.nil then call fail 'unresolved material role' role p~materials[role]
  end
end
b=.CommonPartFamilies~metricFastener('M12',50,'HEX_BOLT','12.9')
if b~parameter('PITCH')~in(.Units~millimetre) <> 1.75 then call fail 'M12 pitch'
if b~parameter('HEAD_SHEAR_CAPACITY_N') <= 0 then call fail 'derived fastener capacity'
s=.CommonPartFamilies~compressionSpring(1,10,8,25)
if s~parameter('SPRING_RATE_N_PER_M') <= 0 then call fail 'derived spring rate'
g=.CommonPartFamilies~spurGear(1,20,20)
if g~parameter('PITCH_DIAMETER')~in(.Units~millimetre) <> 20 then call fail 'gear pitch diameter'
w=.CommonPartFamilies~wire('22AWG',1)
if w~parameter('RESISTANCE_OHM') <= 0 then call fail 'wire resistance'
ic=.CommonPartFamilies~packageDIP(14)
if ic~parameter('PINS') <> 14 then call fail 'DIP package pins'
say 'PASS parameterised family catalogue' catalog~items
exit 0
fail: procedure
  parse arg m
  say 'FAIL:' m
  exit 1
::requires '../src/PartsFamilies.cls'
