/* Candidate20 sequence-locality bridge qualification. */
call assertTrue .MediaAudioV9SequenceExecutionBridge~policies~hasItem('LOOKAHEAD_LOCALITY'), 'lookahead policy exposed'

storage=.directory~new; storage['REF']='storage://fixture/unit0'
memory=.directory~new; memory['REF']='memory://fabric/block0'
unit=.AudioV9SequenceUnit~new(0,storage,memory,0,1024,4096,'MI-B','MI-A')
miA=.AudioV9MiEvidence~new('MI-A',7,.true,4,8192,1,.false,1,'FD-A')
miB=.AudioV9MiEvidence~new('MI-B',3,.true,3,8192,8,.true,1,'FD-B')
candidates=.array~of(miA,miB)
horizon=.array~of(unit)
request=.MediaAudioV9SequenceExecutionBridge~planningRequest('MEDIA-JOB-1','LOOKAHEAD_LOCALITY','MI-A',unit,horizon,candidates,128,4096,'CHECKPOINTED')
call assertEqual 'NON_MUTATING_PLANNED_ADMITTANCE_ONLY',request~authority,'planning remains non-mutating'
proposal=.MediaAudioV9SequenceExecutionBridge~trialProposal(request)
call assertEqual 'PROPOSAL_ONLY_JOB_TO_NODE_LEASE_REQUIRED',proposal~authority,'proposal is not execution authority'

metrics=.AudioV9SequenceTrialMetrics~new
metrics~units=9; metrics~moves=3; metrics~memoryHits=7; metrics~memoryMisses=2
metrics~bytesMoved=22912; metrics~bytesAvoided=79488; metrics~continuationBytesMoved=12288; metrics~failovers=0
e=.MediaAudioV9SequenceExecutionBridge~qualificationEvidence('AUDIO.RECON.MULTIPATH_VIRTUAL_MIC','AUDIO_V9_CANDIDATE20','LOOKAHEAD_LOCALITY',metrics,0,0)
call assertTrue e~equivalent,'zero-error route is equivalent'
call assertEqual 'EXECUTION_STRATEGY_QUALIFICATION_ONLY',e~authorityEffect,'execution strategy does not become acoustic evidence'
call assertTrue e~sourceAuthorityUnchanged,'source authority unchanged'
call assertEqual 79488,e~bytesAvoided,'locality accounting retained'

bad=.MediaAudioV9SequenceExecutionBridge~qualificationEvidence('AUDIO.RECON.MULTIPATH_VIRTUAL_MIC','AUDIO_V9_CANDIDATE20','MOVE_TO_MEMORY',metrics,0.01,0.001)
call assertTrue \bad~equivalent,'non-equivalent reconstruction remains visible'
say 'PASS Audio V9 Candidate20 sequence execution bridge'
exit 0

assertTrue: procedure
  use strict arg condition,label
  if \condition then do
    say 'FAIL' label
    exit 1
  end
  return

assertEqual: procedure
  use strict arg expected,actual,label
  if expected<>actual then do
    say 'FAIL' label 'expected='expected 'actual='actual
    exit 1
  end
  return

::requires 'MediaAudioV9SequenceExecution.cls'
