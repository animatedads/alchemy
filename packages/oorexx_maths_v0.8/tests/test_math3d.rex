numeric digits 80
ctx=.MathContext~decimal(50)
passes=0

call assertEq .Maths~version,'0.8','Maths version is 0.8'

/* Angles and high-precision reduction. */
a90=.MathAngle~degrees(90,ctx)
call assertNear a90~radiansValue,rx_math3d_pi(ctx)/2,'1E-58','90 degrees converts to pi/2'
call assertNear a90~sin,1,'1E-55','sin 90 degrees'
call assertNear a90~cos,0,'1E-55','cos 90 degrees'
call assertNear .MathAngle~degrees(450,ctx)~reduced~value,90,'1E-55','450 degrees reduces to 90'
call assertNear .MathAngle~degrees(-270,ctx)~reduced~value,90,'1E-55','negative degree reduction is canonical'
huge=.MathAngle~degrees('360000000000000000000000000090',ctx)
call assertNear huge~reduced~value,90,'1E-55','huge degree angle reduces before trig conversion'
call assertNear huge~sin,1,'1E-50','huge degree angle sine retains precision'
pi=rx_math3d_pi(ctx); hugeRad=.MathAngle~radians(pi*200000000000000000000+pi/2,ctx)
call assertNear hugeRad~sin,1,'1E-45','large radian angle reduces with magnitude-aware precision'
call assertNear .MathAngle~degrees(180,ctx)~sin,0,'1E-55','sin 180 degrees'
call assertNear .MathAngle~degrees(180,ctx)~cos,-1,'1E-55','cos 180 degrees'
call assertEq a90~evidence~operation,'angle.construct','angle carries evidence'

/* Vector3 semantics. */
x=.MathVector3~new(1,0,0,ctx); y=.MathVector3~new(0,1,0,ctx); z=.MathVector3~new(0,0,1,ctx)
call assertVec x+y,1,1,0,'Vector3 overloaded +'
call assertEq x*y,0,'Vector3 * Vector3 is dot product'
call assertVec x~cross(y),0,0,1,'Vector3 cross product'
call assertVec y~cross(x),0,0,-1,'Vector3 cross orientation'
call assertNear .MathVector3~new(3,4,0,ctx)~norm,5,'1E-55','Vector3 norm'
call assertVecNear .MathVector3~new(3,4,0,ctx)~normalized,'0.6','0.8',0,'1E-50','Vector3 normalization'
call assertVec x*3,3,0,0,'Vector3 scalar multiplication'

/* Quaternion semantics and the old precision-leak regressions. */
q=.MathQuaternion~fromAxisAngle(z,a90,ctx)
root2over2='0.70710678118654752440084436210484903928483593768847'
call assertNear q~w,root2over2,'1E-50','axis-angle quaternion w precision'
call assertNear q~z,root2over2,'1E-50','axis-angle quaternion z precision'
call assertVecNear q*x,0,1,0,'1E-50','quaternion rotates X to Y'
qi=q~inverse
call assertNear qi~z,-root2over2,'1E-50','quaternion inverse does not truncate negated component'
id=q*qi
call assertQuatNear id,1,0,0,0,'1E-48','q * inverse(q) is identity'
call assertQuatNear q~conjugate,q~w,0,0,-q~z,'1E-55','quaternion conjugate preserves precision'
qScaled=.MathQuaternion~fromAxisAngle(.MathVector3~new(0,0,20,ctx),a90,ctx)
call assertVecNear qScaled*x,0,1,0,'1E-50','axis is normalized in fromAxisAngle'
q180=.MathQuaternion~fromAxisAngle(y,.MathAngle~degrees(180,ctx),ctx)
call assertVecNear q180*x,-1,0,0,'1E-48','180-degree quaternion rotation'
q360=.MathQuaternion~fromAxisAngle(z,.MathAngle~degrees(360,ctx),ctx)
call assertVecNear q360*x,1,0,0,'1E-48','360-degree quaternion rotation'
call assertEq q~evidence~operation,'quaternion.fromAxisAngle','quaternion carries construction evidence'

/* Matrix3 quaternion conversion. */
m3=q~toMatrix3
call assertVecNear m3*x,0,1,0,'1E-48','Quaternion Matrix3 agrees with quaternion rotation'
call assertNear m3[3,3],1,'1E-55','Matrix3 Z axis remains fixed'

/* Matrix4 and transform composition. Column vectors: T*R*S applies S,R,T. */
conv=.Math3DConvention~openGL
T=.MathTransform3D~translation(1,2,3,ctx,conv)
R=.MathTransform3D~rotation(q,ctx,conv)
S=.MathTransform3D~scale(2,2,2,ctx,conv)
call assertEq T~class~id,'MATHAFFINETRANSFORM3D','translation is a constrained affine transform'
call assertEq R~class~id,'MATHAFFINETRANSFORM3D','rotation is a constrained affine transform'
call assertEq S~class~id,'MATHAFFINETRANSFORM3D','scale is a constrained affine transform'
model=T*R*S
call assertVecNear model*.MathVector3~new(1,0,0,ctx),1,4,3,'1E-48','T*R*S transform composition order'
call assertVecNear T~transformDirection(x),1,0,0,'1E-55','translation does not affect direction'
call assertVecNear T*x,2,2,3,'1E-55','translation affects point'
call assertEq model~convention~name,'OPENGL','transform retains explicit convention'
call assertEq model~evidence~operation,'transform3d.compose','composed transform carries evidence'

/* Perspective projection conventions. */
p=.MathPerspective~new(.MathAngle~degrees(90,ctx),1,1,10,ctx,.Math3DConvention~openGL)
call assertNear p~matrix[1,1],1,'1E-48','OpenGL perspective cotangent/aspect coefficient'
call assertNear p~matrix[2,2],1,'1E-48','OpenGL perspective vertical coefficient'
nearP=p*.MathVector3~new(0,0,-1,ctx)
farP=p*.MathVector3~new(0,0,-10,ctx)
call assertNear nearP~z,-1,'1E-48','OpenGL near plane maps to NDC -1'
call assertNear farP~z,1,'1E-48','OpenGL far plane maps to NDC +1'
call assertEq p~convention~depthRange,'NEGATIVE_ONE_TO_ONE','OpenGL depth convention explicit'
call assertEq p~evidence~operation,'projection.perspective','perspective carries evidence'

pv=.MathPerspective~new(.MathAngle~degrees(90,ctx),1,1,10,ctx,.Math3DConvention~vulkan)
call assertNear (pv*.MathVector3~new(0,0,-1,ctx))~z,0,'1E-48','Vulkan near plane maps to NDC 0'
call assertNear (pv*.MathVector3~new(0,0,-10,ctx))~z,1,'1E-48','Vulkan far plane maps to NDC 1'
call assertEq pv~convention~handedness,'RIGHT_HANDED','Vulkan handedness explicit'

pd=.MathPerspective~new(.MathAngle~degrees(90,ctx),1,1,10,ctx,.Math3DConvention~directX)
call assertNear (pd*.MathVector3~new(0,0,1,ctx))~z,0,'1E-48','DirectX near plane maps to NDC 0'
call assertNear (pd*.MathVector3~new(0,0,10,ctx))~z,1,'1E-48','DirectX far plane maps to NDC 1'
call assertEq pd~convention~handedness,'LEFT_HANDED','DirectX handedness explicit'

/* Orthographic projection. */
o=.MathOrthographic~new(-2,2,-1,1,1,11,ctx,.Math3DConvention~openGL)
call assertVecNear o*.MathVector3~new(2,1,-1,ctx),1,1,-1,'1E-48','OpenGL orthographic near/top/right corner'
call assertVecNear o*.MathVector3~new(-2,-1,-11,ctx),-1,-1,1,'1E-48','OpenGL orthographic far/bottom/left corner'

/* Ray and plane. */
ray=.MathRay3D~new(.MathVector3~new(1,2,3,ctx),.MathVector3~new(10,0,0,ctx),ctx)
call assertVecNear ray~pointAt(2),3,2,3,'1E-55','Ray pointAt uses normalized direction'
plane=.MathPlane3D~fromPointNormal(.MathVector3~new(0,0,5,ctx),z,ctx)
call assertNear plane~signedDistance(.MathVector3~new(0,0,5,ctx)),0,'1E-55','Plane point lies on plane'
call assertNear plane~signedDistance(.MathVector3~new(0,0,7,ctx)),2,'1E-55','Plane signed distance'

/* Exact-domain boundary: algebra can stay rational; irrational/transcendental paths fail closed. */
rctx=.MathContext~rational
call assertEq .MathVector3~new(3,4,0,rctx)~norm~string,'5','3-4-5 Vector3 norm stays exact rational'
call assertVec .MathVector3~new(1,0,0,rctx)~cross(.MathVector3~new(0,1,0,rctx)),0,0,1,'rational Vector3 cross stays exact'
call assertEq .MathAngle~degrees(450,rctx)~reduced~value~string,'90','rational degree reduction stays exact'
call expectSyntaxSqrt2
call expectSyntaxRationalTrig

/* Caller precision must not leak into 3D methods. */
call lowPrecisionBoundary ctx,root2over2

/* Transform inversion, camera construction and layout export. */
modelInv=model~inverse
call assertVecNear modelInv*(model*.MathVector3~new(3,-2,5,ctx)),3,-2,5,'1E-45','transform inverse round trip'
view=.MathTransform3D~lookAt(.MathVector3~new(0,0,5,ctx),.MathVector3~new(0,0,0,ctx),y,ctx,.Math3DConvention~openGL)
call assertVecNear view*.MathVector3~new(0,0,0,ctx),0,0,-5,'1E-48','right-handed lookAt maps target down negative Z'
viewDx=.MathTransform3D~lookAt(.MathVector3~new(0,0,-5,ctx),.MathVector3~new(0,0,0,ctx),y,ctx,.Math3DConvention~directX)
call assertVecNear viewDx*.MathVector3~new(0,0,0,ctx),0,0,5,'1E-48','left-handed lookAt maps target down positive Z'
flat=T~toColumnMajorArray
call assertNear flat[13],1,'1E-55','column-major export translation X position'
call assertNear flat[14],2,'1E-55','column-major export translation Y position'
call assertNear flat[15],3,'1E-55','column-major export translation Z position'

/* Factory surface. */
call assertEq .Maths~vector3(1,2,3,ctx)~class~id,'MATHVECTOR3','Maths vector3 factory'
call assertEq .Maths~angleDegrees(90,ctx)~class~id,'MATHANGLE','Maths angle factory'
call assertEq .Maths~perspective(.MathAngle~degrees(60,ctx),'1.5',1,100,ctx,conv)~class~id,'MATHPERSPECTIVE','Maths perspective factory'

say 'PASS oorexx_maths Math3D' passes 'assertions'
exit 0

expectSyntaxSqrt2: procedure expose passes
  signal on syntax name expectedSqrt
  ignored=.MathVector3~new(1,1,0,.MathContext~rational)~norm
  say 'FAIL irrational rational-domain sqrt did not fail closed'; exit 1
expectedSqrt:
  passes=passes+1; say 'PASS irrational rational-domain sqrt fails closed'; return

expectSyntaxRationalTrig: procedure expose passes
  signal on syntax name expectedTrig
  ignored=.MathAngle~degrees(90,.MathContext~rational)~sin
  say 'FAIL rational-domain trigonometry did not fail closed'; exit 1
expectedTrig:
  passes=passes+1; say 'PASS rational-domain trigonometry fails closed'; return

lowPrecisionBoundary: procedure expose passes
  use arg ctx,root2over2
  numeric digits 9
  axis=.MathVector3~new(0,0,1,ctx)
  a=.MathAngle~degrees(90,ctx)
  q=.MathQuaternion~fromAxisAngle(axis,a,ctx)
  v=q*.MathVector3~new(1,0,0,ctx)
  qi=q~inverse
  h=a~half
  call assertNear q~z,root2over2,'1E-50','caller NUMERIC DIGITS 9 does not truncate quaternion construction'
  call assertVecNear v,0,1,0,'1E-50','caller NUMERIC DIGITS 9 does not truncate quaternion rotation'
  call assertNear qi~z,'-0.70710678118654752440084436210484903928483593768847','1E-50','caller NUMERIC DIGITS 9 does not truncate quaternion inverse'
  call assertNear h~degreesValue,45,'1E-50','caller NUMERIC DIGITS 9 does not truncate angle halving'
  return

assertEq: procedure expose passes
  use arg actual,expected,label
  if actual == expected then do; passes=passes+1; say 'PASS' label; return; end
  say 'FAIL' label 'actual='actual 'expected='expected; exit 1

assertNear: procedure expose passes
  use arg actual,expected,tolerance,label
  numeric digits 100
  d=(actual-expected)~abs
  if d <= tolerance then do; passes=passes+1; say 'PASS' label; return; end
  say 'FAIL' label 'actual='actual 'expected='expected 'diff='d 'tol='tolerance; exit 1

assertVec: procedure expose passes
  use arg actual,x,y,z,label
  if actual~x=x & actual~y=y & actual~z=z then do; passes=passes+1; say 'PASS' label; return; end
  say 'FAIL' label 'actual='actual 'expected=['||x||','||y||','||z||']'; exit 1

assertVecNear: procedure expose passes
  use arg actual,x,y,z,tolerance,label
  numeric digits 100
  d=max((actual~x-x)~abs,(actual~y-y)~abs,(actual~z-z)~abs)
  if d <= tolerance then do; passes=passes+1; say 'PASS' label; return; end
  say 'FAIL' label 'actual='actual 'expected=['||x||','||y||','||z||'] diff='d 'tol='tolerance; exit 1

assertQuatNear: procedure expose passes
  use arg actual,w,x,y,z,tolerance,label
  numeric digits 100
  d=max((actual~w-w)~abs,(actual~x-x)~abs,(actual~y-y)~abs,(actual~z-z)~abs)
  if d <= tolerance then do; passes=passes+1; say 'PASS' label; return; end
  say 'FAIL' label 'actual='actual 'diff='d 'tol='tolerance; exit 1

::requires 'MathsBootstrap.cls'
