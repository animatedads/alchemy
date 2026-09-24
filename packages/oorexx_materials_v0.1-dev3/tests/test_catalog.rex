numeric digits 30
a=.CommonMaterials~catalog
if a~items<>33 then call fail 'catalog count'
do m over a
  if \m~validate then call fail 'validation'
end
cu=.CommonMaterials~copper
if cu~value('DENSITY')<>8960 then call fail 'copper density'
if \cu~quantity('DENSITY')~dimension~compatible(.Units~kilogramPerCubicMetre~dimension) then call fail 'density dimension'
w=.CommonMaterials~water20C
if w~value('DYNAMIC_VISCOSITY')<0.001 then call fail 'water viscosity'
pc=.CommonMaterials~polycarbonate
if pc~value('YOUNG_MODULUS')<>2300000000 then call fail 'polycarbonate modulus'
if pc~value('YIELD_STRESS')<>65000000 then call fail 'polycarbonate yield stress'
cf=.CommonMaterials~carbonFiberEpoxy
if cf~value('DENSITY')<>1600 then call fail 'CFRP density'
cc=.CommonMaterials~concreteC30
if cc~value('COMPRESSIVE_STRENGTH')<>30000000 then call fail 'concrete strength'
if .CommonMaterials~stainless304~value('YIELD_STRESS')<>215000000 then call fail 'stainless yield stress'
if .CommonMaterials~steelFastener88~value('YIELD_STRESS')<>640000000 then call fail 'fastener steel yield stress'
say 'PASS materials catalog' a~items 'definitions'
exit 0
fail: procedure
  parse arg msg
  say 'FAIL:' msg
  exit 1
::requires "Units.cls"
::requires "../src/MaterialsCatalog.cls"
