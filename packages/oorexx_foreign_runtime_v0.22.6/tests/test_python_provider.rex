failures=0
py=.ForeignPython~import('python_fixture')
call check py~provider='python','python provider identity'
call check py~threadingMode='gil-managed','python GIL policy'
call check py~add(20,22)=42,'python integer call'
call check py~greet('Rexx')='hello Rexx','python string call'
call check py~describe_type(.ForeignPython~text('20'))='str','explicit Python text override'
call check py~describe_type(.ForeignPython~integer('20'))='int','explicit Python integer override'
call check py~describe_type(.ForeignPython~float('20'))='float','explicit Python float override'
a=.array~of(1,2,3,4)
call check py~sum_list(a)=10,'ooRexx array to Python list'
raw='61006200ff'x
pb=.ForeignPython~bytes(raw)
call check py~binary_len(pb)=5,'python bytes embedded NUL length'
call check py~binary_echo(pb)==raw,'python bytes exact roundtrip'
box=py~make_box(7)
call check box~typeName~pos('Box')>0,'python object proxy type'
call check box~get('value')=7,'python object getattr'
call check box~inc(5)=12,'python object method dispatch'
call check py~signature('add')~pos('int')>0,'python signature introspection'
ms=py~methods; found=0
do m over ms; if m='add' then found=1; end
call check found=1,'python method discovery'
call check py~pythonVersion~pos('3.')>0,'python runtime descriptor'
box~close; py~close

hashlib=.ForeignPython~import('hashlib')
h=hashlib~sha256(.ForeignPython~bytes('abc'))
call check h~hexdigest='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad','Python hashlib C-extension SHA-256'
h~close; hashlib~close

if failures=0 then do; say 'PASS Python provider 17 assertions'; exit 0; end
say 'FAIL Python provider failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then return
  failures+=1; say 'FAIL' label
  return
::requires '../rexx/python_foreign.cls'
