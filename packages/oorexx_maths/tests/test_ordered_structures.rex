numeric digits 50
failures=0
scale=.Maths~finiteChain(.array~of('STYLOMETRIC','TESTIMONY','DOCUMENTARY','PROVENANCE'))
call check scale~cardinality=4,'finite chain cardinality'
call check scale~rank('STYLOMETRIC')=1,'bottom rank'
call check scale~rank('PROVENANCE')=4,'top rank'
call check scale~bottom='STYLOMETRIC' & scale~top='PROVENANCE','bottom/top values'
call check scale~lessThan('TESTIMONY','DOCUMENTARY'),'strict order'
call check scale~lessOrEqual('DOCUMENTARY','DOCUMENTARY'),'reflexive non-strict order'
call check scale~greaterThan('PROVENANCE','STYLOMETRIC'),'reverse strict order'
call check scale~greaterOrEqual('TESTIMONY','TESTIMONY'),'reverse reflexive order'
call check scale~compare('STYLOMETRIC','PROVENANCE')=-1,'compare lower'
call check scale~compare('DOCUMENTARY','TESTIMONY')=1,'compare higher'
call check scale~compare('TESTIMONY','TESTIMONY')=0,'compare equal'
call check scale~min('PROVENANCE','DOCUMENTARY')='DOCUMENTARY','minimum'
call check scale~max('TESTIMONY','DOCUMENTARY')='DOCUMENTARY','maximum'
call check scale~meet('PROVENANCE','STYLOMETRIC')='STYLOMETRIC','chain meet'
call check scale~join('TESTIMONY','PROVENANCE')='PROVENANCE','chain join'
call check scale~contains('DOCUMENTARY'),'membership'
call check \scale~contains('UNKNOWN'),'unknown is not member'
call check scale~canonical='finite-chain[11:STYLOMETRIC<9:TESTIMONY<11:DOCUMENTARY<10:PROVENANCE]','canonical order is stable'
copy=scale~values
copy[1]='MUTATED'
call check scale~bottom='STYLOMETRIC','values returns defensive copy'
unknownRejected=.false
signal on syntax name unknownValue
x=scale~rank('UNKNOWN')
signal off syntax
signal unknownDone
unknownValue:
  say 'expected unknown-rank rejection rc='rc 'sigl='sigl 'condition='condition('C') 'description='condition('D')
  unknownRejected=.true
  signal off syntax
unknownDone:
call check unknownRejected,'unknown rank fails closed'
duplicateRejected=.false
signal on syntax name duplicateValue
bad=.Maths~finiteChain(.array~of('LOW','LOW'))
signal off syntax
signal duplicateDone
duplicateValue:
  say 'expected duplicate-chain rejection rc='rc 'sigl='sigl 'condition='condition('C') 'description='condition('D')
  duplicateRejected=.true
  signal off syntax
duplicateDone:
call check duplicateRejected,'duplicate value fails closed'
if failures=0 then do; say 'PASS oorexx_maths ordered structures 21 assertions'; exit 0; end
say 'FAIL oorexx_maths ordered structures failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then do; say 'PASS' label; return; end
  failures+=1; say 'FAIL' label
::requires 'MathsBootstrap.cls'
