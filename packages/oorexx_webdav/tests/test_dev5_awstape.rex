repo=.WebDavSequentialMediaRepository~new
reg=.WebDavRepresentationRegistry~new(repo)

tape=.StorageTapeVolumeCodec~newVolume('TAPE5','BINARY')
.StorageTapeVolumeCodec~addBlock(tape,'ABC')
.StorageTapeVolumeCodec~addBlock(tape,copies('X',70000))
.StorageTapeVolumeCodec~filemark(tape)
.StorageTapeVolumeCodec~addBlock(tape,'TAIL')

ref=.StorageRef~new('tape-1','digest')
obj=.StorageObject~new(ref,'tape.aws',70007,'application/vnd.oorexx.storage.sequential-media')
reg~decorateStorageObject(obj,tape)
reg~register(ref,tape)

rr=reg~render(obj,'application/vnd.oorexx.awstape')
call must rr<>.nil,'AWSTAPE render available'
call eq rr~contentType,'application/vnd.oorexx.awstape','AWSTAPE MIME'
call must rr~body~length>70000,'segmented AWSTAPE rendered'

round=reg~import('ROUND',rr~body,'application/vnd.oorexx.awstape')
call eq round~records~items,tape~records~items,'record count'
call eq round~records[1]~data,'ABC','first block'
call eq round~records[2]~data~length,70000,'large segmented block'
call eq round~records[3]~kind,.StorageSequentialMediaRecordKind~FILEMARK,'filemark preserved'
call eq round~records[4]~data,'TAIL','tail block'

bad=left(rr~body,rr~body~length-1)
signal on syntax name badTape
x=reg~import('BAD',bad,'application/vnd.oorexx.awstape')
say 'FAIL: truncated AWSTAPE accepted'
exit 1
badTape:
signal off syntax

call must reg~import('HET','garbage','application/vnd.oorexx.het')==.nil,'HET import remains unsupported'
call must reg~render(obj,'application/vnd.oorexx.het')==.nil,'HET render remains unsupported'

say 'WEBDAV DEV5 AWSTAPE FIDELITY: OK'
exit 0
must: procedure; use arg c,l; if \c then do; say 'FAIL:' l; exit 1; end; return
eq: procedure; use arg a,e,l; if a<>e then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'WebDavRepresentations.cls'
