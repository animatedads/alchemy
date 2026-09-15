::class CRMTest public
::method assertTrue class
  use arg value, message="assertTrue failed"
  if \value then raise syntax 88.900 array(message)
::method assertEqual class
  use arg expected, actual, message="assertEqual failed"
  if expected~string \= actual~string then raise syntax 88.901 array(message||" expected="||expected||" actual="||actual)
