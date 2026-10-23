/* Cards: strict 80-column canonical records and reversible fixed-byte form. */
deck=.StorageCardDeckCodec~newDeck('JCL-IN','ASCII',80)
x=.StorageCardDeckCodec~addTextCard(deck,'//HELLO JOB CLASS=A')
x=.StorageCardDeckCodec~addTextCard(deck,'//STEP1 EXEC PGM=IEFBR14')
call assertEq 2,deck~dataRecordCount,'two cards admitted'
call assertEq 80,deck~records[1]~sizeBytes,'card padded to 80 columns'
raw=.StorageCardDeckCodec~toFixedBytes(deck)
call assertEq 160,raw~length,'fixed deck export is exact width'
round=.StorageCardDeckCodec~fromFixedBytes('JCL-ROUND',raw,80,'ASCII')
call assertEq raw,.StorageCardDeckCodec~toFixedBytes(round),'fixed deck round trip exact'

failed=.false
signal on syntax name LongCardFailed
x=.StorageCardDeckCodec~addTextCard(deck,copies('X',81))
signal off syntax
signal ContinueLong
LongCardFailed:
  failed=.true
  signal off syntax
ContinueLong:
call assertTrue failed,'over-width card fails closed'

/* Paper: page boundaries remain semantic, not guessed from lines. */
listing=.StoragePaperListingCodec~newListing('JES-PRINT')
x=.StoragePaperListingCodec~addLine(listing,'PAGE 1')
x=.StoragePaperListingCodec~pageBreak(listing)
x=.StoragePaperListingCodec~addLine(listing,'PAGE 2')
call assertEq 2,listing~dataRecordCount,'two printed lines'
call assertEq 1,listing~boundaryCount,'one explicit page boundary'
text=.StoragePaperListingCodec~toAscii(listing)
call assertTrue text~pos('0C'x)>0,'form feed rendered at adapter edge'

/* Tape: variable blocks and filemarks survive as first-class records. */
tape=.StorageTapeVolumeCodec~newVolume('VOL001','EBCDIC')
x=.StorageTapeVolumeCodec~addBlock(tape,'BLOCK-ONE')
x=.StorageTapeVolumeCodec~filemark(tape)
x=.StorageTapeVolumeCodec~addBlock(tape,'BLOCK-TWO-LONGER')
call assertEq 2,tape~dataRecordCount,'two tape blocks'
call assertEq 1,tape~boundaryCount,'filemark retained'
call assertEq .StorageSequentialMediaRecordKind~FILEMARK,tape~records[2]~kind,'filemark ordering retained'

/* Device binding is declared but emulator semantics stay outside Storage. */
plan=.StorageSequentialMediaAdapterPlan~new('hercules','CARD_READER','ASCII_LINES','IN',deck,'000C')
call assertEq 'HERCULES',plan~provider~upper,'adapter provider declared'
call assertEq 'CARD_READER',plan~deviceFamily,'reader family declared'
call assertEq 'IN',plan~direction,'reader direction declared'

say 'PASS sequential cards/paper/tape media contract'
exit 0

::routine assertTrue
  use arg v,l
  if \v then do; say 'FAIL' l; raise syntax 88.900 array('test assertion failed'); end
::routine assertEq
  use arg e,a,l
  if e<>a then do; say 'FAIL' l 'expected='e 'actual='a; raise syntax 88.900 array('test assertion failed'); end

::requires "src/StorageFabric.cls"
::requires "src/StorageSequentialMedia.cls"
