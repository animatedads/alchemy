names=.MLTechniqueCatalogue~names
call eq 9,names~items,'technique count'
d=.MLTechniqueCatalogue~describe('KMEANS')
call eq 'UNSUPERVISED_CLUSTERING',d['family'],'kmeans family'
call truth \d['requiresLabels'],'kmeans unlabeled'
d=.MLTechniqueCatalogue~describe('LOGISTIC_REGRESSION')
call truth d['probabilistic'],'logistic probabilistic'
d=.MLTechniqueCatalogue~describe('CLOSE_NEIGHBOUR_HASHING')
call eq 'APPROXIMATE_NEIGHBOUR_SEARCH',d['family'],'close-neighbour family'
d=.MLTechniqueCatalogue~describe('PATTERN_HASHING')
call eq 'SHAPE_RECOGNITION',d['family'],'pattern-hashing family'
d=.MLTechniqueCatalogue~describe('TEMPORAL_PATTERN_HASHING')
call eq 'TEMPORAL_SHAPE_RECOGNITION',d['family'],'temporal-pattern family'
d=.MLTechniqueCatalogue~describe('WOBBLY_FIT')
call eq 'FIT_DIAGNOSTIC',d['family'],'wobbly-fit family'
say 'PASS test_technique_catalogue'
exit 0

eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l 'expected='e 'actual='a; exit 1; end
 return
truth: procedure
 use arg ok,l
 if \ok then do; say 'FAIL' l; exit 1; end
 return
::requires "OorexxML.cls"
