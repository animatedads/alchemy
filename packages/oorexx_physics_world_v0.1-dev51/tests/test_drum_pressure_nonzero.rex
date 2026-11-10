call loadMaths
world=.PhysicalWorld~new(.nil,.AcousticMedium~air)
solver=.AcousticSolver~new(world)
kit=.DrumKitFactory~standardRockKit
listener=.MathVector3~new(0,-2.2,1.15,.Maths~defaultContext)
plan=kit~preparePressurePlan(listener,solver)
kit~snare(.22,.25,0)
peak=0
do i=1 to 400
  kit~step(.0001); world~advanceSimulationTime(.0001)
  p=kit~pressureScalarAtPlan(plan,kit~time)
  if abs(p)>peak then peak=abs(p)
end
if peak<=0 then do; say 'FAIL drum microphone pressure remained zero'; exit 1; end
say 'PASS drum microphone nonzero pressure peak='peak
exit 0
loadMaths: procedure
 return
::requires 'DrumKitPhysics.cls'
