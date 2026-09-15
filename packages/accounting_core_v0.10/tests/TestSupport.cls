::class AccountingTest public
::method init
  expose failures assertions
  failures = 0; assertions = 0
::method assertTrue
  expose failures assertions
  use arg condition, message
  assertions += 1
  if \condition then do
    failures += 1
    say "FAIL:" message
  end
::method assertEq
  expose failures assertions
  use arg expected, actual, message
  assertions += 1
  if expected~string \= actual~string then do
    failures += 1
    say "FAIL:" message "expected=" expected "actual=" actual
  end
::method failures
  expose failures
  return failures
::method assertions
  expose assertions
  return assertions
