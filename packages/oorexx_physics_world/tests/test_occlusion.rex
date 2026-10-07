ctx=.MathContext~decimal(40)
world=.PhysicalWorld~new(.OpticalMedium~air)

sensor=.OpticalSensor~new( -
    'meter', -
    .RectangleShape~new(0.01,0.01), -
    .PhysicalPose~new(.MathVector3~new(0,0,0.02,ctx),.nil,ctx))
world~addSensor(sensor)

brick=.OpticalBody~new( -
    'brick', -
    .BoxShape~new(0.02,0.02,0.005,ctx), -
    .PhysicsMaterials~blackAbsorber, -
    .PhysicalPose~new(.MathVector3~new(0,0,0.01,ctx),.nil,ctx))
world~addBody(brick)

ray=world~ray(.MathVector3~new(0,0,0,ctx),.MathVector3~new(0,0,1,ctx),555,1,ctx)
trace=world~trace(ray,8,0.000000001)
if sensor~received<>0 then do; say 'FAIL sensor saw through brick' sensor~received; exit 1; end
if trace~absorbed<0.999999 then do; say 'FAIL brick did not absorb ray' trace~absorbed; exit 1; end

say 'PHYSICS OCCLUSION: OK'
exit 0
::requires 'PhysicsWorld.cls'
