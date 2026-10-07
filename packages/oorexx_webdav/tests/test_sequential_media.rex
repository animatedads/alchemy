cat=.StorageCatalogue~new
env=.StorageEnvironment~new('DAVMEDIA',.StorageEnvironmentKind~LIVE,'',0,0,.StorageWritePolicy~DIRECT)
ns=.StorageNamespace~new('DAV',cat,env)
ad=.WebDavStorageAdapter~new(ns)
call must ad~makeCollection('/mvs')~ok,'MKCOL /mvs'

deck=.StorageCardDeckCodec~newDeck('fred001',.StorageSequentialMediaEncoding~ASCII,80)
.StorageCardDeckCodec~addTextCard(deck,'//FRED001 JOB')
.StorageCardDeckCodec~addTextCard(deck,'//STEP1 EXEC PGM=IEFBR14')
r=ad~putSequentialMedia('/mvs/input.deck',deck,'application/vnd.oorexx.storage.card-deck')
call must r~ok,'put canonical deck'
o=ad~objectAt('/mvs/input.deck')
call eq o~eaValue('storage.media.family',''),.StorageSequentialMediaFamily~CARD_DECK,'family EA'
call eq o~eaValue('storage.media.records',''),2,'record EA'
rr=ad~getRepresentation('/mvs/input.deck','text/plain')
call must rr<>.nil,'ascii representation'
call must rr~body~pos('//FRED001 JOB')>0,'deck text rendered'
call eq deck~records[1]~data~length,80,'canonical card remains 80 columns'

listing=.StoragePaperListingCodec~newListing('listing1')
.StoragePaperListingCodec~addLine(listing,'PAGE ONE')
.StoragePaperListingCodec~pageBreak(listing)
.StoragePaperListingCodec~addLine(listing,'PAGE TWO')
r=ad~putSequentialMedia('/mvs/listing',listing,'application/vnd.oorexx.storage.paper-listing')
call must r~ok,'put canonical listing'
rr=ad~getRepresentation('/mvs/listing','text/plain')
call must rr~body~pos('0C'x)>0,'page break survives projection'

tape=.StorageTapeVolumeCodec~newVolume('work01')
.StorageTapeVolumeCodec~addBlock(tape,'AAA')
.StorageTapeVolumeCodec~filemark(tape)
.StorageTapeVolumeCodec~addBlock(tape,'BBB')
r=ad~putSequentialMedia('/mvs/work01',tape,'application/vnd.oorexx.storage.tape-volume')
call must r~ok,'put canonical tape'
call must ad~getRepresentation('/mvs/work01','application/octet-stream')==.nil,'tape flatten fails closed'
call eq tape~boundaryCount,1,'filemark remains canonical'

say 'WEBDAV SEQUENTIAL MEDIA: OK'
exit 0
must: procedure
  use arg condition,label
  if \condition then do; say 'FAIL:' label; exit 1; end
  return
eq: procedure
  use arg actual,expected,label
  if actual<>expected then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return
::requires 'WebDavCore.cls'
