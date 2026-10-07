numeric digits 30
a=.array~of(1,1,1,1)
p=.IncoherentSourceAggregator~combinedRms(a)
if abs(p-2)>.0000001 then do; say 'FAIL incoherent aggregation' p; exit 1; end
say 'PHYSICS INCOHERENT SOURCE AGGREGATION: OK rms='p
exit 0
::requires 'SpectralObservations.cls'
