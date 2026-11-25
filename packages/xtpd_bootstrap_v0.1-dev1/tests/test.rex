seed='11'~copies(32)
key=.directory~new; key['test1']=seed
v=.XtpTestRoleVerifier~new(key)
service=.LogService~new('xtpd-test')
target=.LogMemoryTarget~new('local',.Log~INTERNAL)
service~addTarget(target)
service~addRule(.LogRule~new('boot','xtpd','TestEmitter','EVENT',.Log~INTERNAL,.Log~INTERNAL,.Log~INFO,.nil,.array~of('local')))
logger=service~loggerFor(.TestEmitter~new,'EVENT',.array~new,.Log~INTERNAL)
r1='ROLE|LDAP|main1|spare1|1|1|seed1|test1'
r2='ROLE|LDAP|spare1|main1|2|1|seed1|test1'
r3='ROLE|LDAP|main1|spare1|2|2|seed1|test1'
a=seal(r1,'test1',seed); b=seal(r2,'test1',seed); c=seal(r3,'test1',seed)
s=.TestStore~new(a)
boot=.XtpRoleBootstrap~new(s,v,logger)
call check boot~record~main == 'main1','local main'
call check boot~record~spare == 'spare1','local spare'
call check boot~offer(a) == 'NOT_NEWER','replay'
call check boot~offer('bad') == 'INVALID_OR_FAILED','malformed'
call check boot~offer(seal(r2,'test2',seed)) == 'UNTRUSTED_KEY','untrusted signer'
call check boot~offer(seal(r2,'test1','22'~copies(32))) == 'BAD_SIGNATURE','wrong tag'
call check boot~offer(seal('ROLE|LDAP|spare1|main1|2|1|seed1|test1,test2','test1',seed)) == 'KEY_CHANGE_REFUSED','no key rotation'
call check s~writes = 0,'rejections never persist'
call check boot~offer(b) == 'ACCEPTED','higher epoch'
call check s~load == b,'persist exact envelope'
call check boot~record~main == 'spare1','publish new role'
boot=.XtpRoleBootstrap~new(s,v,logger)
call check boot~record~epoch = 2,'restart reads replacement'
call check boot~offer(a) == 'NOT_NEWER','restart rollback refused'
call check boot~offer(c) == 'ACCEPTED','same epoch higher version'
p=.TestProbe~new('main1','MAIN',2,2)
r=boot~resolve(p)
call check r[1] == 'FRESH' & r[2] == 'main1','fresh test adapter'
p=.TestProbe~new('spare1','SPARE',2,2)
r=boot~resolve(p)
call check r[1] == 'STALE' & r[2] == 'spare1','stale spare'
p=.TestProbe~new('main1','MAIN',1,1)
call check boot~resolve(p)[1] == 'UNAVAILABLE','old epoch not fresh'
call check boot~record~main == 'main1','no autonomous promotion'
call check boot~catchUp(.TestTransport~new(.nil)) == 'NO_ROLE_SOURCE','no reachable seed'
d=seal('ROLE|LDAP|spare1|main1|3|1|seed1|test1','test1',seed)
call check boot~catchUp(.TestTransport~new(d)) == 'ROLE_SOURCE','catch up via seed'
call check boot~record~epoch = 3,'catchup persisted'
s~fail=.true
call check boot~offer(seal('ROLE|LDAP|main1|spare1|4|1|seed1|test1','test1',seed)) == 'PUBLICATION_UNCERTAIN','uncertain persistence'
call check boot~quarantined,'quarantine after publication failure'
call check boot~resolve(p)[1] == 'QUARANTINED','no resolution after failure'
call check target~count >= 8,'structured log events'
call check target~events[1]~payload['KIND'] == 'BOOT_ROLE_LOADED','actual LogEvent payload'
/* Exercise real bounded file read, with no mutation of operational state. */
parse arg filePath
if filePath == '' then exit 2
f=.stream~new(filePath)
f~open('WRITE REPLACE'); f~charout(a); f~close
rf=.XtpRoleFile~new(filePath,.nil,.TestOptions~new)
call check rf~load == a,'exact file read'
bootFile=.XtpRoleBootstrap~new(rf,v,logger)
call check bootFile~record~main == 'main1','boot reads actual local file'
start=bootFile~start(.TestTransport~new(a),.TestProbe~new('main1','MAIN',1,1))
call check start['READY'] & start['STATUS'] == 'FRESH','startup test adapter ready'
start=bootFile~start(.TestTransport~new(.nil),.TestProbe~new('spare1','SPARE',1,1))
call check \start['READY'] & start['STATUS'] == 'STALE','stale startup not ready'
/* Failed signature must not start a new boot. */
call check bootReject(.TestStore~new(seal(r1,'test1','22'~copies(32))),v,logger),'invalid initial signature'
service~disable('qualification')
call check bootReject(.TestStore~new(a),v,logger),'no startup if logging unavailable'
call check bootFile~offer(b) == 'LOG_UNAVAILABLE','no update if logging unavailable'
call check bootFile~quarantined,'logging failure quarantines'
say 'SUITE PASSED'
exit 0
bootReject: procedure
  use arg store,verifier,logger
  signal on syntax name rejected
  boot=.XtpRoleBootstrap~new(store,verifier,logger)
  return .false
  rejected:
  return .true
seal: procedure
  use arg r,k,s
  return r||'0a'x||k||'0a'x||.HMACSHA512~digest(s,'XTP-ROLE-TEST/1:'r)
check: procedure
  use arg ok,label
  if \ok then do; say 'FAIL' label; exit 1; end
  say 'PASS' label
  return
::requires 'XtpRoleBootstrap.cls'
::class TestEmitter
::class TestStore
::attribute fail
::attribute writes get
::method init
  expose bytes fail writes
  use arg bytes
  fail=.false; writes=0
::method load
  expose bytes
  return bytes
::method replace
  expose bytes fail writes
  use arg newBytes
  if fail then return .false
  bytes=newBytes; writes+=1; return .true
::class TestProbe
::method init
  expose p r e v
  use arg p,r,e,v
::method confirms
  expose p r e v
  use arg peer,role,epoch,version
  return p == peer & r == role & e = epoch & v = version
::class TestTransport
::method init
  expose bytes
  use arg bytes
::method fetchRole
  expose bytes
  use arg peer
  if peer == 'seed1' then return bytes
  return .nil

::class TestOptions
::method durability
  return 'FULL'
::method noFollow
  return .true
