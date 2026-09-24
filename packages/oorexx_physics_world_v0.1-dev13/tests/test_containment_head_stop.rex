numeric digits 30
water=.FluidMedium~water20C
tank=.RectangularTankGeometry2D~new(1,.5,.5,10,6)
slosh=.RectangularTankSlosh2D~new(water,tank,.125)
boundary=.FluidContainmentBoundary2D~new(tank)
breach=.RectangularBoundaryBreach2D~new('dry-high','LEFT',0,.3,.1,.05,.6)
boundary~addBreach(breach)
system=.BreachedFreeSurfaceVessel2D~new(slosh,boundary)
r=system~stepDischarge(.01)
if r~escapedStepVolume<>0 then do; say 'FAIL breach above liquid leaked'; exit 1; end
if abs(system~massBalanceError)>0.0000001 then do; say 'FAIL dry breach mass balance'; exit 1; end
say 'PHYSICS CONTAINMENT HYDROSTATIC HEAD: OK'
exit 0
::requires 'FluidContainment.cls'
