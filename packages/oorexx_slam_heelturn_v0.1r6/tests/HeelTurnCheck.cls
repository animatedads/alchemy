/* HeelTurnCheck.cls - assertion counter for the Heel Turn tests.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5). */
::class HeelTurnCheck public
::attribute passed get
::attribute failed get
::method init
  expose passed failed suite
  use strict arg suite
  passed = 0
  failed = 0
::method that
  expose passed failed suite
  use strict arg ok, label
  if ok then passed += 1
  else do
    failed += 1
    say 'FAIL' suite':' label
  end
  return ok
::method finish
  expose passed failed suite
  if failed = 0 then say 'PASS' suite passed 'checks'
  else say 'FAILED' suite failed 'of' passed + failed 'checks'
  return failed = 0
::method module_version class
  return '0.1r6'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-27'
::method module_lastChanged
  return self~class~module_lastChanged
