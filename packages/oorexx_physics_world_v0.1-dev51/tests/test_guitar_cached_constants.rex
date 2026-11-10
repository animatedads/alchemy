s=.GuitarStringPhysicalModel~new(82.4068892282175,.648,.00045,75,.00008,2.8,.018,6)
if abs(s~frequencyForFret(12)-2*s~openFrequency)>.000000001 then do; say 'FAIL cached semitone octave'; exit 1; end
o=.GuitarCoupledOscillator~new('q',.01,110,.02)
if abs(o~omega-2*.Maths~pi(.Maths~defaultContext)*110)>.000000001 then do; say 'FAIL cached omega'; exit 1; end
say 'PASS guitar cached constants'
exit 0
::requires 'GuitarCoupledBoundary.cls'
::requires 'MathsBootstrap.cls'
