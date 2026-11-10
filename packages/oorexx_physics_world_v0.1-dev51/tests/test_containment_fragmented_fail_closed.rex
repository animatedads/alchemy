water=.FluidMedium~water20C
tank=.RectangularTankGeometry2D~new(1,.5,.5,10,6)
slosh=.RectangularTankSlosh2D~new(water,tank,.125)
boundary=.FluidContainmentBoundary2D~new(tank)
system=.BreachedFreeSurfaceVessel2D~new(slosh,boundary)
boundary~markFragmented
signal on syntax name expected
system~stepDischarge(.01)
say 'FAIL fragmented containment did not fail closed'
exit 1
expected:
say 'PHYSICS FRAGMENTED CONTAINMENT FAIL-CLOSED: OK'
exit 0
::requires 'FluidContainment.cls'
