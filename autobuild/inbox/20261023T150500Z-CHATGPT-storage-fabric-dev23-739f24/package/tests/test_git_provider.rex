parse arg repoUrl workRoot sourcePath digest targetPath branch
if branch="" then branch="storage-fabric-test"
if repoUrl="" | workRoot="" | sourcePath="" | digest="" | targetPath="" then do
  say 'FAIL git provider test arguments'
  exit 2
end

ref=.StorageRef~new('audio:test:git-provider','sha256:'||digest)
lifecycle=.StorageServiceLifecycle~new(.StorageSafetyClass~SAFE,.StorageLifecycleState~STABLE)
p=.StorageGitProvider~new('git-test',repoUrl,branch,workRoot,'TEST-VENDOR','TEST-SITE','TEST-VENDOR/TEST-SITE',lifecycle,65536)
call assertEq 'storage.fabric.git/0.1',p~api,'api'
call assertEq .StorageGitCapacityModel~ELASTIC,p~capacityModel,'elastic capacity'
call assertTrue p~canDurable,'durable capability'
call assertFalse p~canWorkspace,'not execution workspace'
call assertTrue p~supportsChunkDeduplication,'chunk dedup capability'

put=p~store(ref,sourcePath,'test-observation')
call assertTrue put~ok,'store succeeds'
call assertTrue put~location<>.nil,'location returned'
call assertTrue put~location~countsAsDurable,'verified git location counts durable'
call assertEq 'TEST-VENDOR',put~location~vendorId,'vendor metadata'
call assertEq 'TEST-SITE',put~location~siteId,'site metadata'
call assertTrue put~commitId<>"",'commit identity'
call assertTrue p~has(ref,put~commitId),'object manifest exists at commit'

reader=.StorageGitProvider~new('git-test',repoUrl,branch,workRoot||'-reader','TEST-VENDOR','TEST-SITE','TEST-VENDOR/TEST-SITE',lifecycle,65536)
mat=reader~materialiseLocation(ref,put~location,targetPath)
call assertTrue mat~ok,'materialise exact commit through fresh clone' 
call assertEq 'sha256:'||digest||';git-commit:'||put~commitId,mat~verificationRef,'materialise verification'

/* Store again. Chunks must be reused; a fresh StorageRef is not manufactured. */
put2=p~store(ref,sourcePath,'test-observation-2')
call assertTrue put2~ok,'idempotent restorage succeeds'
call assertTrue put2~chunksReused>0,'content chunks reused'
call assertEq put~manifestPath,put2~manifestPath,'stable manifest path'

say 'PASS Storage Git provider chunked durable store/materialise'
exit 0

::routine assertTrue
  use arg value,label
  if \value then do; say 'FAIL' label; raise syntax 88.900 array('test assertion failed'); end
::routine assertFalse
  use arg value,label
  if value then do; say 'FAIL' label; raise syntax 88.900 array('test assertion failed'); end
::routine assertEq
  use arg expected,actual,label
  if expected<>actual then do; say 'FAIL' label 'expected='expected 'actual='actual; raise syntax 88.900 array('test assertion failed'); end

::requires 'StorageGit.cls'
