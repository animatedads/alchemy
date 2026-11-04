/* Replays the 28 known-answer numerical anchors from SLAM v0.1. */
signal on syntax name onSyntax
checks=0
failures=0
m=.SlamMathsAdapter~new(.MathContext~decimal(20))

data='2 4 4 4 5 5 7 9'
call case 'ADD',data,'40'
call case 'ADD','1 2 3','6'
call case 'COUNT',data,'8'
call case 'COUNT','7','1'
call case 'MEAN',data,'5'
call case 'MEAN','1 2','1.5'
call case 'MEDIAN',data,'4.5'
call case 'MEDIAN','3 1 2','2'
call case 'MODE',data,'4'
call case 'MODE','1 1 2 2','ERROR'
call case 'RANGE',data,'7'
call case 'RANGE','5 -1','6'
call case 'VARIANCE',data,'4'
call case 'VARIANCE','1 2 3 4','1.25'
call case 'STANDARD',data,'2'
call case 'STANDARD','1 1 1','0'
call case 'DEVIATION',data,'-3 -1 -1 -1 0 0 2 4'
call case 'DEVIATION','1 3','-1 1'
call case 'SQUARE','2 -3','4 9'
call case 'SQUARE','0.5','0.25'
call case 'ROOT','16 2','4 1.41421356237309504880'
call case 'ROOT','-1','ERROR'
call case 'MULTIPLY','2 3 4','24'
call case 'MULTIPLY','5','5'
call case 'SUBTRACT','10 3 2','5'
call case 'SUBTRACT','1 4','-3'
call case 'DIVIDE','24 2 3','4'
call case 'DIVIDE','1 0','ERROR'

if failures=0 then do
  say 'PASS SLAM Maths adapter 28 anchor cases'
  exit 0
end
say 'FAIL SLAM Maths adapter failures='failures
exit 1

case: procedure expose m checks failures
  use arg method,inputText,expectedText
  checks+=1
  input=.array~new
  do i=1 to inputText~words
    input~append(inputText~word(i))
  end
  expected=.array~new
  if expectedText\='ERROR' then do i=1 to expectedText~words
    expected~append(expectedText~word(i))
  end
  gotError=.false
  signal on syntax name caseSyntax
  got=m~send(method,input)
  signal off syntax
  if expectedText='ERROR' then do
    failures+=1
    say 'FAIL' method inputText 'expected refusal'
    return
  end
  if got~items\=expected~items then do
    failures+=1
    say 'FAIL' method inputText 'item count'
    return
  end
  do i=1 to got~items
    if abs(got[i]-expected[i])>1e-15 then do
      failures+=1
      say 'FAIL' method inputText 'item' i 'got' got[i] 'expected' expected[i]
      return
    end
  end
  say 'PASS' method inputText
  return
caseSyntax:
  say 'expected/observed syntax rc='rc 'sigl='sigl 'condition='condition('C') 'description='condition('D')
  gotError=.true
  signal off syntax
  if expectedText='ERROR' then do
    say 'PASS' method inputText 'refused'
    return
  end
  failures+=1
  say 'FAIL' method inputText 'unexpected refusal'
  return

onSyntax:
  say 'SYNTAX line' sigl ':' condition('D')
  exit 2

::requires 'SlamMathsAdapter.cls'
