numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new
body=.PhysicalBody~new('crate',.BoxShape~new(1,1,1,ctx),.PhysicalPose~identity(ctx));world~addBody(body)
controller=.StateOfNationController~new
pj=.PhysicsWorldJournal~new(world,controller,'physics')
world~simulationTime=1
a=pj~capture('A','TEST')
body~pose=.PhysicalPose~new(.MathVector3~new(5,0,0,ctx),body~pose~orientation,ctx);world~simulationTime=2
b=pj~capture('B','TEST')
pj~restore(a)
if world~simulationTime<>1 | body~pose~position~x<>0 then exit 1
pj~restore(b)
if world~simulationTime<>2 | body~pose~position~x<>5 then exit 1
if pj~controller<>controller then exit 1
say 'PHYSICS SHARED STATE-OF-NATION: OK checkpoints='controller~checkpointCount
::requires 'PhysicsJournalState.cls'
::requires 'PhysicsWorld.cls'
