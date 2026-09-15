failures=0
py=.ForeignPython~import('python_fixture')

m=py~method('add')
call check m~name='add','method object name'
call check m~overloadCount=1,'Python callable one runtime signature'
sig=m~signature
call check sig~returnType='int','signature return annotation'
call check sig~inputs~items=2,'signature input count'
call check sig~inputs[1]~name='a','first parameter name'
call check sig~inputs[1]~annotation='int','first parameter annotation'
call check sig~inputs[1]~required,'required parameter'

resolved=py~methodByInputs('add',20,22)
call check resolved~name='add','methodByInputs resolved callable'
call check resolved~returnType='int','methodByInputs return annotation'

-- Annotation-directed conversion: Rexx lexical 20 must remain text for annotated str.
call check py~annotated_text('20')='str:20','annotation-directed str conversion'

-- Exact Rexx binary can use Python's bytes annotation without an explicit wrapper.
raw='61006200ff'x
call check py~binary_len(raw)=5,'annotation-directed bytes conversion'
call check py~binary_echo(raw)==raw,'annotated bytes exact roundtrip'

kw=.ForeignPython~keywords
kw~put('punctuation','?')
call check py~kw_format('Rexx',kw)='hello Rexx?','keyword-only argument dispatch'
kw2=.ForeignPython~keywords
kw2~put('prefix','welcome')
kw2~put('punctuation','.')
call check py~kw_format('Rexx',kw2)='welcome Rexx.','multiple keyword arguments'

pd=.ForeignPython~dict
pd~put('alpha',10)
pd~put('beta',32)
call check py~dict_sum(pd)=42,'explicit Rexx to Python dict'
rd=py~make_dict
call check rd['alpha']=11,'Python string-key dict to Rexx Directory'
call check rd['beta']=31,'Python dict second key'

objects=py~methodObjects; found=0
do om over objects
  if om~name='add' then found=1
end
call check found=1,'methodObjects discovery'

call check py~signature('kw_format')~pos('punctuation')>0,'legacy signature display retained'

py~close
if failures=0 then do; say 'PASS Python provider v0.16 19 assertions'; exit 0; end
say 'FAIL Python provider v0.16 failures='failures; exit 1

check: procedure expose failures
  use arg condition,label
  if condition then return
  failures+=1; say 'FAIL' label
  return
::requires '../rexx/python_foreign.cls'
