ledger=.ProvenanceLedger~new("media-chain")
ref=.FakeStorageRef~new("storage://media/deck-17","sha256:canonical-deck")
img=.FakeMedia~new("deck-17","CARD_DECK","ASCII",80,42,0,"storage://source/jcl")
obs=.ProvenanceSequentialMediaAdapter~observe(ledger,"media-1","2026-09-18T01:20:00+01:00",ref,img,"MEDIA_ADMITTED","authority:storage","evidence:ingest","policy:media")
if obs~operation \== "MEDIA_ADMITTED" | obs~afterHash \== ref~digest | obs~metadataDigest=="" then exit 40
exp=.ProvenanceSequentialMediaAdapter~representationEvent(ledger,"media-2","2026-09-18T01:20:01+01:00",ref,img,"ASCII_LINES","sha256:ascii-artifact","OUT","hercules:3505","TRAILING_BLANKS_PROJECTED","authority:bridge","evidence:reader")
if exp~operation \== "MEDIA_REPRESENTATION_EXPORTED" | exp~beforeHash \== ref~digest | exp~afterHash \== ref~digest then exit 41
imp=.ProvenanceSequentialMediaAdapter~representationEvent(ledger,"media-3","2026-09-18T01:20:02+01:00",ref,img,"ASCII_PUNCH","sha256:punch-artifact","IN","hercules:3525","TRAILING_BLANKS_RECONSTRUCTED","authority:bridge","evidence:punch")
if imp~operation \== "MEDIA_REPRESENTATION_IMPORTED" then exit 42
restored=.FakeStorageRef~new("storage://media/deck-17","sha256:canonical-deck")
rt=.ProvenanceSequentialMediaAdapter~roundTripEvent(ledger,"media-4","2026-09-18T01:20:03+01:00",ref,restored,img,"ASCII_LINES/ASCII_PUNCH","sha256:edge-session","authority:bridge","evidence:roundtrip")
if rt~operation \== "MEDIA_ROUNDTRIP_VERIFIED" | rt~beforeHash \== rt~afterHash then exit 43
img2=.FakeMedia~new("tape-01","TAPE_VOLUME","BINARY",0,3,1,.nil)
tref=.FakeStorageRef~new("storage://media/tape-01","sha256:canonical-tape")
aws=.ProvenanceSequentialMediaAdapter~representationEvent(ledger,"media-5","2026-09-18T01:20:04+01:00",tref,img2,"AWSTAPE","sha256:aws-image","OUT","hercules:3420","LOSSLESS","authority:bridge")
if aws~metadataDigest==exp~metadataDigest then exit 44
say "PASS sequential-media provenance adapter"
exit 0

::class FakeStorageRef
::attribute objectId get
::attribute digest get
::method init
 expose objectId digest
 use strict arg objectId,digest
::method string
 expose objectId
 return objectId

::class FakeMedia
::attribute mediaId get
::attribute family get
::attribute encoding get
::attribute fixedRecordBytes get
::attribute sourceRef get
::attribute dataRecordCount get
::attribute boundaryCount get
::method init
 expose mediaId family encoding fixedRecordBytes dataRecordCount boundaryCount sourceRef
 use strict arg mediaId,family,encoding,fixedRecordBytes,dataRecordCount,boundaryCount,sourceRef

::requires 'ProvenanceLedger.cls'