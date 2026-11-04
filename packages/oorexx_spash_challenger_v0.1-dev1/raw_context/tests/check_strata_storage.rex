/* Unit Storage Fabric API stub; NEVER a production durability test. */
strata=.SpashRawVisualStrata~new~select('tests/stream_GOOD.windows.tsv',1000,20)
call chk strata~items==1,'only stable 1000ms raw door window selected'
call chk strata[1]['START_MS']==0,'selection ranked by original PTS'
call chk strata[1]['AUDIO_CLOCK']=='NOT_ALIGNED','no acoustic time inferred'
cat=.StorageCatalogue~new
origin=.StorageRef~new('original:TP8',copies('a',64))
view=.StorageRef~new('derived:TP8:PTS',copies('b',64))
cat~put(.StorageObject~new(origin,'original',10000,'video/mp4'))
layer=.SpashRawVisualStorage~new~registerView(cat,origin,view,1000,'SPASH_PTS_STREAM_250_500_1000_2000')
call chk layer~eas~get('spash.origin_ref')~value=='original:TP8','catalogue original preserved'
call chk layer~eas~get('spash.persistence')~value=='CATALOGUE_ONLY_NOT_DURABLE','no false durable claim'
call chk layer~eas~get('spash.clock')~value=='SOURCE_VIDEO_PTS_TIMEBASE_AUDIO_UNALIGNED','Storage Fabric keeps clock authority'
say 'SPASH_STORAGE_AND_STRATA_TEST_PASS'
exit 0
::routine chk
 use strict arg assertion,label
 if \assertion then do;say 'FAIL' label;exit 1;end
::requires 'SpashRawVisualStorage.cls'
::requires 'SpashRawVisualStrata.cls'