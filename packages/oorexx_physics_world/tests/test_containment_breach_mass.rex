numeric digits 30
water=.FluidMedium~water20C
tank=.RectangularTankGeometry2D~new(.Units~q(1,.Units~metre),.Units~q(.5,.Units~metre),.Units~q(.5,.Units~metre),10,6)
slosh=.RectangularTankSlosh2D~new(water,tank,.Units~q(.125,.Units~cubicMetre))
boundary=.FluidContainmentBoundary2D~new(tank)
breach=.RectangularBoundaryBreach2D~new('right-low','RIGHT',0,.Units~q(.05,.Units~metre),.Units~q(.1,.Units~metre),.Units~q(.05,.Units~metre),.6)
boundary~addBreach(breach)
system=.BreachedFreeSurfaceVessel2D~new(slosh,boundary)
initial=system~initialMass
report=system~stepDischarge(.01)
if report~escapedStepVolume<=0 then do; say 'FAIL breach did not discharge'; exit 1; end
if system~parcels~items<>1 then do; say 'FAIL escaped parcel missing'; exit 1; end
if abs(initial-(system~retainedMass+system~escapedMass))>0.0000001 then do; say 'FAIL breached vessel mass conservation'; exit 1; end
if system~retainedVolume>=system~initialVolume then do; say 'FAIL retained volume did not fall'; exit 1; end
say 'PHYSICS CONTAINMENT BREACH MASS: OK retained='system~retainedMass 'escaped='system~escapedMass
exit 0
::requires 'FluidContainment.cls'
