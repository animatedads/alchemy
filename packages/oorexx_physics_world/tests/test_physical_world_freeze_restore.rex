numeric digits 30
ctx=.MathContext~new(30)
world=.PhysicalWorld~new
body=.PhysicalBody~new('crate',.BoxShape~new(1,1,1,ctx),.PhysicalPose~identity(ctx))
world~addBody(body)
rb=.RigidBodyState~new(body,.MechanicsMassProperties~solidBox(10,1,1,1),.MathVector3~new(1,2,3,ctx),.MathVector3~new(0.1,0.2,0.3,ctx))
rb~applyForce(.MathVector3~new(4,5,6,ctx))
world~registerFreezeParticipant(.RigidBodyFreezeParticipant~new('crate',rb))
medium=.FluidMedium~new('water',1000,0.001)
tank=.RectangularTankGeometry2D~new(4,10,1.3)
fluid=.RectangularTankSlosh2D~new(medium,tank,24.5,0)
fluid~seedStandingMode(0.02,0.01)
fluid~step(fluid~maxStableTimeStep(9.80665)*0.25,0.2,-0.1,9.80665)
world~registerFreezeParticipant(.FreeSurfaceFreezeParticipant~new('tank',fluid))
world~simulationTime=12.5
cp=world~freeze
frozenX=body~pose~position~x; frozenV=rb~velocity~x; frozenH=fluid~depthAtCell(1,1); frozenFluidTime=fluid~time
body~pose=.PhysicalPose~new(.MathVector3~new(9,8,7,ctx),body~pose~orientation,ctx)
rb~velocity=.MathVector3~new(99,98,97,ctx)
fluid~resetFlat
world~simulationTime=99
world~restore(cp)
if world~simulationTime<>12.5 then exit 1
if body~pose~position~x<>frozenX then exit 1
if rb~velocity~x<>frozenV then exit 1
if fluid~depthAtCell(1,1)<>frozenH | fluid~time<>frozenFluidTime then exit 1
say 'PHYSICS WORLD FREEZE RESTORE: OK participants='world~freezeParticipants~items 'time='world~simulationTime
::requires 'PhysicsWorld.cls'
::requires 'Mechanics.cls'
::requires 'Fluids.cls'
::requires 'FreeSurfaceFluids2D.cls'
