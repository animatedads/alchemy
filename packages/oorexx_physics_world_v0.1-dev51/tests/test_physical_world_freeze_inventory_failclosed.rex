world=.PhysicalWorld~new
cp=world~freeze
m=.FluidMedium~new('water',1000,0.001)
tank=.RectangularTankGeometry2D~new(4,10,1.3)
fluid=.RectangularTankSlosh2D~new(m,tank,24.5,0)
world~registerFreezeParticipant(.FreeSurfaceFreezeParticipant~new('late-tank',fluid))
signal on syntax name bad
world~restore(cp)
exit 1
bad:
say 'PHYSICS WORLD FREEZE INVENTORY FAIL-CLOSED: OK'
exit 0
::requires 'PhysicsWorld.cls'
::requires 'Fluids.cls'
::requires 'FreeSurfaceFluids2D.cls'
