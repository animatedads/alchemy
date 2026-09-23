numeric digits 50
ctx=.MathContext~decimal(50)
conv=.Math3DConvention~openGL

axis=.Maths~vector3(0,0,1,ctx)
angle=.Maths~angleDegrees(90,ctx)
q=.MathQuaternion~fromAxisAngle(axis,angle,ctx)

v=.Maths~vector3(1,0,0,ctx)
say 'q * [1,0,0] =' q*v

T=.MathTransform3D~translation(1,2,3,ctx,conv)
R=.MathTransform3D~rotation(q,ctx,conv)
S=.MathTransform3D~scale(2,2,2,ctx,conv)
model=T*R*S
say 'T*R*S * [1,0,0] =' model*v

projection=.Maths~perspective(.MathAngle~degrees(60,ctx),'1.77777777777777777778',1,100,ctx,conv)
say 'perspective evidence:' projection~evidence~canonical

view=.MathTransform3D~lookAt(.Maths~vector3(0,0,5,ctx),.Maths~vector3(0,0,0,ctx),.Maths~vector3(0,1,0,ctx),ctx,conv)
say 'origin in view space:' view*.Maths~vector3(0,0,0,ctx)

say 'column-major model array:'
a=model~toColumnMajorArray
do i=1 to a~items
  say i a[i]
end

::requires 'MathsBootstrap.cls'
