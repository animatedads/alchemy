numeric digits 30
water=.FluidMedium~water20C
tank=.RectangularTankGeometry2D~new(1,.5,.5,10,6)
slosh=.RectangularTankSlosh2D~new(water,tank,.125)
boundary=.FluidContainmentBoundary2D~new(tank)
boundary~addBreach(.RectangularBoundaryBreach2D~new('low','RIGHT',0,.05,.1,.05,.6))
vessel=.BreachedFreeSurfaceVessel2D~new(slosh,boundary)
world=.ExternalFluidParcelWorld~new
binding=.EscapedFluidWorldBinding~new(vessel,world)
vessel~stepDischarge(.01)
added=binding~synchronize
if added~items<>1 then do; say 'FAIL escaped parcel not admitted'; exit 1; end
if abs(binding~massBalanceError)>.0000001 then do; say 'FAIL retained + external mass'; exit 1; end
if binding~synchronize~items<>0 then do; say 'FAIL duplicate parcel admission'; exit 1; end
say 'PHYSICS RETAINED + EXTERNAL FLUID MASS: OK'
exit 0
::requires 'ExternalFluidParcels.cls'
