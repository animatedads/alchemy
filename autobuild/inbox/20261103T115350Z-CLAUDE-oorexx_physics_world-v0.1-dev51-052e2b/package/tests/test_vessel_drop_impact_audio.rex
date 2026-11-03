numeric digits 30
ctx=.Maths~defaultContext
water=.FluidMedium~water20C
load=.ContainedFluidLoad~filledCylinderByVolume(water,.Units~q(3,.Units~centimetre),.Units~q(250,.Units~millilitre))
dry=.MechanicsMassProperties~hollowCylinder(.22,.027,.031,.10)
props=load~combineCenteredAligned(dry)
drop=.FreeFallDrop~new(.Units~q(1,.Units~metre))
call near drop~impactSpeed,'4.428690551393267','1 m ideal free-fall impact speed','0.0000000001'
call near drop~fallTime,'0.4516007557517875','1 m ideal free-fall time','0.0000000001'
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air,water)
axis=.MathVector3~new(0,0,1,ctx)
q=.MathQuaternion~fromAxisAngle(axis,.MathAngle~degrees(12,ctx),ctx)
vesselBody=.PhysicalBody~new('retained-liquid-vessel',.BoxShape~new(.062,.10,.062,ctx), -
  .PhysicalPose~new(.MathVector3~new(0,.055,0,ctx),q,ctx))
world~addBody(vesselBody)
hull=.RigidContactHull~cylinder(.031,.10,4,ctx)
vessel=.HullRigidBodyState~new(vesselBody,props,hull,.MathVector3~new(.25,-drop~impactSpeed,0,ctx),.nil,.false,.12)
sheetBody=.PhysicalBody~new('metal-sheet',.BoxShape~new(1,.01,1,ctx), -
  .PhysicalPose~new(.MathVector3~new(0,-.005,0,ctx),.nil,ctx))
sheet=.RigidBodyState~new(sheetBody,.MechanicsMassProperties~solidBox(10,1,.01,1),.nil,.nil,.true,0)
solver=.GeneralContactMechanicsSolver~new(world,.MathVector3~new(0,-9.80665,0,ctx),1,drop~fallTime)
solver~addBody(vessel); solver~addBody(sheet)
solver~addPlane(.CollisionSurface~new(.MathVector3~new(0,0,0,ctx),.MathVector3~new(0,1,0,ctx),.08,sheet,.30))
coupler=.StructuralAcousticCoupler~new
coupler~addMode(.StructuralVibrationMode~new('sheet-mode',sheet,.MathVector3~new(0,0,0,ctx), -
  .MathVector3~new(0,1,0,ctx),5,700,.04,.12))
acoustic=.AcousticSolver~new(world)
mic=.AcousticMicrophone~new('mic',.PhysicalPose~new(.MathVector3~new(0,1,1,ctx),.nil,ctx))
acoustic~addMicrophone(mic)
experiment=.VesselImpactExperiment~new(solver,vessel,coupler,acoustic,mic)
report=experiment~run(.Units~q(.10,.Units~second),.Units~q(.01,.Units~second),.Units~q(4,.Units~kilohertz))
if report~contacts<1 then do; say 'FAIL vessel never contacted sheet'; exit 1; end
if report~turns<=0 then do; say 'FAIL vessel did not rotate'; exit 1; end
if report~peakPressure<=0 then do; say 'FAIL impact produced no microphone pressure'; exit 1; end
if report~rmsPressure<=0 then do; say 'FAIL impact produced zero RMS pressure'; exit 1; end
if report~splDb==.nil then do; say 'FAIL impact SPL unavailable'; exit 1; end
if report~sampleBuffer~sampleCount<>400 then do; say 'FAIL impact audio sample count' report~sampleBuffer~sampleCount; exit 1; end
if report~sampleBuffer~startTime<drop~fallTime then do; say 'FAIL audio timeline predates ideal fall'; exit 1; end
say 'PHYSICS RETAINED-LIQUID DROP IMPACT: OK turns='report~turns 'contacts='report~contacts 'SPL='report~splDb 'dB'
exit 0
near: procedure
  use arg actual,expected,label,tolerance='0.000001'
  if abs(actual-expected)>tolerance then do; say 'FAIL:' label actual expected; exit 1; end
return
::requires 'VesselDynamics.cls'
