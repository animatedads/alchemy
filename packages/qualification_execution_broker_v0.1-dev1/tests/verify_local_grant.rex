.QebTestFixture~installCrypto
parse arg challengePath grantPath
ch=.json~fromJSON(charin(challengePath,1,chars(challengePath))); call stream challengePath,'c','close'
g=.json~fromJSON(charin(grantPath,1,chars(grantPath))); call stream grantPath,'c','close'
if g['runId']<>ch['runId'] | g['intentHash']<>ch['intentHash'] then do; say 'FAIL local grant identity'; exit 1; end
pub='d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a'
if \.Ed25519~verify(ch['messageToSign'],g['signature'],pub) then do; say 'FAIL local grant signature'; exit 1; end
say 'PASS verify_local_grant'
::requires 'TestFixture.cls'
::requires 'crypto.cls'
::requires 'json.cls'
