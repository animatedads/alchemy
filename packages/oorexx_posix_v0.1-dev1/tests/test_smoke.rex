numeric digits 30
p = .Posix~new
call assertTrue p~provider == 'rxunixsys', 'provider'
call assertTrue p~capabilities~has('posix.stat.basic'), 'basic stat capability'
call assertTrue p~capabilities~has('posix.dir.iterate'), 'directory capability'

root = '/tmp/oorexx-posix-dev1-' || SysGetpid()
file = root || '/hello.txt'
linkPath = root || '/hello.link'
hardPath = root || '/hello.hard'

r = p~mkdir(root, 448) /* 0700 */
call assertOk r, 'mkdir'
call lineout file, 'hello'
call lineout file

r = p~stat(file)
call assertTrue \r~ok, 'strong stat must fail closed in dev1'
call assertTrue r~error~kind == 'CAPABILITY_UNAVAILABLE', 'strong stat capability failure'

r = p~statBasic(file)
call assertOk r, 'statBasic'
call assertTrue \r~value~coherent, 'statBasic must be marked non-coherent'
call assertTrue r~value~size > 0, 'statBasic size'
call assertTrue r~value~identity == .nil, 'non-coherent stat has no strong identity'

r = p~listDirectory(root)
call assertOk r, 'listDirectory'
call assertTrue r~value~items = 1, 'listDirectory filters dot entries'
call assertTrue r~value~entries[1] == 'hello.txt', 'listed file'

r = p~symlink('hello.txt', linkPath)
call assertOk r, 'symlink'
r = p~link(file, hardPath)
call assertOk r, 'hard link'

r = p~credentials
call assertOk r, 'credentials'
call assertTrue datatype(r~value~uid, 'W'), 'uid numeric'

r = p~lookupUser(r~value~uid)
call assertOk r, 'lookup user by uid'
call assertTrue r~value~name \== '', 'lookup user name'

r = p~lookupGroup(p~credentials~value~gid)
call assertTrue \r~ok, 'group lookup fails closed on this runtime'
call assertTrue r~error~kind == 'CAPABILITY_UNAVAILABLE', 'group lookup capability error'

r = p~unlink(linkPath); call assertOk r, 'unlink symlink'
r = p~unlink(hardPath); call assertOk r, 'unlink hard link'
r = p~unlink(file); call assertOk r, 'unlink file'
r = p~removeDirectory(root); call assertOk r, 'rmdir'

say 'PASS test_smoke'
exit 0

assertOk:
  use arg result, label
  if \result~ok then do
    say 'FAIL' label result~error~string
    exit 2
  end
  return

assertTrue:
  use arg condition, label
  if \condition then do
    say 'FAIL' label
    exit 2
  end
  return

::requires 'Posix.cls'
::requires 'rxunixsys' LIBRARY
