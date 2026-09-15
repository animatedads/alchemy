t=.array~of(0,1,2,4,7,8,11,15)
a=.MLTemporalPatternSeries~scalar(t,.array~of(0,1,3,7,10,7,3,1),'A')
b=.MLTemporalPatternSeries~scalar(t,.array~of(0,1,3,6,9,7,3,1),'B')
c=.MLTemporalPatternSeries~scalar(t,.array~of(0,5,9,4,8,10,2,1),'C')
p=.MLTemporalPatternPolicy~new(24,32,32,72,36,36,1,8,4,8,10,.true,.true,1)
schema=.MLCylindricalTemporalPatternSchema~new(p,'INDEX')
idx=.MLTemporalPatternIndex~new('TPI')
root=idx~journalPoint
corpus=.MLTemporalPatternCorpus~new(.array~of(a,b,c),.array~of('a','b','c'),.array~of('A','B','C'),'CORPUS')
fit=idx~fit(corpus,schema); q=idx~query(a,2,'A')
call assert q~size=2,'query should return requested neighbours'
call assert q~at(1)~sampleId='B','near pattern should rank before changed topology'
old=idx~journalPoint
ignored=idx~rollback(root,'FITTED-FUTURE')
call assert \idx~at('fitted'),'rollback should restore unfitted temporal index'
ignored=idx~rollForward('FITTED-FUTURE')
call assert idx~journalPoint~nodeId==old~nodeId,'roll forward should restore fitted temporal index state'
say 'PASS temporal_pattern_index_branching'
exit 0
assert: procedure; use strict arg ok,msg; if \ok then raise syntax 88.900 array(msg); return
::requires "OorexxML.cls"
