numeric digits 30
root = '/tmp/oorexx-atomic-contract-' || SysGetpid()
call SysMkDir root
path = root || '/name with space' || '09'x || 'and-tab.txt'
a = .AtomicFile~new

/* DATA sync explicitly differs from FULL namespace durability. */
o = .AtomicFileOptions~new
o~durability = 'DATA'
o~preserveMode = .false
o~mode = 416 /* 0640 */
r = a~replace(path, 'payload', o)
call assertTrue r~ok & r~published, 'data publish'
call assertTrue r~fileSynced & \r~parentSynced, 'data sync evidence'
call assertTrue r~mode = 416, 'requested mode'

/* Existing mode is preserved when requested. */
o = .AtomicFileOptions~new
r = a~replace(path, 'next', o)
call assertTrue r~ok & r~mode = 416, 'preserve existing mode'

/* Unsupported CAS must fail closed instead of pretending to fence a generation. */
o = .AtomicFileOptions~new
o~expectedGeneration = 'generation-1'
r = a~replace(path, 'bad', o)
call assertTrue \r~ok & \r~published, 'generation fail closed'
call assertTrue r~errorStage == 'EXPECTED_GENERATION', 'generation stage'
call assertTrue charin(path,1,4) == 'next', 'generation refusal left target unchanged'
call stream path, 'c', 'close'

/* No same-directory staging debris remains after success. */
entries = SysGetdirlist(root)
count = 0
do e over entries
  if e == '.' | e == '..' then iterate
  count += 1
end
call assertTrue count = 1, 'no staging debris'

call SysUnLink path
call SysRmDir root
say 'PASS test_contract'
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
