a=.CommonAssemblies~shaftBearingPulley
if \a~validate then call fail 'assembly validation'
if a~members~items<>4 then call fail 'member count'
if a~connections~items<>3 then call fail 'connection count'
if a~member('SHAFT')~definition~family<>'SHAFT' then call fail 'shaft identity'
if a~member('BEARING')~definition~family<>'BEARING' then call fail 'bearing identity'
if a~member('PULLEY')~definition~family<>'TIMING_PULLEY' then call fail 'pulley identity'
if a~member('SHAFT')~interface('JOURNAL')~geometry['DIAMETER']<>'8 mm' then call fail 'shaft journal'
say 'PASS assembly identity/interfaces' a~members~items 'members' a~connections~items 'connections'
exit 0
fail: procedure
 parse arg m; say 'FAIL:' m; exit 1
::requires 'PartAssemblies.cls'
