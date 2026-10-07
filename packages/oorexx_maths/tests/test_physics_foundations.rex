numeric digits 90
ctx=.MathContext~decimal(50)
rctx=.MathContext~rational
passes=0

call assertNear .Maths~pi(ctx),'3.1415926535897932384626433832795028841971693993751','1E-49','public pi at 50-digit context'
call assertNear .Maths~sqrt(2,ctx)**2,2,'1E-48','public sqrt round trip'
call assertNear .Maths~sin(.Maths~pi(ctx)/6,ctx),'0.5','1E-48','public sine radians'
call assertNear .Maths~cos(.Maths~pi(ctx)/3,ctx),'0.5','1E-48','public cosine radians'
call assertNear .Maths~exp(.Maths~ln(2,ctx),ctx),2,'1E-47','exp and ln are inverse at 2'
call assertNear .Maths~log10(1000,ctx),3,'1E-47','log10 1000'
call assertNear .Maths~atan2(1,0,ctx)~radiansValue,.Maths~pi(ctx)/2,'1E-48','atan2 quadrant +Y'

call assertNear .Maths~exp(-1,ctx)*.Maths~exp(1,ctx),1,'1E-47','positive/negative exponential reciprocal'
call assertNear .Maths~ln('.5',ctx),-.Maths~ln(2,ctx),'1E-47','natural log reciprocal identity'
call assertNear .Maths~atan(1,ctx)~radiansValue,.Maths~pi(ctx)/4,'1E-48','atan one is pi/4'
call assertNear .Maths~atan2(1,-1,ctx)~radiansValue,3*.Maths~pi(ctx)/4,'1E-47','atan2 quadrant II'
call assertNear .Maths~atan2(-1,-1,ctx)~radiansValue,-3*.Maths~pi(ctx)/4,'1E-47','atan2 quadrant III'
call assertNear .Maths~sin(100*.Maths~pi(ctx)+.Maths~pi(ctx)/6,ctx),'.5','1E-46','sine large reduced angle'
call assertNear .Maths~sqrt('1E-40',ctx),'1E-20','1E-48','sqrt tiny positive value'
call assertEq .Maths~sqrt(.Maths~fraction(9,16),rctx)~string,'3/4','exact rational perfect-square sqrt'
call expectIrrationalSqrt

/* Physics dev24/dev25 interpolation patterns. */
x=.array~of(0,10,20); y=.array~of(0,100,400)
li=.Maths~linearInterpolator(x,y,ctx)
call assertNear li~evaluate(5),50,'1E-50','linear interpolation midpoint'
call assertNear li~evaluate(15),250,'1E-50','linear interpolation second interval'
call expectLinearDomain li

lic=.Maths~linearInterpolator(x,y,ctx,'CLAMP')
call assertNear lic~evaluate(-100),0,'1E-50','linear interpolation clamp below domain'
lie=.Maths~linearInterpolator(x,y,ctx,'EXTRAPOLATE')
call assertNear lie~evaluate(-5),-50,'1E-50','linear interpolation explicit extrapolation'
lirq=.Maths~linearInterpolator(.array~of(.Maths~integer(0),.Maths~integer(2)),.array~of(.Maths~integer(1),.Maths~integer(5)),rctx)
call assertEq lirq~evaluate(.Maths~integer(1))~string,'3','rational interpolation stays exact'

rows=.array~of(.array~of(0,10),.array~of(20,30))
bi=.Maths~bilinearInterpolator(.array~of(0,1),.array~of(0,1),rows,ctx)
call assertNear bi~evaluate('.5','.5'),15,'1E-50','bilinear interpolation centre'
call assertNear bi~evaluate(1,1),30,'1E-50','bilinear interpolation upper corner'
call expectBilinearDomain bi

birq=.Maths~bilinearInterpolator(.array~of(.Maths~integer(0),.Maths~integer(2)),.array~of(.Maths~integer(0),.Maths~integer(2)),.array~of(.array~of(.Maths~integer(0),.Maths~integer(2)),.array~of(.Maths~integer(2),.Maths~integer(4))),rctx)
call assertEq birq~evaluate(.Maths~integer(1),.Maths~integer(1))~string,'2','rational bilinear interpolation stays exact'

/* Physics dev15 sampled/spectral observations. */
s=.Maths~sampledSeries(ctx)
s~append(0,1); s~append(1,2); s~append(2,3); s~append(3,4)
call assertNear s~mean,'2.5','1E-50','sampled series mean'
call assertNear s~rms,.Maths~sqrt('7.5',ctx),'1E-48','sampled series RMS'
call assertEq s~count,4,'sampled series count'
call assertNear s~duration,3,'1E-50','sampled series duration'

call assertEq s~isUniform,.true,'uniform sampled series detected'
nonuniform=.Maths~sampledSeries(ctx); nonuniform~append(0,0); nonuniform~append(1,0); nonuniform~append('2.1',0)
call assertEq nonuniform~isUniform,.false,'nonuniform sampled series detected'

wave=.Maths~sampledSeries(ctx); pi=.Maths~pi(ctx)
do i=0 to 15
  t=i/16
  wave~append(t,.Maths~sin(2*pi*t,ctx))
end
fc=wave~fourierComponent(1)
call assertNear fc~amplitude,1,'1E-45','selected-frequency Fourier amplitude'
call assertNear fc~cosineComponent,0,'1E-45','selected-frequency cosine component'
call assertNear fc~sineComponent,1,'1E-45','selected-frequency sine component'
call assertEq fc~sampleCount,16,'spectral component sample count'

/* Physics ray/paraboloid quadratic patterns. */
q=.Maths~quadratic(1,-5,6,rctx)~solve
call assertEq q~hasRealRoots,.true,'quadratic real-root flag'
call assertEq q~root1~string,'3','exact quadratic first root'
call assertEq q~root2~string,'2','exact quadratic second root'
call assertEq q~smallestPositive~string,'2','smallest positive quadratic root'
qc=.Maths~quadratic(1,0,1,ctx)~solve
call assertEq qc~hasRealRoots,.false,'complex quadratic root flag'
call assertNear qc~root1~real,0,'1E-50','complex quadratic real part'
call assertNear qc~root1~imaginary,1,'1E-48','complex quadratic imaginary part'

qs=.Maths~quadratic(1,'1E20',1,ctx)~solve
call assertNear qs~root1*qs~root2,1,'1E-25','stable quadratic roots preserve product c/a'
call assertNear qs~root1+qs~root2,'-1E20','1E-25','stable quadratic roots preserve sum -b/a'

/* Explicit simultaneous-equation object over established matrix solver. */
ls=.Maths~linearSystem(.array~of(.array~of(2,1),.array~of(1,-1)),.array~of(5,1),rctx)
sol=ls~solve
call assertEq sol[1]~string,'2','exact linear-system x'
call assertEq sol[2]~string,'1','exact linear-system y'
res=ls~residual(sol)
call assertEq res[1]~string,'0','linear-system first residual exact zero'
call assertEq res[2]~string,'0','linear-system second residual exact zero'

sr=.Maths~scalarResult('SQRT',2,ctx)
call assertEq sr~evidence~primaryProvider,'PURE','scalar result carries provider evidence'
call assertEq sr~operation,'SQRT','scalar result records operation'

say 'PASS oorexx_maths physics foundations' passes 'assertions'
exit 0

assertEq: procedure expose passes
  use arg actual,expected,label
  if actual==expected then do; passes+=1; say 'PASS' label; return; end
  say 'FAIL' label 'actual='actual 'expected='expected; exit 1
assertNear: procedure expose passes
  use arg actual,expected,tol,label
  numeric digits 90
  if abs(actual-expected)<=tol then do; passes+=1; say 'PASS' label; return; end
  say 'FAIL' label 'actual='actual 'expected='expected 'tol='tol; exit 1
expectIrrationalSqrt: procedure expose passes rctx
  signal on syntax name gotIrrationalSqrt
  x=.Maths~sqrt(2,rctx)
  say 'FAIL irrational rational sqrt did not fail' x; exit 1
gotIrrationalSqrt:
  say 'EXPECTED CONDITION rc=' rc 'sigl=' sigl 'condition=' condition("C") 'description=' condition("D")
  passes+=1; say 'PASS rational irrational sqrt fails closed'; return
expectLinearDomain: procedure expose passes
  use arg li
  signal on syntax name gotLinearDomain
  x=li~evaluate(-1)
  say 'FAIL linear interpolation extrapolated silently' x; exit 1
gotLinearDomain:
  say 'EXPECTED CONDITION rc=' rc 'sigl=' sigl 'condition=' condition("C") 'description=' condition("D")
  passes+=1; say 'PASS linear interpolation fails outside domain'; return
expectBilinearDomain: procedure expose passes
  use arg bi
  signal on syntax name gotBilinearDomain
  x=bi~evaluate(2,.5)
  say 'FAIL bilinear interpolation extrapolated silently' x; exit 1
gotBilinearDomain:
  say 'EXPECTED CONDITION rc=' rc 'sigl=' sigl 'condition=' condition("C") 'description=' condition("D")
  passes+=1; say 'PASS bilinear interpolation fails outside domain'; return

::requires 'MathsBootstrap.cls'
