rows=.array~of(.array~of(-2,-2.1),.array~of(-1,-.9),.array~of(0,0),.array~of(1,1.1),.array~of(2,1.9))
y=.array~of(0,0,0,0,0)
p=.MLDatasetProvenance~new('SENSOR','R1','CAL','abc')
d=.MLDataset~new(rows,y,.array~of('x','y'),'PCA-DATA',p)
m=.MLPrincipalComponentAnalysis~new('pca',1,200,1E-14)
m~fit(d)
r=m~explainedVarianceRatio
call truth r[1]>.99,'first component explains collinear data'
components=m~components; c=components[1]
call near abs(c[1]),abs(c[2]),.05,'loadings approximately equal magnitude'
t=m~transform(d)
call eq 1,t~featureCount,'transformed width'
call eq 5,t~sampleCount,'transformed sample count'
call eq 'PCA-DATA',t~provenance~parentDatasetId,'PCA provenance parent'
call eq 'PCA',t~provenance~transform,'PCA provenance transform'
say 'PASS test_pca'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end
 return
near: procedure
 use arg a,b,t,l
 if abs(a-b)>t then do; say 'FAIL' l 'expected~=' b 'actual=' a; exit 1; end
 return
truth: procedure
 use arg ok,l
 if \ok then do; say 'FAIL' l; exit 1; end
 return
::requires "OorexxML.cls"
