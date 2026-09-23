p=.SshForeignLibsshProvider~new('../bridge/libssh.bridge.json','0.11.5')
call assert \p~serverVersionAllowed('0.11.2/openssl/zlib'),'0.11.2 rejected for server'
call assert p~serverVersionAllowed('0.11.5/openssl/zlib'),'0.11.5 accepted'
call assert p~serverVersionAllowed('0.12.2/openssl/zlib'),'0.12.2 accepted'
say 'PASS test_version_gate'
exit 0
assert: procedure
  use strict arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
::requires '../src/SshCore.cls'
