/* Development demonstration: retained (sealed/non-spilling) liquid vessel dropped
   from one metre onto a rigid metal sheet.  This deliberately does NOT model an
   open glass free surface, slosh, spill or glass fracture yet. */
numeric digits 30
ctx=.Maths~defaultContext
water=.FluidMedium~water20C
liquid=.ContainedFluidLoad~filledCylinderByVolume(water,.Units~q(3,.Units~centimetre),.Units~q(250,.Units~millilitre))
dry=.MechanicsMassProperties~hollowCylinder(.22,.027,.031,.10)
props=liquid~combineCenteredAligned(dry)
drop=.FreeFallDrop~new(.Units~q(1,.Units~metre))
world=.PhysicalWorld~new(.OpticalMedium~air,.AcousticMedium~air,water)
q=.MathQuaternion~fromAxisAngle(.MathVector3~new(0,0,1,ctx),.MathAngle~degrees(12,ctx),ctx)
body=.PhysicalBody~new('glass-like-vessel',.BoxShape~new(.062,.10,.062,ctx), -
  .PhysicalPose~new(.MathVector3~new(0,.055,0,ctx),q,ctx))
vessel=.HullRigidBodyState~new(body,props,.RigidContactHull~cylinder(.031,.10,4,ctx), -
  .MathVector3~new(.25,-drop~impactSpeed,0,ctx),.nil,.false,.12)
sheetBody=.PhysicalBody~new('metal-sheet',.BoxShape~new(1,.01,1,ctx),.PhysicalPose~new(.MathVector3~new(0,-.005,0,ctx),.nil,ctx))
sheet=.RigidBodyState~new(sheetBody,.MechanicsMassProperties~solidBox(10,1,.01,1),.nil,.nil,.true,0)
solver=.GeneralContactMechanicsSolver~new(world,.MathVector3~new(0,-9.80665,0,ctx),1,drop~fallTime)
solver~addBody(vessel); solver~addBody(sheet)
solver~addPlane(.CollisionSurface~new(.MathVector3~new(0,0,0,ctx),.MathVector3~new(0,1,0,ctx),.08,sheet,.30))
coupler=.StructuralAcousticCoupler~new
coupler~addMode(.StructuralVibrationMode~new('sheet-mode',sheet,.MathVector3~new(0,0,0,ctx),.MathVector3~new(0,1,0,ctx),5,700,.04,.12))
acoustic=.AcousticSolver~new(world)
mic=.AcousticMicrophone~new('mic',.PhysicalPose~new(.MathVector3~new(0,1,1,ctx),.nil,ctx)); acoustic~addMicrophone(mic)
report=.VesselImpactExperiment~new(solver,vessel,coupler,acoustic,mic)~run(.10,.01,.Units~q(4,.Units~kilohertz))
say 'liquid:' liquid~volumeQuantity~in(.Units~millilitre) 'mL, mass' liquid~mass 'kg'
say 'ideal fall:' drop~fallTime 's, impact speed' drop~impactSpeed 'm/s'
say 'tumble rotation:' report~turns 'turns ('report~fullTurns 'complete turns)'
say 'contact events:' report~contacts
say 'peak angular speed:' report~peakAngularSpeed 'rad/s'
say 'microphone peak:' report~peakPressure 'Pa'
say 'microphone RMS:' report~rmsPressure 'Pa'
say 'RMS SPL:' report~splDb 'dB re 20 uPa'
::requires 'VesselDynamics.cls'
