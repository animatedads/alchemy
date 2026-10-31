.environment~put(0,'SPASH_RAW_CHECKS')
obj=.SpashRawMotionClock~new
n=obj~load('tests/fixture.samples.tsv','tests/fixture.run.tsv')
call assertTrue n==5,'five source rows admitted'
call assertTrue obj~sourceFile=='synthetic.mp4','run source identity retained'
call assertTrue abs(obj~firstMs-1560)<.001,'PTS first timestamp'
call assertTrue abs(obj~lastMs-1860)<.001,'PTS final timestamp'
point=obj~sampleAt(3)
call assertTrue point['SAMPLE_INDEX']==25,'frame index retained'
call assertTrue point['PTS']==151200,'raw unmodified PTS'
call assertTrue point['AUTHORITY']=='OBSERVED_VIDEO_PTS_MOTION_SAMPLE','raw authority unambiguous'
profile=obj~cadence
call assertTrue abs(profile['MEAN_MS']-75)<.001,'mean 75ms irregular sampling, NOT nominal 60'
call assertTrue abs(profile['MEAN_RATE_HZ']-13.3333333333)<.01,'mean rate from PTS'
call assertTrue profile['NEAR_60MS']==3,'three 60ms steps'
call assertTrue profile['NEAR_120MS']==1,'one 120ms step'
w=obj~window(1560,1860)
call assertTrue w['RAW_STEPS']==4,'four valid frame steps'
call assertTrue abs(w['COVERED_MS']-300)<.001,'exact observed time coverage'
call assertTrue abs(w['GLOBAL_TRAVEL_PX_PER_SECOND']-13.33333333)<.01,'displacement time-normalized, not sample-normalized'
call assertTrue abs(w['DOOR_TRAVEL_PX_PER_SECOND']-6.6666667)<.01,'door displacement per observed second'
call assertTrue abs(w['GLOBAL_DX_PX_PER_SECOND']-13.3333333)<.01,'direction retained'
call assertTrue abs(w['DOOR_LEFT_RESIDUAL_PX_PER_SECOND']-1.33333333)<.01,'door residual retained'
call assertTrue w['MAX_RAW_STEP_MS']==120,'actual maximum cadence preserved'
call assertTrue w['AUDIO_CLOCK_AUTHORITY']=='NOT_ALIGNED','visual timestamps not claimed audio clock'
call assertTrue w['VISUAL_EVENT_SUMMARIES']=='NOT_USED_AS_PRIMARY_DATA','events secondary'
partial=obj~window(1650,1750)
call assertTrue abs(partial['COVERED_MS']-100)<.001,'partial sample overlap follows actual PTS'
call assertTrue abs(partial['GLOBAL_TRAVEL_PX_PER_SECOND']-10.83333333)<.001,'time-weighted partial 60ms and120ms steps'
empty=obj~window(4000,5000)
call assertTrue empty['STATUS']=='NOT_APPLICABLE_NO_RAW_PTS_COVERAGE','no data fails closed'
call assertTrue .environment~at('SPASH_RAW_CHECKS')==23,'expected native suite count'
say 'SPASH RAW VISUAL PTS v0.1 PASS' .environment~at('SPASH_RAW_CHECKS') 'checks'
exit 0
::routine assertTrue
 use strict arg assertion,description
 if \assertion then do
   say 'FAIL' description
   raise syntax 88.900 array('test failed',description)
 end
 .environment~put(.environment~at('SPASH_RAW_CHECKS')+1,'SPASH_RAW_CHECKS')
 say 'PASS' description
::requires 'SpashRawMotionClock.cls'
