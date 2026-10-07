numeric digits 30
mode=.RotatingVibrationMode~new('damped',.MathVector3~new(1,0,0),1,100,5,.01,0)
initial=mode~strainEnergy
do 1000; mode~step(.001); end
final=mode~strainEnergy+mode~kineticEnergy
if final>=initial then do; say 'FAIL damping did not remove modal energy' initial final; exit 1; end
if mode~dampingDissipatedPower<0 then do; say 'FAIL negative damping power'; exit 1; end
say 'PHYSICS VIBRATION DAMPING ENERGY: OK initial='initial 'final='final
exit 0
::requires 'RotatingVibration.cls'
