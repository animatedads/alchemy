say 'AUDIO SCENE ALIGNMENT START'
meta=.Directory~new
ra=.AudioRecording~new('CAM-3605',119940)
rb=.AudioRecording~new('CAM-3603',119940)
ra~addRawFeed('AUDIO-A',119940,'1000053605.mp4','camera A audio',meta)
rb~addRawFeed('AUDIO-B',119940,'1000053603.mp4','camera B audio',meta)
va=ra~createTranscriptView('TA','camera A transcript','fixture')
vb=rb~createTranscriptView('TB','camera B transcript','fixture')
ra~addTranscriptBoundary('TA','EA',22000,23000,'same acoustic event',.8,'fixture',.Array~of('AUDIO-A'),'','',.Directory~new,'')
-- B local 16680 maps to scene 22000 when offset is +5320 ms.
rb~addTranscriptBoundary('TB','EB',16680,17680,'same acoustic event',.8,'fixture',.Array~of('AUDIO-B'),'','',.Directory~new,'')

scene=.AudioScene~new('MOUNT-PAIR','opposite-facing cameras on one mount')
scene~addRecording(ra,'MOUNT-1','CAMERA-A','FORWARD')
scene~addRecording(rb,'MOUNT-1','CAMERA-B','REVERSE')
scene~createTimeMap('MAP-A','CAM-3605',0,0,1,.9,'reference timeline')
scene~createTimeMap('MAP-B','CAM-3603',0,5320,1,.65,'speech-band RMS envelope cross-correlation')
ev=.AudioSceneAlignmentEvidence~new('ALIGN-1','CAM-3605','CAM-3603',0,119808,0,119808,5320,.556,'speech-band RMS envelope cross-correlation',.65)
scene~addAlignmentEvidence(ev)

call eq 5320,scene~timeMap('CAM-3603')~localToScene(0),'B scene offset'
call eq 14680,scene~timeMap('CAM-3603')~sceneToLocal(20000),'scene->B local'
cut=scene~throughCut(20000,24000)
call eq 2,cut~memberCount,'both recordings in scene cut'
a=cut~member('CAM-3605'); b=cut~member('CAM-3603')
call eq 20000,a~clippedLocalStartMs,'A local start'
call eq 14680,b~clippedLocalStartMs,'B local start'
call eq 24000,a~clippedLocalEndMs,'A local end'
call eq 18680,b~clippedLocalEndMs,'B local end'
call eq 1,a~localCut~view('TA')~elementCount,'A event cut'
call eq 1,b~localCut~view('TB')~elementCount,'B event cut'
call eq 0,scene~timeMap('CAM-3605')~driftPpm,'reference drift'
call eq 0,scene~timeMap('CAM-3603')~driftPpm,'B drift currently unasserted/zero'
call eq 1,scene~alignmentEvidence~items,'alignment evidence retained'
say 'AUDIO SCENE ALIGNMENT: OK'
exit 0

eq: procedure
 use strict arg expected,actual,label
 if expected \= actual then raise syntax 88.900 array('FAILED '||label||' expected='||expected||' actual='||actual)
 return

::requires '../AudioScene.cls'
