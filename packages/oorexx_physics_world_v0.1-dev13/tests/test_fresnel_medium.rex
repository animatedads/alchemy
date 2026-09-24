ctx=.MathContext~decimal(40)
d=.MathVector3~new(0,0,1,ctx)
n=.MathVector3~new(0,0,-1,ctx)
glass=.OpticalMedium~bk7Approx
ng=glass~refractiveIndex(555)

air=.GeometricOptics~interface(d,n,.OpticalMedium~air~refractiveIndex(555),ng)
water=.GeometricOptics~interface(d,n,.OpticalMedium~water~refractiveIndex(555),ng)
if water['reflectance']>=air['reflectance'] then do
  say 'FAIL water/glass should reflect less than air/glass' air['reflectance'] water['reflectance']
  exit 1
end
say 'PHYSICS FRESNEL MEDIUM: OK air='air['reflectance'] 'water='water['reflectance']
exit 0
::requires 'PhysicsWorld.cls'
