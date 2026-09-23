numeric digits 30
p = .PosixGapFactory~create
call assertTrue p~capabilities~has('posix.stat.coherent'), 'coherent stat capability'
call assertTrue p~capabilities~has('posix.lstat.coherent'), 'coherent lstat capability'
call assertTrue p~capabilities~has('posix.readlink'), 'readlink capability'

root = '/tmp/oorexx-posix-gap-' || SysGetpid()
file = root || '/target'
linkPath = root || '/link'
r = p~mkdir(root, 448); call assertOk r, 'mkdir'
call lineout file, 'abcdef'
call lineout file
r = p~symlink('target', linkPath); call assertOk r, 'symlink'

r = p~stat(file); call assertOk r, 'coherent stat'
call assertTrue r~value~coherent, 'stat coherent flag'
call assertTrue r~value~observationCount = 1, 'one native stat observation'
call assertTrue r~value~identity \== .nil, 'strong identity available'
call assertTrue r~value~fileType == 'REGULAR', 'regular type'
call assertTrue datatype(r~value~mtimeNsec, 'W'), 'nanosecond mtime available'

slink = p~lstat(linkPath); call assertOk slink, 'lstat symlink'
call assertTrue slink~value~fileType == 'SYMLINK', 'lstat sees symlink'
call assertTrue \slink~value~followedSymlink, 'lstat follow flag false'

follow = p~stat(linkPath); call assertOk follow, 'stat symlink target'
call assertTrue follow~value~fileType == 'REGULAR', 'stat follows symlink'
call assertTrue follow~value~followedSymlink, 'stat follow flag true'
call assertTrue follow~value~inode == r~value~inode, 'followed stat target identity'

rl = p~readLink(linkPath); call assertOk rl, 'readLink'
call assertTrue rl~value == 'target', 'symlink payload exact'

missing = p~stat(root || '/missing')
call assertTrue \missing~ok, 'missing strong stat failure'
call assertTrue missing~error~errno \== .nil, 'missing strong stat errno'

r = p~unlink(linkPath); call assertOk r, 'unlink symlink'
r = p~unlink(file); call assertOk r, 'unlink file'
r = p~removeDirectory(root); call assertOk r, 'rmdir'

say 'PASS test_gap_provider'
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

::requires 'PosixGap.cls'
::requires 'rxunixsys' LIBRARY
