numeric digits 80
failures=0

Q=.Maths~rationalField
call check Q~name='Q','rational field name'
call check Q~characteristic=0,'rational field characteristic zero'
call check Q~add('1/3','1/6')=.Maths~fraction(1,2),'rational field exact addition'
call check Q~multiply('2/3','9/4')=.Maths~fraction(3,2),'rational field exact multiplication'
call check Q~inverse('3/5')=.Maths~fraction(5,3),'rational field exact inverse'
call check Q~contains(.Maths~fraction(2,7)),'rational field contains exact rational values'
call check \Q~contains('2/7'),'rational field membership is representation membership, not coercibility'

PR=.Maths~polynomialRing('x')
x=PR~variable
one=PR~one
poly=(x*x)-one
call check poly~degree=2,'polynomial degree'
call check poly~coefficient(2)=1,'polynomial leading coefficient'
call check poly~coefficient(1)=0,'polynomial absent coefficient is zero'
call check poly~coefficient(0)=-1,'polynomial constant coefficient'
call check poly~evaluate(2)=3,'polynomial exact Horner evaluation'
dp=poly~derivative
call check dp~degree=1,'polynomial derivative degree'
call check dp~coefficient(1)=2,'polynomial derivative coefficient'
call check dp~evaluate(.Maths~fraction(3,2))=3,'polynomial derivative exact evaluation'

q=PR~polynomial(.array~of(.Maths~fraction(1,2),.Maths~fraction(1,3)))
r=q*q
call check r~coefficient(0)=.Maths~fraction(1,4),'polynomial multiplication constant term'
call check r~coefficient(1)=.Maths~fraction(1,3),'polynomial multiplication cross term'
call check r~coefficient(2)=.Maths~fraction(1,9),'polynomial multiplication quadratic term'
call check (q+PR~zero)~equals(q),'polynomial additive identity'
call check (q*PR~one)~equals(q),'polynomial multiplicative identity'

xMinusOne=x-PR~one
division=poly~divideWithRemainder(xMinusOne)
call check division~exact,'polynomial exact division has zero remainder'
call check division~quotient~equals(x+PR~one),'polynomial quotient x^2-1 over x-1 is x+1'
call check xMinusOne~divides(poly),'polynomial divisibility predicate'
other=(x*x)-(x*3)+2
g=poly~gcd(other)
call check g~equals(xMinusOne),'polynomial gcd is monic x-1'
nonExact=(x*x)+PR~one
nonDivision=nonExact~divideWithRemainder(xMinusOne)
call check \nonDivision~exact,'polynomial division exposes nonzero remainder'
call check nonDivision~remainder~degree=0,'polynomial remainder degree below divisor'
call check nonDivision~remainder~coefficient(0)=2,'polynomial remainder value is exact'

VS=.Maths~rationalVectorSpace(3)
e1=VS~basis(1); e2=VS~basis(2); e3=VS~basis(3)
call check VS~dimension=3,'vector-space dimension'
call check VS~contains(e1),'basis vector belongs to space'
call check e1[1]=1,'first basis vector first coordinate'
call check e1[2]=0,'first basis vector second coordinate'
call check e1[3]=0,'first basis vector third coordinate'
vec=VS~vector(.array~of(1,.Maths~fraction(1,2),-2))
w=VS~scale(2,vec)
call check w[1]=2,'scaled vector first coordinate'
call check w[2]=1,'scaled vector second coordinate'
call check w[3]=-4,'scaled vector third coordinate'
call check VS~add(vec,VS~zero)~canonical=vec~canonical,'vector-space additive identity'

W=.Maths~rationalVectorSpace(2)
A=.Maths~rationalMatrix(.array~of(.array~of(1,2,0),.array~of(0,1,1)))
f=.Maths~linearMap(VS,W,A)
y=f~apply(VS~vector(.array~of(1,2,3)))
call check y[1]=5,'linear map first output coordinate'
call check y[2]=5,'linear map second output coordinate'
call check \f~isEndomorphism,'3-to-2 map is not an endomorphism'

B=.Maths~rationalMatrix(.array~of(.array~of(1,0),.array~of(0,1),.array~of(1,1)))
g=.Maths~linearMap(W,VS,B)
h=f~compose(g)
z=h~apply(VS~vector(.array~of(1,2,3)))
call check z[1]=5,'composed linear map first coordinate'
call check z[2]=5,'composed linear map second coordinate'
call check z[3]=10,'composed linear map third coordinate'
call check h~isEndomorphism,'composed 3-to-3 map is endomorphism'

u=VS~vector(.array~of(.Maths~fraction(1,3),.Maths~fraction(2,5),.Maths~fraction(7,11)))
left=f~apply(VS~scale(.Maths~fraction(3,7),u))
right=W~scale(.Maths~fraction(3,7),f~apply(u))
call check left~canonical=right~canonical,'linear map preserves exact scalar multiplication'

if failures=0 then do; say 'PASS oorexx_maths algebra foundations 44 assertions'; exit 0; end
say 'FAIL oorexx_maths algebra foundations failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label
::requires 'MathsBootstrap.cls'
