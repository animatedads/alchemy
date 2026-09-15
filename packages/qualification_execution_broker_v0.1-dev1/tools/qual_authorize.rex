#!/usr/bin/env rexx
/* Local-only human authorization utility.
 * Usage: rexx qual_authorize.rex challenge.json approverKeyId private-seed.hex grant.json
 * The private key file is not opened until after the user types YES.
 */
parse arg challengePath keyId privatePath outputPath
if value('QEB_CRYPTO_ACCEL',,'ENVIRONMENT')='1' then do
  cryptoHome=value('CRYPTO_HOME',,'ENVIRONMENT')
  if cryptoHome<>'' then .CryptoForeignRuntimeInstaller~install(cryptoHome||'/native/openssl_direct.bridge.json',.nil,1000,'foreign.openssl.crypto',cryptoHome||'/native/openssl_compat.bridge.json')
end
if challengePath='' | keyId='' | privatePath='' | outputPath='' then do
  say 'usage: qual_authorize.rex challenge.json approverKeyId private-seed.hex grant.json'
  exit 2
end
signal on syntax name failed
text=charin(challengePath,1,chars(challengePath)); call stream challengePath,'c','close'
challenge=.json~fromJSON(text)
if challenge==.nil | \challenge~isA(.Directory) then do; say 'ERROR invalid challenge JSON'; exit 3; end
intent=challenge['intent']; expected=challenge['intentHash']~string
actual=.QebUtil~sha256(.QebUtil~canonicalIntent(intent))
if actual<>expected then do; say 'ERROR intent hash mismatch'; exit 4; end
message=.QebUtil~signatureMessage(expected)
if challenge['messageToSign']~string<>message then do; say 'ERROR signature message mismatch'; exit 5; end
known=.false
do k over challenge['approverKeys']
  if k['keyId']~string=keyId then known=.true
end
if \known then do; say 'ERROR approver key is not offered by this challenge'; exit 6; end
say 'Qualification authorization request'
say 'Run:' intent['runId']
say 'Requester:' intent['requesterId']
say 'Purpose:' intent['purpose']
say 'Artifact:' intent['artifactId'] 'SHA-256' intent['artifactSha256']
say 'Data:' intent['dataId'] 'manifest SHA-256' intent['dataManifestSha256']
say 'Runtime:' intent['runtimeId']
say 'Sandbox:' intent['sandboxId'] 'network='intent['networkPolicy']
say 'Target:' intent['targetId']
say 'Limits: runtime='intent['maxRuntimeSeconds']'s WLU='intent['maxWlu']
say 'Commands:'
do command over intent['commands']; say '  'command; end
say 'Writable scopes:'
do scope over intent['writableScopes']; say '  'scope; end
say 'Intent SHA-256:' expected
say 'Authorization expires:' intent['authorizationExpiresAt']
say 'Type YES to sign this exact intent; anything else declines:'
pull answer
if answer~strip~upper<>'YES' then do
  say 'DECLINED - private key was not opened.'
  exit 0
end
/* The first private-key access is intentionally below the human decision. */
if stream(privatePath,'c','query exists')='' then do; say 'ERROR private key file not found'; exit 7; end
privateHex=charin(privatePath,1,chars(privatePath)); call stream privatePath,'c','close'
privateHex=privateHex~changestr('0a'x,'')~changestr('0d'x,'')~strip
if privateHex~length<>64 then do; privateHex=''; say 'ERROR private seed must be 32 bytes / 64 hex characters'; exit 8; end
signature=.Ed25519~sign(message,privateHex)
privateHex=''
grant=.directory~new
grant['runId']=intent['runId']; grant['approverKeyId']=keyId; grant['signature']=signature; grant['intentHash']=expected
call charout outputPath,.json~toJSON(grant); call stream outputPath,'c','close'
say 'SIGNED' intent['runId'] 'with' keyId
exit 0
failed:
say 'ERROR local authorization utility failed:' condition('D')
exit 20
::requires 'QualificationExecutionBroker.cls'
::requires 'CryptoForeignRuntimeProvider.cls'
::requires 'json.cls'
