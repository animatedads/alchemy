py=.ForeignPython~import('python_fixture')
/* warm lazy wrappers on the main activity */
ignored=py~add(1,1)
workers=.array~new; messages=.array~new
do i=1 to 8
  w=.PythonWorker~new(py); workers~append(w); messages~append(w~start('stress',100))
end
do m over messages
  if m~result<>1 then do; say 'FAIL Python provider activity stress'; exit 1; end
end
py~close
say 'PASS Python provider activity stress'
exit 0
::class PythonWorker
::method init
  expose py
  use strict arg py
::method stress
  expose py
  use strict arg n
  do i=1 to n
    if py~add(i,1)<>i+1 then return 0
  end
  return 1
::requires '../rexx/python_foreign.cls'
