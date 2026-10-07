world=.PhysicalWorld~new(.nil,.AcousticMedium~air)
solver=.AcousticSolver~new(world)
kit=.DrumKitFactory~standardRockKit
listener=.MathVector3~new(0,-2.2,1.15,.Maths~defaultContext)
plan=kit~preparePressurePlan(listener,solver)
kit~snare(.22,.25,0)
do i=1 to 200; kit~step(.0001); world~advanceSimulationTime(.0001); end
p1=kit~pressureAt(listener,kit~time,solver)~pressurePa
p2=kit~pressureAtPlan(plan,kit~time)~pressurePa
if abs(p1-p2)>.00000001 then do; say 'FAIL drum pressure plan mismatch' p1 p2; exit 1; end
if plan~paths~items<>9 then do; say 'FAIL drum pressure plan path count' plan~paths~items; exit 1; end
say 'PASS drum pressure plan' p1 p2
exit 0
::requires 'DrumKitPhysics.cls'
