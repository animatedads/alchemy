/* A one-kilogram body attached to a fixed point by a 10 N/m spring. */
ctx=.Maths~defaultContext
world=.PhysicalWorld~new
anchorShape=.SphereShape~new('0.03')
massShape=.SphereShape~new('0.05')
anchorBody=.OpticalBody~new('anchor',anchorShape,.nil,.PhysicalPose~new(.MathVector3~new(0,0,0,ctx),.nil,ctx))
massBody=.OpticalBody~new('mass',massShape,.nil,.PhysicalPose~new(.MathVector3~new(2,0,0,ctx),.nil,ctx))
world~addBody(anchorBody); world~addBody(massBody)
anchor=.RigidBodyState~new(anchorBody,.MechanicsMassProperties~solidSphere(1,'0.03'),.nil,.nil,.true)
mass=.RigidBodyState~new(massBody,.MechanicsMassProperties~solidSphere(1,'0.05'))
mechanics=.MechanicsSolver~new(world,.MathVector3~new(0,0,0,ctx))
mechanics~addBody(anchor); mechanics~addBody(mass)
mechanics~addSpring(.SpringConstraint~new(anchor,mass,1,10,'0.15'))
do frame=1 to 200
  mechanics~step('0.01')
  if frame//20=0 then say frame mass~position~x mass~velocity~x
end
::requires 'Mechanics.cls'
