numeric digits 30
::class GuitarAcousticBlockFeedbackDriver public
::method init
 expose _projection _continuation _coupling _ledger
 use strict arg dynamicsProjection,forceCoupling,method='SYMPLECTIC_EULER'
 _projection=dynamicsProjection; _continuation=dynamicsProjection~continuationFromCurrentState(method); _coupling=forceCoupling; _ledger=.array~new
::method continuation; expose _continuation; return _continuation
::method ledger; expose _ledger; return _ledger~copy
::method advancePressureBlock
 expose _projection _continuation _coupling _ledger
 use strict arg dt,pressureSamples,pathEvidence=.nil,source=.nil
 if dt<=0 then raise syntax 88.900 array('positive acoustic block timestep',dt)
 if pressureSamples==.nil | \pressureSamples~isA(.array) then raise syntax 88.900 array('pressure sample Array')
 if pressureSamples~items<2 then raise syntax 88.900 array('at least two pressure samples')
 steps=pressureSamples~items-1; forces=_projection~acousticForceHistory(pressureSamples,_coupling)
 tr=_projection~advanceContinuationBlock(_continuation,dt,steps,forces)
 ev=.directory~new; ev['END_TIME_S']=tr~finalState~time; ev['STEPS']=steps; ev['PRESSURE_SAMPLE_COUNT']=pressureSamples~items
 ev['PATH_EVIDENCE']=pathEvidence; ev['SOURCE']=source; ev['MATHS_EVIDENCE']=tr~evidence; ev['COUPLING_EVIDENCE']=_coupling~evidence
 _ledger~append(ev); return ev
::method snapshot
 expose _continuation _ledger
 d=.directory~new; d['SCHEMA']='physics.guitar-acoustic-block-feedback/1'; d['CONTINUATION']=_continuation~snapshot; d['LEDGER_ITEMS']=_ledger~items; return d
::method restore
 expose _continuation
 use strict arg snapshot
 if snapshot['SCHEMA']<>'physics.guitar-acoustic-block-feedback/1' then raise syntax 88.900 array('guitar acoustic block feedback snapshot schema')
 _continuation~restore(snapshot['CONTINUATION']); return self
::requires 'GuitarAcousticFeedback.cls'
::requires 'GuitarMathsDynamics.cls'
