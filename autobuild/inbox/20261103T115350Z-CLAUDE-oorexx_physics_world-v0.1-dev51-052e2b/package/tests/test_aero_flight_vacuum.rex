numeric digits 30
ctx=.Maths~defaultContext; p=.directory~new; p['PART_DEFINITION_ID']='BALL'; p['MASS']='410 g'; p['LENGTH']='290 mm'; p['MAX_CIRCUMFERENCE']='600 mm'
pos=.MathVector3~new(0,0,10,ctx); vel=.MathVector3~new(10,0,10,ctx); q=.MathQuaternion~new(1,0,0,0,ctx); w=.MathVector3~new(0,0,0,ctx)
f=.RugbyBallFlightFactory~create(p,pos,vel,q,w,'0.000000001',.AxialAerodynamicCoefficientModel~new(0,0))
f~run(1,.02); s=f~history[f~history~items]
if abs(s~position~x-10)>.0001 then exit 1
if abs(s~velocity~z-(10-9.80665))>.001 then exit 1
say 'PHYSICS FLIGHT GRAVITY INTEGRATION: OK x=' s~position~x 'vz=' s~velocity~z
::requires 'BallisticFlight.cls'
