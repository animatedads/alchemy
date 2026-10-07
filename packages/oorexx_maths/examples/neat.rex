numeric digits 50
A=.Maths~matrix(.array~of(.array~of(3,2),.array~of(1,2)))
b=.Maths~vector(.array~of(5,5))
x=A~solve(b)
say 'x =' x
say
say x~evidence~describe
say
say x~prove~describe
::requires '../rexx/MathsBootstrap.cls'
