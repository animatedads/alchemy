/* Physics World v0.1-dev43
 * Acoustic pressure -> guitar strings/body forcing.
 * This closes the physical monitor-speaker feedback loop without inserting
 * synthetic reverb into the audio output.
 */
numeric digits 30

::class GuitarAcousticPressureObservation public
::method init
 expose _time _pressure _source _path _evidence
 use strict arg timeSeconds,pressurePa,source=.nil,pathEvidence=.nil,evidence=.nil
 _time=timeSeconds+0;_pressure=pressurePa+0;_source=source;_path=pathEvidence;_evidence=evidence
::method timeSeconds; expose _time; return _time
::method pressurePa; expose _pressure; return _pressure
::method source; expose _source; return _source
::method pathEvidence; expose _path; return _path
::method evidence; expose _evidence; return _evidence

::class GuitarAcousticForceCoupling public
::method init
 expose _stringArea _bodyArea _stringGain _bodyGain _evidence
 use strict arg effectiveStringAreaM2=.000002,effectiveBodyAreaM2=.045,stringPressureGain=1,bodyPressureGain=1,evidence=.nil
 if effectiveStringAreaM2<0 | effectiveBodyAreaM2<0 then raise syntax 88.900 array('non-negative acoustic effective areas')
 _stringArea=effectiveStringAreaM2+0;_bodyArea=effectiveBodyAreaM2+0
 _stringGain=stringPressureGain+0;_bodyGain=bodyPressureGain+0;_evidence=evidence
::method stringEffectiveArea; expose _stringArea; return _stringArea
::method bodyEffectiveArea; expose _bodyArea; return _bodyArea
::method evidence; expose _evidence; return _evidence
::method stringForce
 expose _stringArea _stringGain
 use strict arg pressurePa,modeShape=1
 return pressurePa*_stringArea*_stringGain*modeShape
::method bodyForce
 expose _bodyArea _bodyGain
 use strict arg pressurePa,participation=1
 return pressurePa*_bodyArea*_bodyGain*participation

::class GuitarAcousticFeedbackDriver public
::method init
 expose _instrument _coupling _ledger _pi
 use strict arg instrumentMechanics,forceCoupling
 _instrument=instrumentMechanics;_coupling=forceCoupling;_ledger=.array~new;_pi=.Maths~pi(.Maths~defaultContext)
::method instrument; expose _instrument; return _instrument
::method ledger; expose _ledger; return _ledger~copy

::method step
 expose _instrument _coupling _ledger _pi
 use strict arg dt,pressureObservation
 if dt<=0 then raise syntax 88.900 array('positive acoustic feedback step',dt)
 p=pressureObservation~pressurePa
 /* External acoustic work is allowed to add energy: unlike the closed
    mechanical boundary, this is an explicitly driven system. Every course is
    forced, including courses with zero intentional/pluck excitation. */
 do c over _instrument~courses
   n=0
   do q over c~oscillators
     n+=1
     /* Distributed pressure coupling uses a bounded modal participation
        approximation. It is evidence-bearing, not a universal string constant. */
     shape=2/(_pi*n)
     f=_coupling~stringForce(p,shape)
     v=q~velocity+dt*f/q~mass
     q~setState(q~displacement,v)
   end
 end
 do b over _instrument~bodyModes
   f=_coupling~bodyForce(p,1)
   v=b~velocity+dt*f/b~mass
   b~setState(b~displacement,v)
 end
 mech=_instrument~step(dt)
 ev=.directory~new
 ev['TIME']=_instrument~time
 ev['PRESSURE_PA']=p
 ev['SOURCE']=pressureObservation~source
 ev['PATH_EVIDENCE']=pressureObservation~pathEvidence
 ev['MECHANICAL_EVENT']=mech
 ev['COUPLING_EVIDENCE']=_coupling~evidence
 _ledger~append(ev)
 return ev

::requires 'rxmath' LIBRARY
::requires 'GuitarInstrumentMechanics.cls'
::requires 'MathsBootstrap.cls'
