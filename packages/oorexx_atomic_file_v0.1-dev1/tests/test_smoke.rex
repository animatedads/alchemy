numeric digits 30
root = '/tmp/oorexx-atomic-dev1-' || SysGetpid()
call SysMkDir root
path = root || '/state.txt'
a = .AtomicFile~new
r = a~replace(path, 'first' || '0a'x)
call assertTrue r~ok, 'create ok'
call assertTrue r~published, 'create published'
call assertTrue r~parentSynced, 'full parent synced'
call assertTrue charin(path,1,6) == 'first' || '0a'x, 'create bytes'
call stream path, 'c', 'close'

r = a~replace(path, 'second')
call assertTrue r~ok, 'replace ok'
call assertTrue r~replacedExisting, 'replace existing evidence'
call assertTrue charin(path,1,6) == 'second', 'replace bytes'
call stream path, 'c', 'close'

link = root || '/link.txt'
call SysSymlink path, link
r = a~replace(link, 'bad')
call assertTrue \r~ok, 'symlink rejected'
call assertTrue r~errorStage == 'TARGET_SYMLINK', 'symlink stage'
call SysUnLink link
call SysUnLink path
call SysRmDir root
say 'PASS test_smoke'
exit 0

assertTrue:
  use arg condition, label
  if \condition then do
    say 'FAIL' label
    exit 2
  end
  return

::requires 'AtomicFile.cls'
::requires 'rxunixsys' LIBRARY
