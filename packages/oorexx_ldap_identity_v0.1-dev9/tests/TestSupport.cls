::class LdapIdentityTest public
::method assert class
  use strict arg condition, message
  if \condition then raise syntax 88.900 array("ASSERT: " || message)
  return .true
::method equal class
  use strict arg expected, actual, message
  if expected <> actual then raise syntax 88.900 array("ASSERT: " || message || " expected=" || expected || " actual=" || actual)
  return .true
