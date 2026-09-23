/* MLStandard.cls - conventional machine-learning objects for ooRexx ML.
 *
 * v0.1-dev2 adds dataset identity/provenance, immutable subset derivation,
 * ridge regression, k-NN, and richer metrics while preserving dev1 APIs.
 */

::class MLDatasetProvenance public
::attribute sourceId
::attribute sourceRevision
::attribute acquisitionTag
::attribute digest
::attribute parentDatasetId
::attribute transform
::attribute role
::attribute metadata
::method init
  use strict arg sourceId='',sourceRevision='',acquisitionTag='',digest='',parentDatasetId='',transform='',role='',metadata=.nil
  self~sourceId=sourceId; self~sourceRevision=sourceRevision; self~acquisitionTag=acquisitionTag; self~digest=digest
  self~parentDatasetId=parentDatasetId; self~transform=transform; self~role=role; self~metadata=metadata
::method derive
  use strict arg parentDatasetId,transform,role='',metadata=.nil
  return .MLDatasetProvenance~new(self~sourceId,self~sourceRevision,self~acquisitionTag,self~digest,parentDatasetId,transform,role,metadata)
::method canonicalText
  return 'DATASET_PROVENANCE=source='||self~sourceId||'|revision='||self~sourceRevision||'|tag='||self~acquisitionTag||'|digest='||self~digest||'|parent='||self~parentDatasetId||'|transform='||self~transform||'|role='||self~role

::class MLDataset public
::method init
  expose rows targets featureNames datasetId provenance sampleIds
  use strict arg sourceRows,sourceTargets,sourceFeatureNames=.nil,datasetId='',provenance=.nil,sourceSampleIds=.nil
  if \sourceRows~isA(.Array) | \sourceTargets~isA(.Array) then raise syntax 88.900 array('MLDataset requires row and target Arrays')
  if sourceRows~items<>sourceTargets~items then raise syntax 88.900 array('MLDataset row/target count mismatch')
  rows=.array~new; targets=.array~new; sampleIds=.array~new
  width=-1
  do row over sourceRows
    if \row~isA(.Array) then raise syntax 88.900 array('MLDataset row must be Array')
    if width=-1 then width=row~items
    else if row~items<>width then raise syntax 88.900 array('MLDataset must be rectangular')
    rows~append(.MLFrozenVector~new(row))
  end
  do target over sourceTargets; targets~append(target); end
  if sourceFeatureNames==.nil then featureNames=.MLFrozenVector~new(.array~new)
  else do
    if \sourceFeatureNames~isA(.Array) then raise syntax 88.900 array('MLDataset feature names must be Array')
    if sourceFeatureNames~items>0 & width>=0 & sourceFeatureNames~items<>width then raise syntax 88.900 array('MLDataset feature-name count mismatch')
    featureNames=.MLFrozenVector~new(sourceFeatureNames)
  end
  if sourceSampleIds==.nil then do i=1 to rows~items; sampleIds~append(i); end
  else do
    if \sourceSampleIds~isA(.Array) | sourceSampleIds~items<>rows~items then raise syntax 88.900 array('MLDataset sample-id count mismatch')
    do sid over sourceSampleIds; sampleIds~append(sid); end
  end
  if datasetId='' then datasetId='DATASET-'||rows~items||'x'||self~featureCount
  datasetId=datasetId; provenance=provenance
::method id; expose datasetId; return datasetId
::method provenance; expose provenance; return provenance
::method sampleCount; expose rows; return rows~items
::method featureCount; expose rows; if rows~items=0 then return 0; return rows[1]~items
::method featureNames; expose featureNames; return featureNames~toArray
::method sampleId; expose sampleIds; use strict arg i; return sampleIds[i]
::method sampleIds
  expose sampleIds
  out=.array~new; do sid over sampleIds; out~append(sid); end; return out
::method row; expose rows; use strict arg i; return rows[i]~toArray
::method target; expose targets; use strict arg i; return targets[i]
::method targets
  expose targets
  out=.array~new; do target over targets; out~append(target); end; return out
::method rows
  expose rows
  out=.array~new; do row over rows; out~append(row~toArray); end; return out
::method subset
  expose featureNames datasetId provenance
  use strict arg indices,newId='',role='SUBSET',transform='SUBSET'
  if \indices~isA(.Array) then raise syntax 88.900 array('MLDataset subset indices must be Array')
  outRows=.array~new; outTargets=.array~new; outIds=.array~new
  do idx over indices
    if idx<1 | idx>self~sampleCount then raise syntax 88.900 array('MLDataset subset index out of range',idx)
    outRows~append(self~row(idx)); outTargets~append(self~target(idx)); outIds~append(self~sampleId(idx))
  end
  if newId='' then newId=datasetId||':'||role
  if provenance==.nil then childProv=.MLDatasetProvenance~new('','','','',datasetId,transform,role)
  else childProv=provenance~derive(datasetId,transform,role)
  return .MLDataset~new(outRows,outTargets,featureNames~toArray,newId,childProv,outIds)
::method canonicalText
  expose rows targets datasetId provenance sampleIds
  lines=.array~new; lines~append('DATASET='||datasetId||'|samples='||rows~items||'|features='||self~featureCount)
  if provenance\==.nil then lines~append(provenance~canonicalText)
  do i=1 to rows~items; lines~append(sampleIds[i]||':'||rows[i]~canonicalText||'=>'||targets[i]); end
  return lines~makeString('L')

::class MLStandardScaler subclass MLDriveableObject public
::method init
  use strict arg stableId='SCALER'
  initial=.directory~new; initial['fitted']=.false
  self~init:super(stableId,'STANDARD_SCALER',initial)
::method fit
  use strict arg dataset
  n=dataset~sampleCount; p=dataset~featureCount
  if n=0 then raise syntax 88.900 array('cannot fit scaler on empty dataset')
  means=.array~new; scales=.array~new
  numeric digits 40
  do j=1 to p
    total=0; do i=1 to n; row=dataset~row(i); total=total+row[j]; end
    mean=total/n; means~append(mean)
    var=0; do i=1 to n; row=dataset~row(i); d=row[j]-mean; var=var+d*d; end
    var=var/n; scale=var**0.5; if scale=0 then scale=1
    scales~append(scale)
  end
  changes=.directory~new; changes['means']=.MLFrozenVector~new(means); changes['scales']=.MLFrozenVector~new(scales); changes['fitted']=.true; changes['samples']=n; changes['datasetId']=dataset~id
  return self~mutate(changes,'FIT_SCALER')
::method transformRow
  use strict arg row
  if \self~at('fitted') then raise syntax 88.900 array('MLStandardScaler is not fitted')
  means=self~at('means'); scales=self~at('scales'); out=.array~new
  if row~items<>means~items then raise syntax 88.900 array('scaler row width mismatch')
  do j=1 to row~items; out~append((row[j]-means[j])/scales[j]); end
  return out
::method transform
  use strict arg dataset,newId=''
  rows=.array~new; do i=1 to dataset~sampleCount; rows~append(self~transformRow(dataset~row(i))); end
  if newId='' then newId=dataset~id||':SCALED'
  if dataset~provenance==.nil then prov=.MLDatasetProvenance~new('','','','',dataset~id,'STANDARD_SCALE','TRANSFORMED')
  else prov=dataset~provenance~derive(dataset~id,'STANDARD_SCALE','TRANSFORMED')
  return .MLDataset~new(rows,dataset~targets,dataset~featureNames,newId,prov,dataset~sampleIds)

::class MLLinearRegression subclass MLDriveableObject public
::method init
  use strict arg stableId='LINEAR_REGRESSION',context=.nil
  initial=.directory~new; initial['fitted']=.false; initial['context']=context
  self~init:super(stableId,'LINEAR_REGRESSION',initial)
::method fit
  use strict arg dataset,context=.nil
  if dataset~sampleCount=0 then raise syntax 88.900 array('cannot fit regression on empty dataset')
  if context==.nil then do
    if self~at('context')==.nil then context=.MathContext~rational
    else context=self~at('context')
  end
  rows=.array~new
  do i=1 to dataset~sampleCount
    src=dataset~row(i); row=.array~new; row~append(1)
    do value over src; row~append(value); end
    rows~append(row)
  end
  A=.Maths~matrix(rows,context); b=.Maths~vector(dataset~targets,context)
  At=A~transpose; beta=(At*A)~solve(At*b)
  changes=.directory~new
  changes['coefficients']=.MLFrozenVector~new(beta~toArray)
  changes['featureCount']=dataset~featureCount
  changes['samples']=dataset~sampleCount
  changes['datasetId']=dataset~id
  changes['fitted']=.true
  changes['context']=context
  changes['fitEvidence']=beta~evidence
  return self~mutate(changes,'FIT_LINEAR_REGRESSION')
::method coefficients
  if \self~at('fitted') then raise syntax 88.900 array('MLLinearRegression is not fitted')
  return self~at('coefficients')
::method predict
  use strict arg row
  if \self~at('fitted') then raise syntax 88.900 array('MLLinearRegression is not fitted')
  coeff=self~at('coefficients')
  if row~items<>self~at('featureCount') then raise syntax 88.900 array('regression row width mismatch')
  value=coeff[1]
  do j=1 to row~items; value=value+(coeff[j+1]*row[j]); end
  return value
::method predictDecimal
  use strict arg row,digits=30
  value=self~predict(row)
  if value~hasMethod('TODECIMAL') then return value~toDecimal(digits)
  return value+0

::class MLRidgeRegression subclass MLDriveableObject public
::method init
  use strict arg stableId='RIDGE_REGRESSION',lambda=1,context=.nil
  if lambda<0 then raise syntax 88.900 array('ridge lambda must be non-negative')
  initial=.directory~new; initial['fitted']=.false; initial['lambda']=lambda; initial['context']=context
  self~init:super(stableId,'RIDGE_REGRESSION',initial)
::method lambda; return self~at('lambda')
::method setLambda
  use strict arg lambda
  if lambda<0 then raise syntax 88.900 array('ridge lambda must be non-negative')
  c=.directory~new; c['lambda']=lambda; return self~mutate(c,'RIDGE_LAMBDA')
::method fit
  use strict arg dataset,context=.nil
  if dataset~sampleCount=0 then raise syntax 88.900 array('cannot fit ridge regression on empty dataset')
  if context==.nil then do
    if self~at('context')==.nil then context=.MathContext~rational
    else context=self~at('context')
  end
  rows=.array~new
  do i=1 to dataset~sampleCount
    src=dataset~row(i); row=.array~new; row~append(1)
    do value over src; row~append(value); end
    rows~append(row)
  end
  A=.Maths~matrix(rows,context); b=.Maths~vector(dataset~targets,context); At=A~transpose; normal=At*A
  n=dataset~featureCount+1; regRows=.array~new
  do i=1 to n
    r=.array~new
    do j=1 to n
      if i=j & i>1 then r~append(self~at('lambda')); else r~append(0)
    end
    regRows~append(r)
  end
  reg=.Maths~matrix(regRows,context); beta=(normal+reg)~solve(At*b)
  changes=.directory~new; changes['coefficients']=.MLFrozenVector~new(beta~toArray); changes['featureCount']=dataset~featureCount
  changes['samples']=dataset~sampleCount; changes['datasetId']=dataset~id; changes['fitted']=.true; changes['context']=context; changes['fitEvidence']=beta~evidence
  return self~mutate(changes,'FIT_RIDGE_REGRESSION')
::method coefficients
  if \self~at('fitted') then raise syntax 88.900 array('MLRidgeRegression is not fitted')
  return self~at('coefficients')
::method predict
  use strict arg row
  if \self~at('fitted') then raise syntax 88.900 array('MLRidgeRegression is not fitted')
  coeff=self~at('coefficients'); if row~items<>self~at('featureCount') then raise syntax 88.900 array('ridge row width mismatch')
  value=coeff[1]; do j=1 to row~items; value=value+(coeff[j+1]*row[j]); end; return value
::method predictDecimal
  use strict arg row,digits=30
  value=self~predict(row); if value~hasMethod('TODECIMAL') then return value~toDecimal(digits); return value+0

::class MLCentroidClassifier subclass MLDriveableObject public
::method init
  use strict arg stableId='CENTROID_CLASSIFIER'
  initial=.directory~new; initial['fitted']=.false
  self~init:super(stableId,'CENTROID_CLASSIFIER',initial)
::method fit
  use strict arg dataset
  if dataset~sampleCount=0 then raise syntax 88.900 array('cannot fit classifier on empty dataset')
  sums=.directory~new; counts=.directory~new; p=dataset~featureCount
  do i=1 to dataset~sampleCount
    label=dataset~target(i); row=dataset~row(i)
    if \sums~hasIndex(label) then do
      z=.array~new; do j=1 to p; z~append(0); end; sums[label]=z; counts[label]=0
    end
    v=sums[label]; do j=1 to p; v[j]=v[j]+row[j]; end; counts[label]=counts[label]+1
  end
  frozen=.directory~new; labels=sums~allIndexes; labels~sort
  do classLabel over labels
    v=sums[classLabel]; c=counts[classLabel]; out=.array~new; do j=1 to p; out~append(v[j]/c); end
    frozen[classLabel]=.MLFrozenVector~new(out)
  end
  changes=.directory~new; changes['centroids']=.MLFrozenMap~new(frozen); changes['featureCount']=p; changes['fitted']=.true; changes['samples']=dataset~sampleCount; changes['datasetId']=dataset~id
  return self~mutate(changes,'FIT_CENTROID_CLASSIFIER')
::method predict
  use strict arg row
  if \self~at('fitted') then raise syntax 88.900 array('MLCentroidClassifier is not fitted')
  if row~items<>self~at('featureCount') then raise syntax 88.900 array('classifier row width mismatch')
  centroids=self~at('centroids'); bestLabel=''; bestDistance=0; first=.true
  do classLabel over centroids~allIndexes
    c=centroids[classLabel]; d=0
    do j=1 to row~items; delta=row[j]-c[j]; d=d+delta*delta; end
    if first | d<bestDistance then do; bestDistance=d; bestLabel=classLabel; first=.false; end
  end
  return bestLabel

::class MLKNNClassifier subclass MLDriveableObject public
::method init
  use strict arg stableId='KNN_CLASSIFIER',k=3
  if k<1 then raise syntax 88.900 array('k-NN k must be positive')
  initial=.directory~new; initial['fitted']=.false; initial['k']=k
  self~init:super(stableId,'KNN_CLASSIFIER',initial)
::method k; return self~at('k')
::method setK
  use strict arg k
  if k<1 then raise syntax 88.900 array('k-NN k must be positive')
  c=.directory~new; c['k']=k; return self~mutate(c,'KNN_K')
::method fit
  use strict arg dataset
  if dataset~sampleCount=0 then raise syntax 88.900 array('cannot fit k-NN on empty dataset')
  if self~at('k')>dataset~sampleCount then raise syntax 88.900 array('k-NN k exceeds sample count')
  c=.directory~new; c['dataset']=dataset; c['datasetId']=dataset~id; c['featureCount']=dataset~featureCount; c['fitted']=.true
  return self~mutate(c,'FIT_KNN')
::method predict
  use strict arg row
  if \self~at('fitted') then raise syntax 88.900 array('MLKNNClassifier is not fitted')
  if row~items<>self~at('featureCount') then raise syntax 88.900 array('k-NN row width mismatch')
  d=self~at('dataset'); distances=.array~new
  do i=1 to d~sampleCount
    train=d~row(i); dist=0
    do j=1 to row~items; delta=row[j]-train[j]; dist=dist+delta*delta; end
    distances~append(.MLNeighbor~new(dist,d~target(i),i))
  end
  distances~sortWith(.MLNeighborComparator~new)
  votes=.directory~new; distanceSum=.directory~new
  do i=1 to self~at('k')
    n=distances[i]; label=n~label
    if \votes~hasIndex(label) then do; votes[label]=0; distanceSum[label]=0; end
    votes[label]=votes[label]+1; distanceSum[label]=distanceSum[label]+n~distance
  end
  labels=votes~allIndexes; labels~sort; best=''; bestVotes=-1; bestDistance=0; first=.true
  do classLabel over labels
    label=classLabel
    if votes[label]>bestVotes | (votes[label]=bestVotes & (first | distanceSum[label]<bestDistance)) then do
      best=label; bestVotes=votes[label]; bestDistance=distanceSum[label]; first=.false
    end
  end
  return best

::class MLNeighbor public
::attribute distance
::attribute label
::attribute index
::method init; use strict arg distance,label,index; self~distance=distance; self~label=label; self~index=index

::class MLNeighborComparator public
::method compare
  use strict arg a,b
  if a~distance<b~distance then return -1
  if a~distance>b~distance then return 1
  if a~index<b~index then return -1
  if a~index>b~index then return 1
  return 0

::class MLLinearGDRegressor subclass MLDriveableObject public
::method init
  use strict arg stableId='LINEAR_GD_REGRESSOR'
  initial=.directory~new; initial['fitted']=.false; initial['epochsTrained']=0; initial['objective']=.nil
  self~init:super(stableId,'LINEAR_GD_REGRESSOR',initial)
::method train
  use strict arg dataset,optimizer,session=.nil,epochs=100
  if dataset~sampleCount=0 then raise syntax 88.900 array('cannot train gradient regressor on empty dataset')
  if epochs<1 then raise syntax 88.900 array('gradient-regression epochs must be positive')
  if \optimizer~hasMethod('APPLY') then raise syntax 88.900 array('gradient regressor requires optimizer apply contract')
  p=dataset~featureCount
  if \self~at('fitted') then do
    weights=.array~new; do j=0 to p; weights~append(0); end
    c=.directory~new; c['parameters']=.MLFrozenVector~new(weights); c['featureCount']=p; c['datasetId']=dataset~id; c['fitted']=.true; c['epochsTrained']=0
    self~mutate(c,'GD_INITIALIZE')
  end
  else if self~at('featureCount')<>p then raise syntax 88.900 array('gradient regressor feature width changed across continuation')
  do localEpoch=1 to epochs
    weights=self~at('parameters')~toArray
    gradient=self~gradient(dataset,weights)
    newWeights=optimizer~apply(weights,gradient,'GD_OPTIMIZER_STEP')
    objective=self~objective(dataset,newWeights)
    epochNumber=self~at('epochsTrained')+1
    c=.directory~new; c['parameters']=newWeights; c['objective']=objective; c['epochsTrained']=epochNumber; c['datasetId']=dataset~id; c['samples']=dataset~sampleCount
    self~mutate(c,'GD_EPOCH')
    if session\==.nil then do
      metrics=.directory~new; metrics['mse']=objective
      session~recordEpoch(epochNumber,objective,metrics)
    end
  end
  return self~journalPoint
::method parameters
  if \self~at('fitted') then raise syntax 88.900 array('MLLinearGDRegressor is not fitted')
  return self~at('parameters')
::method predict
  use strict arg row
  if \self~at('fitted') then raise syntax 88.900 array('MLLinearGDRegressor is not fitted')
  if row~items<>self~at('featureCount') then raise syntax 88.900 array('gradient regression row width mismatch')
  w=self~at('parameters'); value=w[1]; do j=1 to row~items; value=value+(w[j+1]*row[j]); end; return value
::method gradient private
  use strict arg dataset,weights
  n=dataset~sampleCount; p=dataset~featureCount; grad=.array~new; do j=0 to p; grad~append(0); end
  do i=1 to n
    row=dataset~row(i); predicted=weights[1]; do j=1 to p; predicted=predicted+(weights[j+1]*row[j]); end
    error=predicted-dataset~target(i); grad[1]=grad[1]+(2*error)
    do j=1 to p; grad[j+1]=grad[j+1]+(2*error*row[j]); end
  end
  do j=1 to grad~items; grad[j]=grad[j]/n; end
  return grad
::method objective private
  use strict arg dataset,weights
  expected=dataset~targets; predicted=.array~new; p=dataset~featureCount
  do i=1 to dataset~sampleCount
    row=dataset~row(i); value=weights[1]; do j=1 to p; value=value+(weights[j+1]*row[j]); end; predicted~append(value)
  end
  return .MLMetrics~meanSquaredError(expected,predicted)

::class MLConfusionMatrix public
::method init
  expose labels counts
  use strict arg expected,predicted
  if expected~items<>predicted~items | expected~items=0 then raise syntax 88.900 array('confusion arrays must have equal nonzero length')
  set=.directory~new; do v over expected; set[v]=1; end; do v over predicted; set[v]=1; end
  labels=set~allIndexes; labels~sort; counts=.directory~new
  do actual over labels
    row=.directory~new; do predictedLabel over labels; row[predictedLabel]=0; end; counts[actual]=row
  end
  do i=1 to expected~items; actual=expected[i]; p=predicted[i]; row=counts[actual]; row[p]=row[p]+1; end
::method labels; expose labels; out=.array~new; do v over labels; out~append(v); end; return out
::method count; expose counts; use strict arg actual,predicted; if \counts~hasIndex(actual) then return 0; if \counts[actual]~hasIndex(predicted) then return 0; return counts[actual][predicted]
::method total
  expose labels counts
  n=0; do a over labels; do p over labels; n=n+counts[a][p]; end; end; return n
::method canonicalText
  expose labels counts
  lines=.array~new; do a over labels; do p over labels; lines~append(a||'->'||p||'='||counts[a][p]); end; end; return lines~makeString('L')

::class MLMetrics public
::method meanSquaredError class
  use strict arg expected,predicted
  ignored=self~checkPair(expected,predicted)
  numeric digits 40; total=0
  do i=1 to expected~items; a=self~number(expected[i]); b=self~number(predicted[i]); d=a-b; total=total+d*d; end
  return total/expected~items
::method meanAbsoluteError class
  use strict arg expected,predicted
  ignored=self~checkPair(expected,predicted)
  numeric digits 40; total=0
  do i=1 to expected~items; total=total+abs(self~number(expected[i])-self~number(predicted[i])); end
  return total/expected~items
::method rootMeanSquaredError class
  use strict arg expected,predicted
  return self~meanSquaredError(expected,predicted)**0.5
::method rSquared class
  use strict arg expected,predicted
  ignored=self~checkPair(expected,predicted)
  numeric digits 40; mean=0; do v over expected; mean=mean+self~number(v); end; mean=mean/expected~items
  ssTot=0; ssRes=0
  do i=1 to expected~items
    a=self~number(expected[i]); p=self~number(predicted[i]); ssTot=ssTot+(a-mean)*(a-mean); ssRes=ssRes+(a-p)*(a-p)
  end
  if ssTot=0 then do; if ssRes=0 then return 1; return 0; end
  return 1-(ssRes/ssTot)
::method accuracy class
  use strict arg expected,predicted
  ignored=self~checkPair(expected,predicted)
  hits=0; do i=1 to expected~items; if expected[i]==predicted[i] then hits=hits+1; end
  return hits/expected~items
::method confusionMatrix class
  use strict arg expected,predicted
  return .MLConfusionMatrix~new(expected,predicted)
::method precision class
  use strict arg expected,predicted,positiveLabel
  cm=.MLConfusionMatrix~new(expected,predicted); tp=cm~count(positiveLabel,positiveLabel); fp=0
  do actual over cm~labels; if actual\==positiveLabel then fp=fp+cm~count(actual,positiveLabel); end
  if tp+fp=0 then return 0
  return tp/(tp+fp)
::method recall class
  use strict arg expected,predicted,positiveLabel
  cm=.MLConfusionMatrix~new(expected,predicted); tp=cm~count(positiveLabel,positiveLabel); fn=0
  do p over cm~labels; if p\==positiveLabel then fn=fn+cm~count(positiveLabel,p); end
  if tp+fn=0 then return 0
  return tp/(tp+fn)
::method f1 class
  use strict arg expected,predicted,positiveLabel
  p=self~precision(expected,predicted,positiveLabel); r=self~recall(expected,predicted,positiveLabel); if p+r=0 then return 0; return 2*p*r/(p+r)
::method evaluate class
  use strict arg metricName,expected,predicted,positiveLabel=''
  m=metricName~translate
  if m='MSE' | m='MEANSQUAREDERROR' then return self~meanSquaredError(expected,predicted)
  if m='MAE' | m='MEANABSOLUTEERROR' then return self~meanAbsoluteError(expected,predicted)
  if m='RMSE' | m='ROOTMEANSQUAREDERROR' then return self~rootMeanSquaredError(expected,predicted)
  if m='R2' | m='RSQUARED' then return self~rSquared(expected,predicted)
  if m='ACCURACY' then return self~accuracy(expected,predicted)
  if m='PRECISION' then return self~precision(expected,predicted,positiveLabel)
  if m='RECALL' then return self~recall(expected,predicted,positiveLabel)
  if m='F1' then return self~f1(expected,predicted,positiveLabel)
  raise syntax 88.900 array('unknown ML metric',metricName)
::method checkPair class private
  use strict arg expected,predicted
  if \expected~isA(.Array) | \predicted~isA(.Array) | expected~items<>predicted~items | expected~items=0 then raise syntax 88.900 array('metric arrays must have equal nonzero length')
  return .true
::method number class private
  use strict arg value
  if value~hasMethod('TODECIMAL') then return value~toDecimal(40)
  return value+0

::requires "MLCore.cls"
::requires "MathsBootstrap.cls"
