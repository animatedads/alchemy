numeric digits 50
failures=0
ctx=.MathContext~rational
p=.Maths~pairedStatistics(.array~of(1,2,3),.array~of(2,4,6),ctx)
call check p~count=3,'pair count'
call check p~leftMean=2,'left mean'
call check p~rightMean=4,'right mean'
call check p~populationCovariance=.Maths~fraction(4,3),'population covariance exact 4/3'
call check p~sampleCovariance=2,'sample covariance exact 2'
call check p~populationCorrelation=1,'population correlation exact +1'
call check p~sampleCorrelation=1,'sample correlation exact +1'
neg=.Maths~pairedStatistics(.array~of(1,2,3),.array~of(6,4,2),ctx)
call check neg~populationCorrelation=-1,'negative perfect correlation'
call check neg~sampleCorrelation=-1,'negative sample perfect correlation'
left=p~left~values
left[1]=99
call check p~left~minimum=1,'paired values remain defensive'
lengthRejected=.false
signal on syntax name onLength
bad=.Maths~pairedStatistics(.array~of(1,2),.array~of(1),ctx)
signal off syntax
signal lengthDone
onLength:
  say 'expected paired-length rejection rc='rc 'sigl='sigl 'condition='condition('C') 'description='condition('D')
  lengthRejected=.true
  signal off syntax
lengthDone:
call check lengthRejected,'unequal pair lengths fail closed'
zeroRejected=.false
signal on syntax name onZero
z=.Maths~pairedStatistics(.array~of(1,1,1),.array~of(2,3,4),ctx)~populationCorrelation
signal off syntax
signal zeroDone
onZero:
  say 'expected zero-variance rejection rc='rc 'sigl='sigl 'condition='condition('C') 'description='condition('D')
  zeroRejected=.true
  signal off syntax
zeroDone:
call check zeroRejected,'zero variance correlation fails closed'
if failures=0 then do
  say 'PASS oorexx_maths paired statistics 12 assertions'
  exit 0
end
say 'FAIL oorexx_maths paired statistics failures='failures
exit 1
check: procedure expose failures
  use arg ok,label
  if ok then do; say 'PASS' label; return; end
  failures+=1
  say 'FAIL' label
  return
::requires 'MathsBootstrap.cls'
