failures=0
py=.ForeignPython~import('python_fixture')
obj=py~make_dtype_thing('float64')
call check py~module_dtype(obj)='float64','module-level Python proxy argument remains PyObject'
kw=.ForeignPython~keywords
kw~put('value',obj)
call check py~kw_dtype(kw)='float64','Python proxy survives kwargs marshalling'
d=.ForeignPython~dict
d~put('value',obj)
call check py~dict_dtype(d)='float64','Python proxy survives dict marshalling'
call check py~list_dtype(.Array~of(obj))='float64','Python proxy survives nested list marshalling'
if .ForeignPython~canImport('numpy') then do
  np=.ForeignPython~import('numpy')
  nkw=.ForeignPython~keywords; nkw~put('dtype','float32')
  arr=np~arange(8,nkw)
  tensor=arr~asTensor
  call check py~module_dtype(tensor)='float32','ForeignTensor passed to module-level Python function'
  tensor~close; arr~close; np~close
end
obj~close; py~close
if failures=0 then do; say 'PASS Python proxy argument marshalling v0.22.1'; exit 0; end
say 'FAIL Python proxy argument marshalling failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then return
  failures+=1; say 'FAIL' label
  return
::requires '../rexx/python_foreign.cls'
