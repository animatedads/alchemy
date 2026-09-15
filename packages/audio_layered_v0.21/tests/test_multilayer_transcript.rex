/* Multi-layer transcript / noisy-coach / railway-station scenario. */
say 'MULTILAYER TRANSCRIPT START'

audio = .AudioRecording~new('STATION-1', 120000)
audio~addRawFeed('MIC-A',120000,'a.wav','left feed',.directory~new)
audio~addRawFeed('MIC-B',120000,'b.wav','right feed',.directory~new)

/* Source groups are hypotheses, not asserted identities. */
gA = audio~createSourceGroup('G-NEAR','near conversational group',.array~of('speaker-a','speaker-b'),'near left / foreground',0.78,'analyst',.directory~new)
gB = audio~createSourceGroup('G-PA','public-address / distant group',.array~of('pa-speaker'),'far / overhead',0.91,'analyst',.directory~new)
gC = audio~createSourceGroup('G-UNKNOWN','overlapping third group',.array~new,'mid-right uncertain',0.42,'analyst',.directory~new)

/* Two competing transcript views for the same near group. */
t1 = audio~createTranscriptView('T-NEAR-A','near group lexical hypothesis A','beamformed feed + human listen','G-NEAR','H-NEAR-17',1,'listen to foreground conversational cluster',.directory~new)
t2 = audio~createTranscriptView('T-NEAR-B','near group lexical hypothesis B','alternate separation + human listen','G-NEAR','H-NEAR-17',2,'listen to same foreground cluster via alternate separation',.directory~new)
/* Parallel transcript for a different group. */
t3 = audio~createTranscriptView('T-PA','public address transcript','far-field emphasis','G-PA','H-PA-4',1,'listen to overhead/distant announcement',.directory~new)

src=.array~of('MIC-A','MIC-B')
audio~addTranscriptBoundary('T-NEAR-A','TA1',10000,14000,'meet me by platform four',0.66,'listener-1',src,'G-NEAR','LEX-9',.directory~new,'foreground candidate')
audio~addTranscriptBoundary('T-NEAR-B','TB1',10000,14000,'meet me at platform four',0.54,'listener-2',src,'G-NEAR','LEX-9',.directory~new,'alternate lexical candidate')
audio~addTranscriptBoundary('T-PA','TP1',12000,18000,'the next service...',0.88,'listener-1',src,'G-PA','',.directory~new,'parallel distant source')

call assertEqual 'G-NEAR', audio~view('T-NEAR-A')~sourceGroupId, 'transcript view retains source group'
call assertEqual 'H-NEAR-17', audio~view('T-NEAR-B')~hypothesisSetId, 'competing view shares hypothesis set'
call assertEqual 2, audio~view('T-NEAR-B')~alternativeRank, 'alternate transcript rank retained'

cut = audio~throughCut(13000,15000,.array~of('T-NEAR-A','T-NEAR-B','T-PA'))
call assertEqual 3, cut~viewCount, 'through cut contains all three transcript layers'
call assertEqual 3, cut~allElements~items, 'one clipped transcript from each layer'
call assertEqual 13000, cut~view('T-PA')~elements[1]~clippedStartMs, 'parallel PA transcript clipped independently'
call assertEqual 15000, cut~view('T-PA')~elements[1]~clippedEndMs, 'parallel PA transcript crosses cut end'
call assertEqual 'meet me by platform four', cut~view('T-NEAR-A')~elements[1]~label, 'candidate A retained'
call assertEqual 'meet me at platform four', cut~view('T-NEAR-B')~elements[1]~label, 'candidate B retained'
call assertTrue audio~canonicalText~pos('SOURCE_GROUP=G-NEAR') > 0, 'source-group hypothesis canonicalized'
call assertTrue audio~canonicalText~pos('hypothesisSet=H-NEAR-17') > 0, 'competing transcript relationship canonicalized'

say 'MULTILAYER TRANSCRIPT: OK'
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
