numeric digits 30
ctx=.MathContext~new(30)
worldA=.PhysicalWorld~new
bodyA=.PhysicalBody~new('A',.BoxShape~new(1,1,1,ctx),.PhysicalPose~identity(ctx))
worldA~addBody(bodyA)
cp=worldA~freeze
worldB=.PhysicalWorld~new
bodyB=.PhysicalBody~new('B',.BoxShape~new(1,1,1,ctx),.PhysicalPose~identity(ctx))
worldB~addBody(bodyB)
beforeA=bodyA~pose; beforeB=bodyB~pose
signal on syntax name crossWorldRejected
worldB~restore(cp)
say 'FAIL cross-world checkpoint accepted'; exit 1
crossWorldRejected:
signal off syntax
if bodyA~pose \== beforeA then do; say 'FAIL originating body mutated'; exit 1; end
if bodyB~pose \== beforeB then do; say 'FAIL target body mutated'; exit 1; end

cp2=worldA~freeze
bodyExtra=.PhysicalBody~new('extra',.BoxShape~new(1,1,1,ctx),.PhysicalPose~identity(ctx))
worldA~addBody(bodyExtra)
signal on syntax name changedInventoryRejected
worldA~restore(cp2)
say 'FAIL changed body inventory accepted'; exit 1
changedInventoryRejected:
signal off syntax
say 'PASS Physics freeze world/body binding'
exit 0
::requires 'PhysicsWorld.cls'
