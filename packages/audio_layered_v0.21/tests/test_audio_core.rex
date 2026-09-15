/* Layered audio, view-specific boundaries, processing lineage, through-cut tests. */
say 'AUDIO CORE SMOKE START'

audio = .AudioRecording~new('OP-HARDCASTLE-1', 300000)
rawA = audio~addRawFeed('RAW-A', 300000, 'raw-a.ogg', 'primary microphone', .directory~new)
rawB = audio~addRawFeed('RAW-B', 300000, 'raw-b.ogg', 'secondary/reference feed', .directory~new)

inputs = .array~of('RAW-A','RAW-B')
p = .directory~new
p['mode'] = 'adaptive'
p['reference'] = 'RAW-B'
cancelled = audio~addDerived('CANCELLED', 300000, 'cancelled.wav', 'dual-feed cancellation', inputs, .directory~new, 'P1', 'dual-feed adaptive cancellation', 'CANCELLATION', p, 0.93, 'processor-A', 'preserve raw feeds', 0, 300000)

inputs2 = .array~of('CANCELLED')
p2 = .directory~new
p2['highpass_hz'] = 100
p2['lowpass_hz'] = 7000
enhanced = audio~addDerived('SPEECH-ENHANCED', 300000, 'enhanced.wav', 'speech enhancement', inputs2, .directory~new, 'P2', 'speech-band enhancement', 'ENHANCEMENT', p2, 0.85, 'processor-B', '', 0, 300000)

speech = audio~createView('V-SPEECH', .AudioConstant~VIEW_SPEECH, 'candidate lexical transcription', 'human phonetic assessment', .directory~new)
speaker = audio~createView('V-SPEAKER', .AudioConstant~VIEW_SPEAKER, 'speaker assessment', 'voice comparison', .directory~new)
prosody = audio~createView('V-PROSODY', .AudioConstant~VIEW_PROSODY, 'pitch and delivery', 'F0/rhythm assessment', .directory~new)
spatial = audio~createView('V-SPATIAL', .AudioConstant~VIEW_SPATIAL, 'acoustic location within room', 'TDOA/reflection/spatial model', .directory~new)
processing = audio~createView('V-PROCESS', .AudioConstant~VIEW_PROCESSING, 'processing applicability', 'processing lineage assessment', .directory~new)

sources = .array~of('SPEECH-ENHANCED')
audio~addBoundary('V-SPEECH','B-S1',157000,159100,'UTTERANCE','I want her dead',0.82,'listener-A',sources,.directory~new,'candidate reading')
audio~addBoundary('V-SPEAKER','B-SP1',156700,159400,'SPEAKER','child',0.96,'listener-A',sources,.directory~new,'foreground child voice')
attrs = .directory~new
attrs['median_f0_hz'] = 263
audio~addBoundary('V-PROSODY','B-P1',156900,159500,'REGISTER','ordinary child register',0.90,'pitch-estimator',sources,attrs,'')
attrs2 = .directory~new
attrs2['region'] = 'near buggy / foreground'
attrs2['azimuth_deg'] = 18
audio~addBoundary('V-SPATIAL','B-L1',155000,161000,'LOCATION','foreground near microphone',0.65,'spatial-assessor',.array~of('RAW-A','RAW-B'),attrs2,'multi-feed spatial inference')
audio~addBoundary('V-PROCESS','B-X1',150000,170000,'PROCESSING','dual-feed cancellation applicable',0.88,'processor-A',.array~of('RAW-A','RAW-B','CANCELLED'),.directory~new,'P1')

call assertTrue audio~selectView('V-SPEECH'), 'select speech view'
call assertEqual 'V-SPEECH', audio~selectedView~id, 'selected view retained'

lineage = audio~lineageOf('SPEECH-ENHANCED')
call assertEqual 4, lineage~items, 'lineage includes two raw feeds, cancellation and enhancement'
call assertEqual 'SPEECH-ENHANCED', lineage[lineage~items]~id, 'lineage terminates at selected derived signal'

cut = audio~throughCut(158000,160000)
call assertEqual 5, cut~viewCount, 'through cut returns every requested view'
call assertEqual 5, cut~allElements~items, 'one intersecting element from every view'

speechCut = cut~view('V-SPEECH')~elements[1]
call assertEqual 158000, speechCut~clippedStartMs, 'left-clipped speech absolute start'
call assertEqual 159100, speechCut~clippedEndMs, 'speech natural end retained'
call assertEqual 0, speechCut~cutRelativeStartMs, 'speech begins at cut-relative zero'
call assertEqual 1100, speechCut~cutRelativeEndMs, 'speech relative end'
call assertEqual 1000, speechCut~boundaryOffsetStartMs, 'cut starts one second into original speech boundary'
call assertEqual 2100, speechCut~boundaryOffsetEndMs, 'original boundary offset end preserved'

locationCut = cut~view('V-SPATIAL')~elements[1]
call assertEqual 158000, locationCut~clippedStartMs, 'spatial boundary cut to slice start'
call assertEqual 160000, locationCut~clippedEndMs, 'spatial boundary cut to slice end'
call assertEqual 3000, locationCut~boundaryOffsetStartMs, 'spatial cut offset into independent view boundary'
call assertEqual 5000, locationCut~boundaryOffsetEndMs, 'spatial end offset into independent boundary'
call assertEqual 0.65, locationCut~confidence, 'view-specific confidence survives cut'

selectedCut = audio~selectedCut(158000,160000)
call assertEqual 1, selectedCut~viewCount, 'selected cut contains selected view only'
call assertTrue audio~canonicalText~pos('dual-feed adaptive cancellation') > 0, 'processing technique canonicalized'
call assertTrue audio~canonicalText~pos('V-SPATIAL') > 0, 'spatial view canonicalized'

say 'AUDIO CORE SMOKE: OK'
exit 0

assertEqual: procedure
  use arg expected, actual, message
  if expected \= actual then do
    say 'ASSERT EQUAL FAILED:' message 'expected='expected 'actual='actual
    exit 1
  end
  return 1

assertTrue: procedure
  use arg condition, message
  if \ condition then do
    say 'ASSERT TRUE FAILED:' message
    exit 1
  end
  return 1

::requires '../AudioCore.cls'
