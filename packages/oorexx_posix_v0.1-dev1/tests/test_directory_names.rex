p = .Posix~new
root = '/tmp/oorexx-posix-names-' || SysGetpid()
r = p~mkdir(root, 448)
call assertOk r, 'mkdir'

names = .array~of('with space', 'with' || '09'x || 'tab', 'with' || '0a'x || 'newline', '.hidden')
do name over names
  path = root || '/' || name
  call lineout path, 'x'
  call lineout path
end

r = p~listDirectory(root)
call assertOk r, 'listDirectory'
call assertTrue r~value~items = names~items, 'all unusual names preserved'
do expected over names
  found = .false
  do actual over r~value~entries
    if actual == expected then do
      found = .true
      leave
    end
  end
  call assertTrue found, 'missing exact filename'
end

do name over names
  r = p~unlink(root || '/' || name)
  call assertOk r, 'unlink unusual name'
end
r = p~removeDirectory(root)
call assertOk r, 'rmdir'

say 'PASS test_directory_names'
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
