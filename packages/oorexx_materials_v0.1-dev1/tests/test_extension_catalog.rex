numeric digits 50
pc=.CommonMaterials~polycarbonate
if pc~family <> 'POLYMER' then call fail 'polycarbonate family'
if pc~value('YIELD_STRESS') <> 65000000 then call fail 'polycarbonate yield'
cf=.CommonMaterials~carbonFiberEpoxy
if cf~value('DENSITY') <> 1600 then call fail 'CFRP density'
cc=.CommonMaterials~concreteC30
if cc~value('COMPRESSIVE_STRENGTH') <> 30000000 then call fail 'concrete strength'
say 'PASS materials extension catalog'
exit 0
fail: procedure
  parse arg m
  say 'FAIL:' m
  exit 1
::requires 'Units.cls'
::requires '../src/MaterialsCatalog.cls'
