/* Qualification of DSFS-like Storage Fabric personality and AWS round trip. */
cat=.StorageCatalogue~new
env=.StorageEnvironment~new('MVS-LIVE',.StorageEnvironmentKind~LIVE,'',0,1,.StorageWritePolicy~DIRECT)
ns=.StorageNamespace~new('ED209Z-USS',cat,env)
store=.MasMemoryStorageFabricStore~new(ns,cat,.StorageWritePolicy~DIRECT)
svc=.MasStorageFabricDsfsService~new(store)

h=svc~open('/u/USER/sample.txt','OWRONLY OCREAT OTRUNC','TEXT')
call assertEqual 12,h~write('HELLO WORLD'||'0a'x),'write length'
r1=h~close
call assertTrue r1<>.nil,'first ref exists'
call assertEqual 'HELLO WORLD'||'0a'x,svc~open('/u/USER/sample.txt','ORDONLY','TEXT')~readAll,'read back'

h2=svc~open('/u/USER/sample.txt','ORDWR OAPPEND','TEXT')
call assertEqual 7,h2~append('SECOND'||'0a'x),'append length'
r2=h2~close
call assertTrue r2~objectId<>r1~objectId,'write creates new StorageRef'
call assertEqual r2~objectId,store~resolve('/u/USER/sample.txt')~objectId,'namespace advanced to new ref'
call assertEqual 2,cat~count,'old and new objects retained'

records=.array~of('FIRST REC','SECOND REC')
rbytes=.MasRecordStream~encode(records)
rh=svc~open('/u/USER/records.bin','OWRONLY OCREAT OTRUNC','RECORD')
ignore=rh~write(rbytes); rr=rh~close
call assertEqual 2,.MasRecordStream~decode(store~read(rr))~items,'record stream roundtrip'

projector=.MasDirectoryTapeProjector~new(svc)
tape=projector~project('/u/USER','TEXT')
call assertEqual 2,tape~files~items,'directory projects two files'

target='/mnt/data/mas_dsfs_qualification.aws'
writer=.MasAwsTapeWriter~new
ignore=writer~write(tape,target)
size=stream(target,'c','query size')
call assertTrue datatype(size,'N') & size>20,'AWS tape created'
call stream target,'c','open read'
hdr=charin(target,,6)
call stream target,'c','close'
call assertTrue hdr~length=6,'AWS first header present'
call assertTrue c2d(reverse(substr(hdr,1,2)))>0,'AWS first block length nonzero'

say 'PASS DSFS_STORAGE_FABRIC_ROUNDTRIP'
say 'REF1='r1~objectId
say 'REF2='r2~objectId
say 'CATALOGUE_OBJECTS='cat~count
say 'TAPE_FILES='tape~files~items
say 'AWS_BYTES='size
exit 0

assertEqual: procedure
  use strict arg expected,actual,label
  if expected<>actual then do
    say 'FAIL' label 'expected='expected 'actual='actual
    exit 2
  end
  return
assertTrue: procedure
  use strict arg condition,label
  if \condition then do; say 'FAIL' label; exit 2; end
  return

::requires '../src/MasStorageFabricDsfs.cls'
