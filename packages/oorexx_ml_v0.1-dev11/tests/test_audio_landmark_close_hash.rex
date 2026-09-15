/* 18-bit-like landmark space: temporal relation + two frequency bins, 6 bits each. */
s=.MLCloseHashSchema~new(.array~of(,
  .MLCloseHashDimension~new('dt',0,64,64,2),,
  .MLCloseHashDimension~new('f1',0,64,64,1),,
  .MLCloseHashDimension~new('f2',0,64,64,1)),'AUDIO-LANDMARK-18')
rows=.array~of(.array~of(12,20,30),.array~of(12,21,30),.array~of(12,20,31),.array~of(40,50,55))
y=.array~of('anchor','f1-neighbour','f2-neighbour','far'); ids=.array~of('A','B','C','D')
d=.MLDataset~new(rows,y,.array~of('dt','f1','f2'),'LANDMARKS',.nil,ids)
idx=.MLCloseNeighbourIndex~new; idx~fit(d,s)
exactBucket=idx~query(.array~of(12,20,30),4,0,0,'HASH','A')
call eq 0,exactBucket~size,'exact bucket alone misses adjacent landmarks after excluding self'
probe=idx~query(.array~of(12,20,30),4,1,0,'HASH','A')
call eq 2,probe~size,'one-shell probe finds adjacent-frequency landmarks'
call truth probe~at(1)~hashDistance=probe~at(2)~hashDistance,'equal one-bin frequency differences remain equally close'
far=s~difference(s~encode(.array~of(12,20,30)),s~encode(.array~of(14,20,30)))
near=s~difference(s~encode(.array~of(12,20,30)),s~encode(.array~of(12,21,30)))
call truth far~score>near~score,'more significant temporal dimension can be weighted above frequency'
say 'PASS test_audio_landmark_close_hash'
exit 0
eq: procedure; use arg a,e,l; if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end; return
truth: procedure; use arg v,l; if \v then do; say 'FAIL' l; exit 1; end; return
::requires "OorexxML.cls"
