numeric digits 30
ctx=.Maths~defaultContext; p=.directory~new; p['PART_DEFINITION_ID']='RUGBY'; p['MASS']='410 g'; p['LENGTH']='290 mm'; p['MAX_CIRCUMFERENCE']='600 mm'
pos=.MathVector3~new(0,0,1,ctx); vel=.MathVector3~new(25,0,15,ctx); q=.MathQuaternion~new(1,0,0,0,ctx); w=.MathVector3~new(0,0,0,ctx)
no=.RugbyBallFlightFactory~create(p,pos,vel,q,w,1.2,.AxialAerodynamicCoefficientModel~new(0,0)); dr=.RugbyBallFlightFactory~create(p,pos,vel,q,w,1.2,.AxialAerodynamicCoefficientModel~new(.18,.65))
no~run(.4,.02); dr~run(.4,.02); xn=no~body~position~x; xd=dr~body~position~x
if xd>=xn then exit 1
say 'PHYSICS RUGBY DRAG TRAJECTORY: OK noDragX=' xn 'dragX=' xd
::requires 'BallisticFlight.cls'
