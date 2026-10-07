ctx=.Maths~defaultContext; p=.directory~new; p['PART_DEFINITION_ID']='RUGBY'; p['MASS']='410 g'; p['LENGTH']='290 mm'; p['MAX_CIRCUMFERENCE']='600 mm'
pos=.MathVector3~new(0,0,1,ctx); vel=.MathVector3~new(20,0,5,ctx); q=.MathQuaternion~new(1,0,0,0,ctx); w=.MathVector3~new(0,20,0,ctx)
f=.RugbyBallFlightFactory~create(p,pos,vel,q,w,1.2,.AxialAerodynamicCoefficientModel~new(.2,.7,0,.02)); before=f~body~orientation; f~run(.1,.01); after=f~body~orientation
if before~w=after~w & before~x=after~x & before~y=after~y & before~z=after~z then exit 1
say 'PHYSICS RUGBY SPIN ORIENTATION EVOLUTION: OK omega=' f~body~angularVelocity~norm
::requires 'BallisticFlight.cls'
