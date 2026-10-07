ctx=.MathContext~decimal(40)
world=.PhysicalWorld~new(.OpticalMedium~air)

waterRegion=.OpticalMediumRegion~new( -
    'tank', -
    .BoxShape~new(1,1,1,ctx), -
    .OpticalMedium~water, -
    .PhysicalPose~identity(ctx), -
    10)
world~addMediumRegion(waterRegion)

glass=.OpticalBody~new( -
    'glass', -
    .SphereShape~new(0.10), -
    .PhysicsMaterials~bk7Approx, -
    .PhysicalPose~identity(ctx), -
    'BODY', -
    .nil, -
    100)
world~addBody(glass)

pAir=.MathVector3~new(0,0,0.75,ctx)
pWater=.MathVector3~new(0.30,0,0,ctx)
pGlass=.MathVector3~new(0,0,0,ctx)

if world~mediumAt(pAir)~name<>'air' then do; say 'FAIL air medium'; exit 1; end
if world~mediumAt(pWater)~name<>'water' then do; say 'FAIL water medium'; exit 1; end
if world~mediumAt(pGlass)~name<>'BK7-approx' then do; say 'FAIL nested glass medium'; exit 1; end

/* Trace from air, through water, through nested glass, and back out. */
origin=.MathVector3~new(0,0,-0.75,ctx)
direction=.MathVector3~new(0,0,1,ctx)
ray=world~ray(origin,direction,555,1,ctx)
trace=world~trace(ray,20,0.000000001)
if trace~branches<5 then do; say 'FAIL expected medium-boundary branches' trace~branches; exit 1; end
if trace~escaped<0.99 then do; say 'FAIL expected nearly all energy to escape' trace~escaped; exit 1; end

say 'PHYSICS SPATIAL MEDIA: OK branches='trace~branches 'escaped='trace~escaped
exit 0
::requires 'PhysicsWorld.cls'
