failures=0
py=.ForeignPython~import('python_fixture')
seq=py~make_sequence_box
call check seq~isA(.ForeignPythonObject),'custom Python sequence remains resident proxy'
call check seq~items=3,'ForeignPythonObject ITEMS uses Python len()'
call check seq[1]='alpha','Rexx [] index 1 maps to Python index 0'
call check seq~at(2)='beta','AT is one-based Rexx indexing'
call check seq~pythonAt(0)='alpha','pythonAt preserves Python zero-based indexing'
call check seq~pythonAt(-1)='gamma','pythonAt preserves Python negative indexing'
seq~close
map=py~make_mapping_box
call check map['name']='foreign','Rexx [] preserves nonnumeric Python mapping keys'
call check map~pythonAt(0)='zero','pythonAt preserves exact numeric mapping key'
map~close
py~close
if failures=0 then do; say 'PASS Python collection indexing v0.22.2'; exit 0; end
say 'FAIL Python collection indexing failures='failures; exit 1
check: procedure expose failures
  use arg condition,label
  if condition then return
  failures+=1; say 'FAIL' label
  return
::requires '../rexx/python_foreign.cls'
