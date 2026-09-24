d=.CommonParts~rectangularPlate('100 mm','50 mm','3 mm','AL-6061-T6')
p=.ManufacturedPartProjection~new('WORKPIECE-1',d,'state://initial')
if p~definitionId<>d~id then call fail 'origin identity'
r=p~advanceState('state://machined-1')
if r<>1 then call fail 'revision'
if p~definitionId<>d~id then call fail 'definition mutated'
if p~stateRef<>'state://machined-1' then call fail 'state ref'
say 'PASS manufactured projection immutable origin / mutable state reference'
exit 0
fail: procedure
 parse arg m; say 'FAIL:' m; exit 1
::requires 'ManufacturedPartProjection.cls'
