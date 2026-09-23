p = .Posix~new
missing = '/tmp/oorexx-posix-definitely-missing-' || SysGetpid()

r = p~statBasic(missing)
call assertTrue \r~ok, 'missing statBasic fails'
call assertTrue r~error~errno \== .nil, 'missing stat preserves errno'
call assertTrue r~error~provider == 'rxunixsys', 'missing stat provider evidence'

r = p~listDirectory(missing)
call assertTrue \r~ok, 'missing directory fails'
call assertTrue r~error~errno \== .nil, 'missing directory preserves errno'

r = p~readLink(missing)
call assertTrue \r~ok, 'readLink unavailable'
call assertTrue r~error~kind == 'CAPABILITY_UNAVAILABLE', 'readLink capability error'

r = p~lookupUser('definitely_no_such_user_oorexx_posix')
call assertTrue \r~ok, 'missing user fails'
call assertTrue r~error~kind == 'LOOKUP_NOT_FOUND', 'missing user is structured not-found'
call assertTrue r~error~errno = 0, 'missing user does not invent errno'

r = p~lookupGroup('definitely_no_such_group_oorexx_posix')
call assertTrue \r~ok, 'group lookup unavailable before unsafe native call'
call assertTrue r~error~kind == 'CAPABILITY_UNAVAILABLE', 'group lookup fail-closed capability'

say 'PASS test_failures'
exit 0

assertTrue:
  use arg condition, label
  if \condition then do
    say 'FAIL' label
    exit 2
  end
  return

::requires 'Posix.cls'
::requires 'rxunixsys' LIBRARY
