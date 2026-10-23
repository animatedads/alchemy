cat=.StorageCatalogue~new
env=.StorageEnvironment~new('STREAM5',.StorageEnvironmentKind~LIVE,'',0,0,.StorageWritePolicy~DIRECT)
ns=.StorageNamespace~new('STREAM5',cat,env)
ad=.WebDavStorageAdapter~new(ns,.WebDavMemoryContentStore~new)
call must ad~makeCollection('/data')~ok,'mkcol'

stage='/tmp/webdav-dev5-stage-'||time('S')||'.bin'
address system 'rm -f' stage
factory=.WebDavStreamingIngressFactory~new(ad,65536)
session=factory~localFileSession('/data/upload.bin',stage,131072,'application/octet-stream')
session~begin
call eq session~nextMaximum,65536,'first backpressure bound'
call must session~acceptChunk(copies('A',65536)),'first chunk'
call eq session~receivedBytes,65536,'first byte count'
call must \ad~exists('/data/upload.bin'),'no publication before commit'
call must session~acceptChunk(copies('B',65536)),'second chunk'
call eq session~nextMaximum,0,'complete input has no next chunk'
outcome=session~commit
call must outcome~ok,'commit succeeds'
call must ad~exists('/data/upload.bin'),'published after commit'
call must left(outcome~ref~digest,7)='sha256:','SHA-256 identity'
call eq ad~readRange('/data/upload.bin',65520,32,1024),copies('A',16)||copies('B',16),'committed bytes preserved'

stage2='/tmp/webdav-dev5-abort-'||time('S')||'.bin'
address system 'rm -f' stage2
s2=factory~localFileSession('/data/aborted.bin',stage2,100000,'application/octet-stream')
s2~begin
call must s2~acceptChunk(copies('X',12345)),'partial chunk accepted'
call must \ad~exists('/data/aborted.bin'),'partial upload not published'
call must s2~abort,'abort cleanup complete'
call must \ad~exists('/data/aborted.bin'),'aborted upload never published'
call eq stream(stage2,'c','query exists'),'','staging file deleted'

stage3='/tmp/webdav-dev5-incomplete-'||time('S')||'.bin'
address system 'rm -f' stage3
s3=factory~localFileSession('/data/incomplete.bin',stage3,100,'application/octet-stream')
s3~begin
call must s3~acceptChunk(copies('Y',50)),'incomplete received'
o3=s3~commit
call must \o3~ok,'incomplete commit rejected'
call eq o3~code,'INCOMPLETE_UPLOAD','incomplete code'
call must \ad~exists('/data/incomplete.bin'),'incomplete upload not published'
call must s3~abort,'cleanup incomplete stage'

say 'WEBDAV DEV5 STAGED STREAMING PUBLICATION: OK'
exit 0
must: procedure
  use arg c,l
  if \c then do; say 'FAIL:' l; exit 1; end
  return
eq: procedure
  use arg a,e,l
  if a<>e then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'WebDavStreaming.cls'
