::class RIDTestSupport public
::method assertTrue class
  use arg condition, message = "assertTrue failed"
  if condition <> .true then do
    raise syntax 88.998 array(message)
  end
::method assertFalse class
  use arg condition, message = "assertFalse failed"
  if condition <> .false then do
    raise syntax 88.998 array(message)
  end
::method assertEq class
  use arg expected, actual, message = "assertEq failed"
  if expected~string <> actual~string then do
    raise syntax 88.998 array(message || " expected=" || expected || " actual=" || actual)
  end
::method ok class
  use arg result, message = "expected OK"
  if result~ok <> .true then do
    raise syntax 88.998 array(message || " " || result~code || " " || result~detail)
  end
  return result~value
::method failCode class
  use arg code, result, message = "unexpected result"
  if result~ok <> .false | result~code <> code then do
    raise syntax 88.998 array(message || " expected=" || code || " actual=" || result~code || " " || result~detail)
  end
  return result
