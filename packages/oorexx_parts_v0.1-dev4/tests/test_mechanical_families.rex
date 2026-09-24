sizes=.array~of('M2','M2.5','M3','M4','M5','M6','M8','M10','M12')
do s over sizes
  b=.CommonParts~metricBolt(s,'30 mm','STEEL-8.8-REFERENCE')
  if b~parameter('PITCH')='' then call fail 'bolt pitch'
  if b~parameter('HEAD_SHEAR_CAPACITY_N')<=0 then call fail 'bolt capacity'
end
series=.array~of('608','6000','6001','6002','6200','6201','6202','6203','6204')
do n over series
  b=.CommonParts~bearingDeepGroove(n,'2RS')
  if b~geometry['BORE']='' then call fail 'bearing geometry'
end
shaft=.CommonParts~roundShaft('8 mm','250 mm','SS-304-REFERENCE')
if shaft~material('BODY')<>'SS-304-REFERENCE' then call fail 'shaft material'
plate=.CommonParts~rectangularPlate('200 mm','100 mm','6 mm','AL-6061-T6')
if plate~material('BODY')<>'AL-6061-T6' then call fail 'plate material'
spring=.CommonParts~compressionSpring('1 mm','10 mm',8,'30 mm','STEEL-MILD-REFERENCE')
if spring~family<>'SPRING' then call fail 'spring family'
say 'PASS mechanical families' sizes~items 'bolt sizes,' series~items 'bearing series'
exit 0
fail: procedure
 parse arg m; say 'FAIL:' m; exit 1
::requires 'PartsCatalog.cls'
