numeric digits 30
ctx=.Maths~defaultContext
air=.FluidMedium~air20C
water=.FluidMedium~water20C
world=.PhysicalWorld~new(.OpticalMedium~air,.nil,air)
region=.FluidMediumRegion~new( -
  'water-tank', -
  .BoxShape~new(1,1,1,ctx), -
  water, -
  .PhysicalPose~identity(ctx), -
  10, -
  .OpticalMedium~water)
world~addMediumRegion(region)

inside=.MathVector3~new(0,0,0,ctx)
outside=.MathVector3~new(0,0,'0.75',ctx)
if world~fluidMediumAt(inside)~name<>'water-20C-approx' then do; say 'FAIL fluid region'; exit 1; end
if world~fluidMediumAt(outside)~name<>'air-20C-approx' then do; say 'FAIL ambient fluid'; exit 1; end
if world~mediumAt(inside)~name<>'water' then do; say 'FAIL shared optical region'; exit 1; end
if world~mediumAt(outside)~name<>'air' then do; say 'FAIL ambient optical'; exit 1; end
say 'PHYSICS FLUID SHARED REGIONS: OK'
exit 0
::requires 'Fluids.cls'
