parse arg bridge
if bridge=='' then bridge='../bridge/libssh.bridge.json'
p=.SshForeignLibsshProvider~new(bridge)
probe=p~probe
call assert probe['provider']='native','native provider'
call assert pos('libssh',probe['provider_path'])>0,'libssh loaded'
call assert pos('.',probe['version'])>0,'version returned'
s=p~session
call assert s<>.nil,'session created'
s~close
say 'libssh='probe['version'] 'server_capable='probe['server_capable']
say 'PASS test_foreign_libssh'
exit 0
assert: procedure
  use strict arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
::requires '../src/SshCore.cls'
