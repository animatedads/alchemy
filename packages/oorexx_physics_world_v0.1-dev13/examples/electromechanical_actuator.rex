numeric digits 30
ctx=.Maths~defaultContext
world=.PhysicalWorld~new
zero=.MathVector3~new(0,0,0,ctx)
armatureBody=.PhysicalBody~new('armature',.SphereShape~new(.01),.PhysicalPose~identity(ctx))
armature=.RigidBodyState~new(armatureBody,.MechanicsMassProperties~pointMass(.05,.01))
world~addBody(armatureBody)
mechanics=.MechanicsSolver~new(world,zero)
mechanics~addBody(armature)
actuator=.LinearElectromechanicalTransducer~new( -
  'linear-voice-coil',armature,zero,.PhysicalPose~identity(ctx),.MathVector3~new(1,0,0,ctx), -
  .Units~q(3,.Units~newton/.Units~ampere))

drive=.ElectricalDriveObservation~new(.Units~q(0,.Units~second),.Units~q(.2,.Units~ampere),.Units~q(5,.Units~volt),'Rexx-tronics electrical solve')
event=actuator~applyDrive(drive)
mechanics~step(.Units~q(.01,.Units~second))
feedback=.ElectricalDriveObservation~new(.Units~q(.01,.Units~second),.Units~q(.2,.Units~ampere),.Units~q(5,.Units~volt),'post-mechanics electrical re-solve')
event2=actuator~applyDrive(feedback)

say 'force:' event~forceMagnitude 'N'
say 'armature velocity:' armature~velocity~x 'm/s'
say 'armature position:' armature~position~x 'm'
say 'back EMF after motion:' event2~backEmf 'V'
say 'conversion power:' event2~conversionElectricalPower 'W'
say 'terminal power not assigned by ideal transducer:' event2~unassignedTerminalPower 'W'
::requires 'Electromechanics.cls'
