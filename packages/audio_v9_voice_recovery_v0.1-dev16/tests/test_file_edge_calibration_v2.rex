numeric digits 30
parse source . . me
root=filespec('L',me)||filespec('P',me)||'..'
call directory root

pass=0
call t_media_extent_only
call t_correlated_spatial_one_vote
call t_independent_seam_support
call t_spatial_tdoa_separation
call t_fd_sign
call t_competing_clusters
call t_legacy_map_rejected
call t_clock_applies_measured_only
say 'PASS file-edge calibration v2 assertions='pass
exit 0

t_media_extent_only:
  obs=.array~new
  obs~append(.AudioV9FileEdgeEvidence~mediaExtent('e1','fc','20231009_210018_tp00003_original.ogg','20231009_213806_tp00004_original.ogg',8000,18143970,1,'MEDIA-FC-04'))
  s=.AudioV9FileEdgeCalibrationSolver~new~solve(obs,123)
  call ok s~mediaExtentStatus='MEASURED','extent measured'
  call ok s~status='EXTENT_ONLY','extent alone cannot measure clock'
  call ok s~cumulativeCorrectionSamples=123,'extent alone cannot advance correction'
  return

t_correlated_spatial_one_vote:
  obs=.array~new; edge=.AudioV9VoiceClock~fromSourceName('20231009_213806_tp00004_original.ogg')
  obs~append(.AudioV9FileEdgeEvidence~spatialLagJump('s1','fc','20231009_210018_tp00003_original.ogg','20231009_213806_tp00004_original.ogg',edge,102,1,'WINDOW-44','SRC-A','VOICE_A',2,.true,'ENV'))
  obs~append(.AudioV9FileEdgeEvidence~spatialLagJump('s2','fc','20231009_210018_tp00003_original.ogg','20231009_213806_tp00004_original.ogg',edge,101,1,'WINDOW-44','SRC-A','VOICE_A',1,.true,'DIRECT'))
  obs~append(.AudioV9FileEdgeEvidence~spatialLagJump('s3','fc','20231009_210018_tp00003_original.ogg','20231009_213806_tp00004_original.ogg',edge,103,1,'WINDOW-44','SRC-A','VOICE_A',3,.true,'REFINED'))
  s=.AudioV9FileEdgeCalibrationSolver~new~solve(obs,0)
  call ok s~candidateCount=1,'correlated estimators collapse to one bundle'
  call ok s~independentSupport=1,'correlated estimators count as one independent vote'
  call ok s~status='CLOCK_CANDIDATE','one bundle cannot become measured clock'
  call ok s~cumulativeCorrectionSamples=0,'candidate cannot advance clock'
  return

t_independent_seam_support:
  obs=.array~new; l='20231009_210018_tp00003_original.ogg'; r='20231009_213806_tp00004_original.ogg'; edge=.AudioV9VoiceClock~fromSourceName(r)
  /* nominal spacing 2268 s => 18,144,000 samples; extent is 40 samples short */
  obs~append(.AudioV9FileEdgeEvidence~mediaExtent('e2','fc',l,r,8000,18143960,1,'MEDIA-FC-04'))
  obs~append(.AudioV9FileEdgeEvidence~seamGap('g1','fc',l,r,edge,2,1,'SEAM-A','VOICE-A','SPEAKER_001'))
  obs~append(.AudioV9FileEdgeEvidence~seamGap('g2','fc',l,r,edge,3,1,'SEAM-B','VOICE-B','SPEAKER_002'))
  s=.AudioV9FileEdgeCalibrationSolver~new(4,8,2)~solve(obs,10)
  call ok s~mediaExtentResidualSamples=-40,'extent residual is separate E'
  call ok s~status='CLOCK_MEASURED','two independent seam sources measure clock'
  call ok s~clockStepSamples=-37 | s~clockStepSamples=-38,'C=E+G near -38'
  call ok s~seamGapStatus='GAP_MEASURED','G is separately reported as gap'
  call ok s~seamGapSamples>=2 & s~seamGapSamples<=3,'derived seam gap preserved'
  call ok s~cumulativeCorrectionSamples=10+s~clockStepSamples,'measured clock advances cumulative correction'
  return

t_spatial_tdoa_separation:
  obs=.array~new; l='20231009_210018_tp00003_original.ogg'; r='20231009_213806_tp00004_original.ogg'; edge=.AudioV9VoiceClock~fromSourceName(r)
  obs~append(.AudioV9FileEdgeEvidence~spatialLagJump('p1','fc',l,r,edge,25,1,'PATH-A','PATH-A','VOICE-A',20,.true,'REFINED'))
  obs~append(.AudioV9FileEdgeEvidence~spatialLagJump('p2','fc',l,r,edge,26,1,'PATH-B','PATH-B','VOICE-B',21,.true,'REFINED'))
  s=.AudioV9FileEdgeCalibrationSolver~new~solve(obs,0)
  call ok s~status='CLOCK_MEASURED','independent path families can measure clock when TDOA change known'
  call ok s~clockStepSamples=5,'clock removes physical TDOA change'
  call ok s~spatialSupport=2,'two spatial bundles support result'
  return

t_fd_sign:
  obs=.array~new; l='20231009_201239_tp00025_original.ogg'; r='20231009_222005_tp00000_original.ogg'; edge=.AudioV9VoiceClock~fromSourceName(r)
  /* FD positive clock step produces negative lag jump under project convention. */
  obs~append(.AudioV9FileEdgeEvidence~spatialLagJump('fd1','fd',l,r,edge,-9,1,'FD-A','FD-A','VOICE-A',-4,.true,'DIRECT'))
  obs~append(.AudioV9FileEdgeEvidence~spatialLagJump('fd2','fd',l,r,edge,-10,1,'FD-B','FD-B','VOICE-B',-5,.true,'DIRECT'))
  s=.AudioV9FileEdgeCalibrationSolver~new~solve(obs,0)
  call ok s~status='CLOCK_MEASURED','FD independent spatial candidates measured'
  call ok s~clockStepSamples=5,'FD lag convention sign handled'
  return

t_competing_clusters:
  obs=.array~new; l='20231009_210018_tp00003_original.ogg'; r='20231009_213806_tp00004_original.ogg'; edge=.AudioV9VoiceClock~fromSourceName(r)
  obs~append(.AudioV9FileEdgeEvidence~clockCandidate('c1','fc',l,r,edge,10,1,'B1','G1'))
  obs~append(.AudioV9FileEdgeEvidence~clockCandidate('c2','fc',l,r,edge,12,1,'B2','G2'))
  obs~append(.AudioV9FileEdgeEvidence~clockCandidate('c3','fc',l,r,edge,100,1,'B3','G3'))
  obs~append(.AudioV9FileEdgeEvidence~clockCandidate('c4','fc',l,r,edge,102,1,'B4','G4'))
  s=.AudioV9FileEdgeCalibrationSolver~new(4,8,2)~solve(obs,77)
  call ok s~status='CLOCK_AMBIGUOUS','two independently-supported clusters stay ambiguous'
  call ok s~cumulativeCorrectionSamples=77,'ambiguous clock never advances correction'
  return

t_legacy_map_rejected:
  caught=.false
  signal on syntax name legacy_bad
  x=.AudioV9FileEdgeCalibrationMap~fromFile('tests/fixtures/unsafe_dev4_FILE_EDGE_MAP.tsv')
  signal off syntax
  call ok .false,'legacy dev4 map must not load as dev6 authority'
  return
legacy_bad:
  signal off syntax
  caught=.true
  call ok caught,'legacy dev4 map rejected fail-closed'
  return

t_clock_applies_measured_only:
  l1='20231009_210018_tp00003_original.ogg'; l2='20231009_213806_tp00004_original.ogg'; l3='20231009_221535_tp00005_original.ogg'
  edge2=.AudioV9VoiceClock~fromSourceName(l2); edge3=.AudioV9VoiceClock~fromSourceName(l3)
  s1=.AudioV9FileEdgeCalibrationSolution~new('fc',l1,l2,edge2,0,'UNKNOWN',5,5,0,'UNKNOWN','CLOCK_MEASURED',2,2,0,0,2,0,'test')
  s2=.AudioV9FileEdgeCalibrationSolution~new('fc',l2,l3,edge3,0,'UNKNOWN',200,5,0,'UNKNOWN','CLOCK_CANDIDATE',1,1,0,0,1,0,'test')
  a=.array~of(s1,s2); m=.AudioV9FileEdgeCalibrationMap~new(a)
  c=.AudioV9CalibratedSourceClock~new('fc',.array~of(l1,l2,l3),8000,m)
  call ok c~correctionFor(l2)=5,'measured correction applied'
  call ok c~correctionFor(l3)=5,'candidate correction not applied'
  call ok c~statusFor(l3)='CLOCK_CANDIDATE','candidate status preserved'
  return

ok: procedure expose pass
  use arg condition,label
  if condition then do; pass=pass+1; return; end
  say 'FAIL 'label
  exit 1

::requires 'AudioV9FileEdgeCalibration.cls'
