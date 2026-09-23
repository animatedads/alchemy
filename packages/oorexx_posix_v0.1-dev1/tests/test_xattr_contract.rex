p = .Posix~new
root = '/tmp/oorexx-posix-xattr-' || SysGetpid()
call lineout root, 'x'
call lineout root

if p~capabilities~has('posix.xattr.write') then do
  r = p~setXattr(root, 'user.oorexx_posix_dev1', 'abc')
  if r~ok then do
    wr = p~getXattrWeak(root, 'user.oorexx_posix_dev1')
    call assertTrue wr~ok, 'weak xattr read result'
    call assertTrue wr~value~value == 'abc', 'weak xattr payload'
    call assertTrue \wr~value~ambiguousEmpty, 'non-empty xattr is not ambiguous'

    strong = p~getXattr(root, 'user.oorexx_posix_dev1')
    call assertTrue \strong~ok, 'strong xattr must remain unavailable'
    call assertTrue strong~error~kind == 'CAPABILITY_UNAVAILABLE', 'strong xattr capability error'

    r = p~removeXattr(root, 'user.oorexx_posix_dev1')
    call assertTrue r~ok, 'remove xattr'
  end
  else say 'SKIP filesystem rejected user xattr:' r~error~string
end
else say 'SKIP xattr write routines unavailable'

call SysFileDelete root
say 'PASS test_xattr_contract'
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
