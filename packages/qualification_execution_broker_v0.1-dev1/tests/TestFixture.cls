::class QebTestFixture public
::method installCrypto class
  cryptoHome=value('CRYPTO_HOME',,'ENVIRONMENT')
  if cryptoHome='' then return
  direct=cryptoHome||'/native/openssl_direct.bridge.json'
  compat=cryptoHome||'/native/openssl_compat.bridge.json'
  .CryptoForeignRuntimeInstaller~install(direct,.nil,1000,'foreign.openssl.crypto',compat)

::method catalog class
  c=.QebAuthorityCatalog~new
  d=.directory~new; d['sha256']='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; d['signed']=.true; d['checked']=.true; d['deployed']=.true; c~add('artifact','demo-artifact',d)
  d=.directory~new; d['manifestSha256']='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'; d['authorized']=.true; d['available']=.true; c~add('data','demo-data',d)
  d=.directory~new; d['manifestSha256']='cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc'; d['available']=.true; c~add('runtime','oorexx-5.3.0-r13196',d)
  d=.directory~new; d['profileSha256']='dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd'; d['available']=.true; d['constructible']=.true; d['maxRuntimeSeconds']=1800; d['maxWlu']=2400; d['networkPolicy']='DENY'; d['writableScopes']=.array~of('/sandbox/work','/sandbox/results'); c~add('sandbox','strict-oorexx',d)
  d=.directory~new; d['manifestSha256']='eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'; d['valid']=.true; d['commands']=.array~of('rexx tests/test_core.rex','rexx tests/test_restart.rex'); c~add('testplan','demo-tests',d)
  d=.directory~new; d['profileSha256']='ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'; d['eligible']=.true; d['available']=.true; c~add('target','ed209-test',d)
  return c
::method approvers class
  r=.QebApproverRegistry~new
  r~add('architect-ed25519','d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a','Architect local key',.true)
  return r
::method args class
  a=.directory~new; a['artifactId']='demo-artifact'; a['dataId']='demo-data'; a['runtimeId']='oorexx-5.3.0-r13196'; a['sandboxId']='strict-oorexx'; a['testPlanId']='demo-tests'; a['targetId']='ed209-test'; a['purpose']='qualification regression'; return a
::requires 'QualificationExecutionBroker.cls'
::requires 'CryptoForeignRuntimeProvider.cls'
