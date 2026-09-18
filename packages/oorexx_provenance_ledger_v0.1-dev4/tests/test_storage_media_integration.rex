ledger=.ProvenanceLedger~new("storage-media-integration")
ref=.StorageRef~new("storage://media/tape/int-01","sha256:canonical-tape-int")
tape=.StorageTapeVolumeCodec~newVolume("int-01","BINARY",ref)
.StorageTapeVolumeCodec~addBlock(tape,"ABC")
.StorageTapeVolumeCodec~filemark(tape)
.StorageTapeVolumeCodec~addBlock(tape,"DEF")
tx=.ProvenanceSequentialMediaAdapter~observe(ledger,"int-1","2026-09-18T01:25:00+01:00",ref,tape,"MEDIA_ADMITTED","authority:storage")
if tx~objectRef \== ref~objectId | tx~afterHash \== ref~digest then exit 50
aws=.ProvenanceSequentialMediaAdapter~representationEvent(ledger,"int-2","2026-09-18T01:25:01+01:00",ref,tape,"AWSTAPE","sha256:aws-int","OUT","hercules:3420","LOSSLESS","authority:hercules")
if aws~operation \== "MEDIA_REPRESENTATION_EXPORTED" then exit 51
if tape~dataRecordCount \== 2 | tape~boundaryCount \== 1 then exit 52
say "PASS real Storage Fabric sequential-media provenance integration"
exit 0
::requires 'ProvenanceLedger.cls'
::requires 'StorageFabric.cls'
::requires 'StorageSequentialMedia.cls'