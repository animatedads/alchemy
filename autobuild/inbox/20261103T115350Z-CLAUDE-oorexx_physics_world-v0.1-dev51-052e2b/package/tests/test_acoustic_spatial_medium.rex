numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air)
tank=.PhysicalMediumRegion~new('tank',.BoxShape~new(1,1,1,ctx),.OpticalMedium~water,.AcousticMedium~water,.PhysicalPose~identity(ctx),10)
world~addMediumRegion(tank)
outside=.MathVector3~new(0,0,'0.75',ctx)
inside=.MathVector3~new(0,0,0,ctx)
if world~mediumAt(outside)~name<>'air' then do; say 'FAIL optical outside air'; exit 1; end
if world~mediumAt(inside)~name<>'water' then do; say 'FAIL optical inside water'; exit 1; end
if world~acousticMediumAt(outside)~name<>'air' then do; say 'FAIL acoustic outside air'; exit 1; end
if world~acousticMediumAt(inside)~name<>'water' then do; say 'FAIL acoustic inside water'; exit 1; end
say 'PHYSICS SHARED OPTICAL + ACOUSTIC SPATIAL MEDIUM: OK'
::requires 'Acoustics.cls'
