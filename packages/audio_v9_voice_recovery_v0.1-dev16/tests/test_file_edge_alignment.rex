numeric digits 30
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')
if root='' then root='.'
count=0

left='20231009_210018_tp00003_original.ogg'
right='20231009_210118_tp00004_original.ogg'
third='20231009_210218_tp00005_original.ogg'
edge=.AudioV9VoiceClock~fromSourceName(right)
obs=.array~new
obs~append(.AudioV9FileEdgeObservation~fromLagChange('MOV-1','fc',left,right,edge,'MOVEMENT',80,77,12,12,1,'VOICE_FAMILY_7'))
obs~append(.AudioV9FileEdgeObservation~new('HASH-1','fc',left,right,edge,'TEMPORAL_HASH',-3,1,'VOICE_FAMILY_7',12,12))
obs~append(.AudioV9FileEdgeObservation~new('ENV-1','fc',left,right,edge,'ENVELOPE',-4,.8,'VOICE_FAMILY_7',11,12))
obs~append(.AudioV9FileEdgeObservation~new('BAD-1','fc',left,right,edge,'RECURRENCE',40,.2,'UNLABELLED',120,120))
solver=.AudioV9FileEdgeAlignmentSolver~new(1.0,2,1000,8)
solution=solver~solve(obs,10)
call ok solution~resolved,'robust edge solution resolves'
call eq solution~boundaryStepSamples,-3,'edge step kept at sample precision'
call eq solution~cumulativeCorrectionSamples,7,'edge step adds to prior camera correction'
call ok solution~excludedCount>=1,'outlying recurrence can be set aside diagnostically'
call ok solution~tdoaBeforeSamples<20,'physical TDOA retained separately from clock step'

map=.AudioV9FileEdgeMap~new(.array~of(solution))
names=.array~of(left,right,third)
clock=.AudioV9PiecewiseSourceClock~new('fc',names,8000,map)
call eq clock~correctionFor(left),0,'first source is anchor'
call eq clock~correctionFor(right),-3,'measured edge changes right source start'
call eq clock~correctionFor(third),-3,'unmeasured next edge carries prior only as prediction'
call eq clock~statusFor(right),'MEASURED','measured edge status retained'
call eq clock~statusFor(third),'PREDICTED','missing edge is explicit prediction'
start=.AudioV9VoiceClock~parse('2023-10-09 21:00:48')
finish=.AudioV9VoiceClock~parse('2023-10-09 21:01:48')
slices=clock~slices(start,finish)
call eq slices~items,2,'sample interval crosses corrected file edge'
call eq slices[1]~expectedSamples,239997,'left slice ends at corrected edge without zero padding'
call eq slices[2]~expectedSamples,240003,'right slice supplies samples moved across nominal edge'
call eq slices[2]~offsetSamples,0,'right file begins at its acoustically corrected edge'
call eq slices[1]~expectedSamples+slices[2]~expectedSamples,480000,'corrected slices preserve exact requested sample geometry'

fdobs=.AudioV9FileEdgeObservation~fromLagChange('FD-1','fd',left,right,edge,'MOVEMENT',20,25,3,3,1,'VOICE')
call eq fdobs~boundaryStepSamples,-5,'FD edge uses opposite cross-feed lag sign'

geom=.AudioV9FileEdgeObservation~fromDecodedLength('GEOM-1','fc',left,right,8000,479997,1)
call eq geom~boundaryStepSamples,-3,'decoded file length predicts sample-exact next-file edge step'
call eq geom~estimator,'DECODED_LENGTH','decoded-length evidence retains estimator provenance'

amb=.array~new
amb~append(.AudioV9FileEdgeObservation~new('A1','fc',left,right,edge,'MOVEMENT',-20,1))
amb~append(.AudioV9FileEdgeObservation~new('A2','fc',left,right,edge,'HASH',-20,1))
amb~append(.AudioV9FileEdgeObservation~new('B1','fc',left,right,edge,'MOVEMENT',20,1))
amb~append(.AudioV9FileEdgeObservation~new('B2','fc',left,right,edge,'HASH',20,1))
ambsol=.AudioV9FileEdgeAlignmentSolver~new(0,2,1000,8)~solve(amb,9)
call ok ambsol~ambiguous,'competing equally supported edge shifts remain ambiguous'
call ok \ambsol~resolved,'ambiguous edge is not semantic clock authority'
ambmap=.AudioV9FileEdgeMap~new(.array~of(ambsol))
ambclock=.AudioV9PiecewiseSourceClock~new('fc',names,8000,ambmap)
call eq ambclock~correctionFor(right),0,'ambiguous edge does not alter clock map'
call eq ambclock~statusFor(right),'PREDICTED','ambiguous edge carries prior as explicit prediction'

say 'PASS test_file_edge_alignment assertions='||count
exit 0

ok: procedure expose count
  parse arg actual,label
  count=count+1
  if \actual then do; say 'FAIL 'label; exit 1; end
return

eq: procedure expose count
  parse arg actual,expected,label
  count=count+1
  if actual\==expected then do; say 'FAIL 'label' expected='expected' actual='actual; exit 1; end
return

::requires 'AudioV9FileEdgeAlignment.cls'
