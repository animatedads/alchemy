b=.CommonParts~rugbyLeagueBall
if b~family<>'SPORTS_BALL' then call fail 'family'
roles=.array~of('BLADDER','REINFORCEMENT','COVER','VALVE','INFLATION_GAS')
do role over roles
  id=b~material(role)
  if .CommonMaterials~byId(id)=.nil then call fail 'unresolved material' role id
end
if b~parameter('SHAPE')='SPHERE' then call fail 'rugby ball must not be sphere'
p=.SportsBallProjection~rugbyLeague(b)
if \p['ORIENTATION_MODEL_REQUIRED'] then call fail 'orientation requirement'
if \p['SPIN_MODEL_REQUIRED'] then call fail 'spin requirement'
say 'PASS rugby league ball layered materials and Physics projection boundary'
exit 0
fail: procedure
 parse arg m; say 'FAIL:' m; exit 1
::requires 'SportsBallProjection.cls'
