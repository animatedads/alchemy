/* technique_sampler.rex - compact dev7 catalogue demonstration. */
rows=.array~of(.array~of(-2,-2),.array~of(-1,-1),.array~of(1,1),.array~of(2,2))
labels=.array~of('LOW','LOW','HIGH','HIGH')
d=.MLDataset~new(rows,labels,.array~of('x','y'),'TECHNIQUE-DEMO')

log=.MLBinaryLogisticRegression~new('demo-logistic',.15,200,0); log~fit(d,'HIGH')
say 'LOGISTIC' log~predict(.array~of(1.5,1.5)) 'p='log~predictProbability(.array~of(1.5,1.5))

nb=.MLGaussianNaiveBayes~new('demo-nb'); nb~fit(d)
say 'NAIVE_BAYES' nb~predict(.array~of(-1.5,-1.4))

tree=.MLDecisionTreeClassifier~new('demo-tree',3); tree~fit(d)
say 'TREE' tree~predict(.array~of(1.7,1.6))

unlabelled=.MLDataset~new(rows,.array~of(.nil,.nil,.nil,.nil),.array~of('x','y'),'UNLABELLED')
km=.MLKMeans~new('demo-kmeans',2); km~fit(unlabelled)
say 'KMEANS clusters='km~predict(.array~of(-1.5,-1.5))','km~predict(.array~of(1.5,1.5)) 'inertia='km~inertia

pca=.MLPrincipalComponentAnalysis~new('demo-pca',1); pca~fit(unlabelled)
t=pca~transformRow(.array~of(2,2))
say 'PCA pc1='t[1] 'explained='pca~explainedVarianceRatio[1]

say 'PASS technique_sampler'
::requires "OorexxML.cls"
