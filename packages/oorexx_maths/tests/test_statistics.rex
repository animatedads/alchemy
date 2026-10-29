numeric digits 50
failures=0
ctx=.MathContext~rational
data=.array~of(2,4,4,4,5,5,7,9)
s=.Maths~statistics(data,ctx)
call check s~count=8,'count'
call check s~sum=40,'sum'
call check s~product=201600,'product'
call check s~mean=5,'mean'
call check s~median=.Maths~fraction(9,2),'median exact 9/2'
call check s~uniqueMode=4,'unique mode'
call check s~minimum=2 & s~maximum=9,'minimum and maximum'
call check s~range=7,'range'
call check s~populationVariance=4,'population variance'
call check s~sampleVariance=.Maths~fraction(32,7),'sample variance 32/7'
call check s~populationStdDev=2,'population standard deviation'
expected=.array~of(-3,-1,-1,-1,0,0,2,4)
dev=s~deviations~toArray
call check dev~items=expected~items,'deviation count'
do i=1 to expected~items
  call check dev[i]=expected[i],'deviation 'i
end
sq=.Maths~statistics(.array~of(2,-3),ctx)~squaredValues~toArray
call check sq[1]=4 & sq[2]=9,'squared values'
modes=.Maths~statistics(.array~of(1,1,2,2),ctx)~modes
call check modes~items=2,'all tied modes are represented'
modeRejected=.false
signal on syntax name onModeTie
x=.Maths~statistics(.array~of(1,1,2,2),ctx)~uniqueMode
signal off syntax
signal modeDone
onModeTie:
  say 'expected mode-tie rejection rc='rc 'sigl='sigl 'condition='condition('C') 'description='condition('D')
  modeRejected=.true
  signal off syntax
modeDone:
call check modeRejected,'unique mode refuses ties'
exact=.Maths~statistics(.array~of(1,2),ctx)
call check exact~mean=.Maths~fraction(3,2),'rational mean remains exact'
call check exact~populationVariance=.Maths~fraction(1,4),'rational variance remains exact'
call check exact~sampleVariance=.Maths~fraction(1,2),'rational sample variance remains exact'
copy=s~values
copy[1]=999
call check s~minimum=2,'values returns defensive copy'
emptyRejected=.false
signal on syntax name onEmpty
x=.Maths~statistics(.array~new,ctx)~mean
signal off syntax
signal emptyDone
onEmpty:
  say 'expected empty-statistics rejection rc='rc 'sigl='sigl 'condition='condition('C') 'description='condition('D')
  emptyRejected=.true
  signal off syntax
emptyDone:
call check emptyRejected,'empty mean fails closed'
sampleRejected=.false
signal on syntax name onSample
x=.Maths~statistics(.array~of(1),ctx)~sampleVariance
signal off syntax
signal sampleDone
onSample:
  say 'expected sample-variance rejection rc='rc 'sigl='sigl 'condition='condition('C') 'description='condition('D')
  sampleRejected=.true
  signal off syntax
sampleDone:
call check sampleRejected,'sample variance requires two values'
if failures=0 then do
  say 'PASS oorexx_maths statistics 29 assertions'
  exit 0
end
say 'FAIL oorexx_maths statistics failures='failures
exit 1
check: procedure expose failures
  use arg ok,label
  if ok then do; say 'PASS' label; return; end
  failures+=1
  say 'FAIL' label
  return
::requires 'MathsBootstrap.cls'
