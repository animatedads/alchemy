numeric digits 50
ctx=.MathContext~rational
A=.Maths~matrix(.array~of(.array~of(1,2),.array~of(3,4)),ctx)
b=.Maths~vector(.array~of(5,11),ctx)
x=A~solve(b)
say 'x =' x
say x~evidence~describe
say x~prove(.MathClaim~satisfiesEquation(0))~describe
::requires '../rexx/MathsBootstrap.cls'
