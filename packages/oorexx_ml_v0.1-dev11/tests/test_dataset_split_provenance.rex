rows=.array~of(.array~of(0),.array~of(1),.array~of(2),.array~of(3),.array~of(4),.array~of(5))
y=.array~of(0,1,2,3,4,5)
prov=.MLDatasetProvenance~new('camera-A','rev17','capture','sha256:abc')
d=.MLDataset~new(rows,y,.array~of('x'),'D1',prov,.array~of('s0','s1','s2','s3','s4','s5'))
rng=.MLDeterministicRNG~new(2468,'split-rng')
root=rng~journalPoint
s1=.MLSplitter~holdout(d,0.34,rng,'S1')
call eq 4,s1~train~sampleCount,'train count'
call eq 2,s1~test~sampleCount,'test count'
call eq 'D1',s1~test~provenance~parentDatasetId,'parent provenance'
call eq 'TEST',s1~test~provenance~role,'test role'
c1=s1~canonicalText
rng~rollback(root,'first-split')
s2=.MLSplitter~holdout(d,0.34,rng,'S1')
call eq c1,s2~canonicalText,'split replay from RNG checkpoint'
plan=.MLSplitter~kfold(d,3,.nil,'K3')
call eq 3,plan~k,'k fold count'
call eq 2,plan~fold(1)~testIndices~items,'fold test size'
say 'PASS test_dataset_split_provenance'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end
 return
::requires "OorexxML.cls"
