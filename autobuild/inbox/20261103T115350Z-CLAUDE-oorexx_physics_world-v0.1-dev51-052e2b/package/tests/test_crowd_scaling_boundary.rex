numeric digits 30
n=83500; a=.array~new
do n; a~append(1); end
p=.IncoherentSourceAggregator~combinedRms(a)
expected=RxCalcSqrt(n,30)
if abs(p-expected)>.000001 then do; say 'FAIL crowd scaling' p expected; exit 1; end
if p=n then do; say 'FAIL coherent amplitude multiplication'; exit 1; end
say 'PHYSICS 83500 INCOHERENT SOURCES: OK rms='p
exit 0
::requires 'SpectralObservations.cls'
::requires 'rxmath' LIBRARY
