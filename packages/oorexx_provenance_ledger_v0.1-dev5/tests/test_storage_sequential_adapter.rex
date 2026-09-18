/* Qualification against the real Storage Fabric dev17 sequential-media contract. */
tape=.StorageTapeVolumeCodec~newVolume("ledger-tape")
call charout "real.manifest","M"; call stream "real.manifest","c","close"
call charout "real.anchor","A"; call stream "real.anchor","c","close"
call charout "real.segment","S"; call stream "real.segment","c","close"
.ProvenanceMediaAdapter~archiveToSequentialImage(tape,"real.manifest","real.anchor",.array~of("real.segment"))
if tape~dataRecordCount<>3 | tape~boundaryCount<>3 then exit 60
r=.ProvenanceMediaAdapter~readSequentialImage(tape)
if r~items<>3 | r[1]["payload"]<>"M" | r[2]["payload"]<>"A" | r[3]["payload"]<>"S" then exit 61
say "PASS Storage Fabric dev17 tape carriage adapter"
do f over .array~of("real.manifest","real.anchor","real.segment"); call sysfiledelete f; end
exit 0
::requires 'ProvenanceLedger.cls'
::requires 'StorageSequentialMedia.cls'
