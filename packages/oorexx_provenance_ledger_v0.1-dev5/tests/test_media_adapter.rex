/* No Storage Fabric ::requires here: prove the ledger side remains duck typed. */
img=.FakeTape~new
call charout "media.manifest","PROVENANCE-ARCHIVE|TEST"; call stream "media.manifest","c","close"
call charout "media.anchor","PROVENANCE-ANCHOR|TEST"; call stream "media.anchor","c","close"
call charout "media.segment","PROVENANCE-SEGMENT|TEST"; call stream "media.segment","c","close"
.ProvenanceMediaAdapter~archiveToSequentialImage(img,"media.manifest","media.anchor",.array~of("media.segment"))
if img~records~items<>6 then exit 50
r=.ProvenanceMediaAdapter~readSequentialImage(img)
if r~items<>3 then exit 51
if r[1]["kind"]<>"MANIFEST" | r[2]["kind"]<>"ANCHOR" | r[3]["kind"]<>"SEGMENT" then exit 52
x=.ProvenanceMediaAdapter~extractSequentialImage(img,"media.out")
if .ProvenanceMediaAdapter~fileBytes(x["manifest"])<>"PROVENANCE-ARCHIVE|TEST" then exit 53
if .ProvenanceMediaAdapter~fileBytes(x["anchor"])<>"PROVENANCE-ANCHOR|TEST" then exit 54
if .ProvenanceMediaAdapter~fileBytes(x["segments"][1])<>"PROVENANCE-SEGMENT|TEST" then exit 55
say "PASS media-neutral archive carriage"
do f over .array~of("media.manifest","media.anchor","media.segment","media.out.manifest","media.out.anchor","media.out.segment.1"); call sysfiledelete f; end
exit 0
::class FakeRecord
::attribute kind get
::attribute data get
::method init; expose kind data; use arg kind,data=""
::class FakeTape
::attribute records get
::method init; expose records; records=.array~new
::method addData; expose records; use arg data; records~append(.FakeRecord~new("DATA",data)); return self
::method addFilemark; expose records; records~append(.FakeRecord~new("FILEMARK")); return self
::requires 'ProvenanceLedger.cls'
