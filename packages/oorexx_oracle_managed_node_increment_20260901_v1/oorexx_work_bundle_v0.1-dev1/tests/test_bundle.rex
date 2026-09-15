root=directory()||"/fixtures"
digest=.WorkBundleCryptoSHA256Digest~new
proof=.FakeProof~new("test-key")
builder=.WorkBundleBuilder~new(digest,proof)
files=.array~of("task.rex","data.txt")
entries=.array~of("task.rex")
kinds=.array~of("TEST")
runtimes=.array~of("OOREXX")
b=builder~seal(root,"BUNDLE-1","BUILD-SERVICE","KEY-1",files,entries,kinds,runtimes,"ssc:COMPONENT@7",100,10000)
v=.WorkBundleVerifier~new(digest,proof)
call assertCode v~verify(b,200),"OK","valid bundle"
call assertTrue b~manifest~hasEntrypoint("task.rex"),"entrypoint declared"
call assertTrue b~manifest~permitsKind("test"),"kind permitted"
call assertTrue \b~manifest~permitsKind("SERVICE"),"service not permitted"
repo=.InMemoryWorkBundleRepository~new
ref=repo~put(b)
call assertTrue repo~fetch(ref)\==.nil,"repository retrieval"
/* Tamper after sealing: content digest must fail. */
s=.stream~new(root||"/data.txt"); s~open("WRITE REPLACE"); s~lineOut("tampered"); s~close
call assertCode v~verify(b,200),"BUNDLE_FILE_DIGEST_MISMATCH","tamper detected"
/* restore fixture for clean reruns */
s=.stream~new(root||"/data.txt"); s~open("WRITE REPLACE"); s~lineOut("payload"); s~close
call assertCode v~verify(b,10000),"BUNDLE_EXPIRED","expiry enforced"
say "PASS Work Bundle v0.1-dev1 sealing, proof, tamper and expiry"
exit 0

assertTrue: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
assertCode: procedure
  use arg result,expected,label
  if result~code<>expected then do; say "FAIL" label "expected="expected "got="result~code result~detail; exit 1; end
  return

::class FakeProof public
::method init
  expose key
  use strict arg keyArg
  key=keyArg~string
::method sign
  expose key
  use strict arg producerId,keyId,canonical
  return .SHA256~new(key||"|"||producerId||"|"||keyId||"|"||canonical)~digest
::method verify
  use strict arg producerId,keyId,canonical,signature
  return signature=self~sign(producerId,keyId,canonical)

::requires "../src/WorkBundle.cls"
