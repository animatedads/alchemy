::class AJIAdapterTestSupport public
::method assert class
  use arg condition, message="assertion failed"
  if \condition then raise syntax 88.900 array(message)
::method eq class
  use arg expected, actual, message=""
  if expected~string <> actual~string then raise syntax 88.900 array("expected="||expected||" actual="||actual||" "||message)
::method ok class
  use arg r, message=""
  if r == .nil then raise syntax 88.900 array("missing result "||message)
  if \r~ok then raise syntax 88.900 array("expected OK got "||r~code||" "||r~detail||" "||message)
  return r
::method fail class
  use arg code, r, message=""
  if r == .nil then raise syntax 88.900 array("missing result "||message)
  if r~ok then raise syntax 88.900 array("expected failure "||code||" "||message)
  if r~code <> code then raise syntax 88.900 array("expected "||code||" got "||r~code||" "||r~detail)
  return r
