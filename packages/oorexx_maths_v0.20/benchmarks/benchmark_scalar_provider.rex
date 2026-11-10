parse arg provider count
if provider='' then provider='PURE'
if count='' then count=2000
if provider='PURE' then ctx=.MathContext~decimal(50,'PURE')
else ctx=.MathContext~binary64(provider)
numeric digits 50
sum=0
do i=1 to count
  x=i/137
  sum=sum+.Maths~sin(x,ctx)+.Maths~cos(x,ctx)+.Maths~exp(x/1000,ctx)
end
say provider 'count='count 'checksum='sum
::requires 'MathRxMathProvider.cls'
