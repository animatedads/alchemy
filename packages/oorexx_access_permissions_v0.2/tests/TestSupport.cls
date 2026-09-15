::routine assertTrue public
  use strict arg actual, message
  if actual <> .true then raise syntax 88.900 array("assertTrue failed: " || message)
  return
::routine assertFalse public
  use strict arg actual, message
  if actual <> .false then raise syntax 88.900 array("assertFalse failed: " || message)
  return
::routine assertEq public
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed: " || message || " expected=" || expected || " actual=" || actual)
  return
