parse source . . me
root=filespec('location',me)'../'
call addp root'src'; call addp value('STORAGE_SRC',,'ENVIRONMENT')

/* Canonical tape: two blocks separated by a filemark. */
t=.StorageTapeVolumeCodec~newVolume('TAPE001')
.StorageTapeVolumeCodec~addBlock(t,'ABC')
.StorageTapeVolumeCodec~filemark(t)
.StorageTapeVolumeCodec~addBlock(t,'DEFG')

aws=.WebDavAwsTapeCodec~render(t)
call assert aws~length=25,'AWS encoded length'
a=.WebDavAwsTapeCodec~parse('TAPE001-A',aws)
call sameTape t,a,'AWSTAPE round trip'

het=.WebDavHetTapeCodec~render(t)
h=.WebDavHetTapeCodec~parse('TAPE001-H',het)
call sameTape t,h,'HET uncompressed round trip'

/* >65535 is legal canonical/HET via chunks but deliberately rejected by AWS. */
big=.StorageTapeVolumeCodec~newVolume('BIG')
.StorageTapeVolumeCodec~addBlock(big,copies('X',65536))
hetBig=.WebDavHetTapeCodec~render(big)
big2=.WebDavHetTapeCodec~parse('BIG2',hetBig)
call assert big2~records[1]~data~length=65536,'HET chunk reassembly'
awsRejected=.false
signal on syntax name awsBad
x=.WebDavAwsTapeCodec~render(big)
signal off syntax
call assert .false,'oversize AWS must fail'
awsBad:
awsRejected=.true
signal off syntax
call assert awsRejected,'oversize AWS rejected'

/* Compression flag cannot be silently interpreted as plain tape data. */
compressed=.WebDavTapeHeader~make(3,0,.WebDavTapeHeader~NEWREC+.WebDavTapeHeader~ENDREC+.WebDavTapeHeader~HET_ZLIB,0)||'XYZ'
compRejected=.false
signal on syntax name compBad
x=.WebDavHetTapeCodec~parse('C',compressed)
signal off syntax
call assert .false,'compressed HET must fail without provider'
compBad:
compRejected=.true
signal off syntax
call assert compRejected,'compressed HET rejected'

/* Registry negotiates explicit tape representations; empty Accept still refuses. */
reg=.WebDavRepresentationRegistry~new
ref=.StorageRef~new('tape-obj','digest-tape')
o=.StorageObject~new(ref,'WORK01',7,'application/vnd.oorexx.storage.sequential-media')
reg~decorateStorageObject(o,t); reg~register(ref,t)
call assert reg~render(o,'')==.nil,'generic tape GET refused'
rr=reg~render(o,.WebDavTapeFormat~AWSTAPE_TYPE)
call assert rr<>.nil & rr~contentType=.WebDavTapeFormat~AWSTAPE_TYPE,'AWSTAPE negotiated'
ri=reg~import('TAPE-I',rr~body,.WebDavTapeFormat~AWSTAPE_TYPE)
call sameTape t,ri,'registry AWSTAPE import'

say 'WEBDAV TAPE CODECS: OK'
exit 0

sameTape: procedure
  use arg a,b,label
  call assert a~family=b~family,label||' family'
  call assert a~records~items=b~records~items,label||' record count'
  do i=1 to a~records~items
    call assert a~records[i]~kind=b~records[i]~kind,label||' kind '||i
    call assert a~records[i]~data==b~records[i]~data,label||' data '||i
  end
return
assert: procedure
  use arg ok,msg
  if \ok then do; say 'ASSERT FAILED:' msg; exit 1; end
return
addp: procedure
  use arg p
  if p='' then return
  cur=value('REXX_PATH',,'ENVIRONMENT')
  if cur='' then call value 'REXX_PATH',p,'ENVIRONMENT'
  else call value 'REXX_PATH',p':'cur,'ENVIRONMENT'
return

::requires 'WebDavRepresentations.cls'
::requires 'WebDavTapeCodecs.cls'
