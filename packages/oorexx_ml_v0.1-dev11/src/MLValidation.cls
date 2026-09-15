/* MLValidation.cls - split/fold plans, validation evidence and branch comparison. */

::class MLDataSplit public
::attribute id
::attribute train
::attribute test
::attribute trainIndices
::attribute testIndices
::attribute method
::attribute evidence
::method init
  use strict arg id,train,test,trainIndices,testIndices,method='HOLDOUT',evidence=.nil
  self~id=id; self~train=train; self~test=test; self~trainIndices=.MLFrozenVector~new(trainIndices); self~testIndices=.MLFrozenVector~new(testIndices); self~method=method; self~evidence=evidence
::method canonicalText
  return 'SPLIT='||self~id||'|method='||self~method||'|train='||self~train~id||':'||self~trainIndices~canonicalText||'|test='||self~test~id||':'||self~testIndices~canonicalText

::class MLFold public
::attribute number
::attribute trainIndices
::attribute testIndices
::method init
  use strict arg number,trainIndices,testIndices
  self~number=number; self~trainIndices=.MLFrozenVector~new(trainIndices); self~testIndices=.MLFrozenVector~new(testIndices)
::method canonicalText; return 'FOLD='||self~number||'|train='||self~trainIndices~canonicalText||'|test='||self~testIndices~canonicalText

::class MLKFoldPlan public
::attribute id
::attribute datasetId
::attribute k
::attribute shuffled
::attribute rngPoint
::method init
  expose folds
  use strict arg id,datasetId,k,sourceFolds,shuffled=.false,rngPoint=''
  self~id=id; self~datasetId=datasetId; self~k=k; self~shuffled=shuffled; self~rngPoint=rngPoint
  folds=.array~new; do fold over sourceFolds; folds~append(fold); end
::method fold; expose folds; use strict arg i; return folds[i]
::method folds; expose folds; out=.array~new; do f over folds; out~append(f); end; return out
::method canonicalText
  expose folds
  lines=.array~new; lines~append('KFOLD='||self~id||'|dataset='||self~datasetId||'|k='||self~k||'|shuffled='||self~shuffled||'|rng='||self~rngPoint)
  do f over folds; lines~append(f~canonicalText); end; return lines~makeString('L')

::class MLSplitter public
::method holdout class
  use strict arg dataset,testFraction=0.20,rng=.nil,id='HOLDOUT'
  if dataset~sampleCount<2 then raise syntax 88.900 array('holdout requires at least two samples')
  if testFraction<=0 | testFraction>=1 then raise syntax 88.900 array('test fraction must be between zero and one')
  indexes=self~indexes(dataset~sampleCount); rngPoint=''; shuffled=.false
  if rng\==.nil then do; indexes=self~shuffle(indexes,rng); rngPoint=rng~journalPoint~string; shuffled=.true; end
  testCount=trunc(dataset~sampleCount*testFraction); if testCount<1 then testCount=1; if testCount>=dataset~sampleCount then testCount=dataset~sampleCount-1
  trainCount=dataset~sampleCount-testCount; trainIdx=.array~new; testIdx=.array~new
  do i=1 to trainCount; trainIdx~append(indexes[i]); end
  do i=trainCount+1 to indexes~items; testIdx~append(indexes[i]); end
  train=dataset~subset(trainIdx,dataset~id||':'||id||':TRAIN','TRAIN','HOLDOUT:'||id)
  test=dataset~subset(testIdx,dataset~id||':'||id||':TEST','TEST','HOLDOUT:'||id)
  e=.directory~new; e['fraction']=testFraction; e['shuffled']=shuffled; e['rngPoint']=rngPoint
  return .MLDataSplit~new(id,train,test,trainIdx,testIdx,'HOLDOUT',.MLFrozenMap~new(e))
::method kfold class
  use strict arg dataset,k=5,rng=.nil,id='KFOLD'
  if k<2 | k>dataset~sampleCount then raise syntax 88.900 array('k-fold k must be between 2 and sample count')
  indexes=self~indexes(dataset~sampleCount); rngPoint=''; shuffled=.false
  if rng\==.nil then do; indexes=self~shuffle(indexes,rng); rngPoint=rng~journalPoint~string; shuffled=.true; end
  folds=.array~new
  do f=1 to k
    train=.array~new; test=.array~new
    do pos=1 to indexes~items
      which=((pos-1)//k)+1
      if which=f then test~append(indexes[pos]); else train~append(indexes[pos])
    end
    folds~append(.MLFold~new(f,train,test))
  end
  return .MLKFoldPlan~new(id,dataset~id,k,folds,shuffled,rngPoint)
::method indexes class private
  use strict arg n
  out=.array~new; do i=1 to n; out~append(i); end; return out
::method shuffle class private
  use strict arg indexes,rng
  if \rng~hasMethod('CURSOR') | \rng~hasMethod('COMMITCURSOR') then raise syntax 88.900 array('shuffle RNG lacks cursor contract')
  out=.array~new; do v over indexes; out~append(v); end; cursor=rng~cursor
  do i=out~items to 2 by -1; j=cursor~nextInt(i); tmp=out[i]; out[i]=out[j]; out[j]=tmp; end
  rng~commitCursor(cursor,'DATASET_SHUFFLE')
  return out

::class MLClassModelFactory public
::method init; expose classObject prefix; use strict arg newClassObject,newPrefix='CV'; classObject=newClassObject; prefix=newPrefix
::method create
  expose classObject prefix
  use strict arg id
  return classObject~new(prefix||':'||id)

::class MLFoldResult public
::attribute fold
::attribute modelId
::attribute modelPoint
::attribute metric
::attribute value
::attribute expected
::attribute predicted
::attribute modelState
::method init
  use strict arg fold,model,metric,value,expected,predicted
  self~fold=fold; self~modelId=model~stableId; self~modelPoint=model~journalPoint~string; self~metric=metric; self~value=value
  self~expected=.MLFrozenVector~new(expected); self~predicted=.MLFrozenVector~new(predicted); self~modelState=.MLFrozenMap~new(model~snapshot)
::method canonicalText; return 'FOLD_RESULT='||self~fold||'|model='||self~modelId||'@'||self~modelPoint||'|metric='||self~metric||'|value='||self~value

::class MLValidationEvidence public
::attribute id
::attribute datasetId
::attribute planId
::attribute metric
::attribute aggregate
::attribute sourceIdentity
::method init
  expose results
  use strict arg id,datasetId,planId,metric,aggregate,sourceResults,sourceIdentity=.nil
  self~id=id; self~datasetId=datasetId; self~planId=planId; self~metric=metric; self~aggregate=aggregate; self~sourceIdentity=sourceIdentity
  results=.array~new; do r over sourceResults; results~append(r); end
::method results; expose results; out=.array~new; do r over results; out~append(r); end; return out
::method canonicalText
  expose results
  lines=.array~new; lines~append('VALIDATION='||self~id||'|dataset='||self~datasetId||'|plan='||self~planId||'|metric='||self~metric||'|aggregate='||self~aggregate)
  do r over results; lines~append(r~canonicalText); end; return lines~makeString('L')

::class MLCrossValidator public
::method evaluate class
  use strict arg dataset,plan,factory,metricName='MSE',positiveLabel='',sourceIdentity=.nil
  if plan~datasetId\==dataset~id then raise syntax 88.900 array('validation plan dataset identity mismatch')
  results=.array~new; total=0
  do f=1 to plan~k
    fold=plan~fold(f); train=dataset~subset(fold~trainIndices~toArray,dataset~id||':'||plan~id||':F'||f||':TRAIN','TRAIN','KFOLD:'||plan~id)
    test=dataset~subset(fold~testIndices~toArray,dataset~id||':'||plan~id||':F'||f||':TEST','TEST','KFOLD:'||plan~id)
    model=factory~create(plan~id||':F'||f); model~fit(train)
    predicted=.array~new; do i=1 to test~sampleCount; predicted~append(model~predict(test~row(i))); end
    expected=test~targets; value=.MLMetrics~evaluate(metricName,expected,predicted,positiveLabel); total=total+value
    results~append(.MLFoldResult~new(f,model,metricName,value,expected,predicted))
  end
  aggregate=total/plan~k
  return .MLValidationEvidence~new('VALIDATION:'||plan~id,dataset~id,plan~id,metricName,aggregate,results,sourceIdentity)

::class MLBranchComparisonResult public
::attribute modelId
::attribute branchA
::attribute branchB
::attribute pointA
::attribute pointB
::attribute metric
::attribute valueA
::attribute valueB
::attribute preferredBranch
::attribute predictionsA
::attribute predictionsB
::method init
  use strict arg modelId,branchA,branchB,pointA,pointB,metric,valueA,valueB,preferredBranch,predictionsA,predictionsB
  self~modelId=modelId; self~branchA=branchA; self~branchB=branchB; self~pointA=pointA; self~pointB=pointB; self~metric=metric; self~valueA=valueA; self~valueB=valueB; self~preferredBranch=preferredBranch
  self~predictionsA=.MLFrozenVector~new(predictionsA); self~predictionsB=.MLFrozenVector~new(predictionsB)
::method canonicalText
  return 'BRANCH_COMPARISON=model='||self~modelId||'|A='||self~branchA||'@'||self~pointA||':'||self~valueA||'|B='||self~branchB||'@'||self~pointB||':'||self~valueB||'|metric='||self~metric||'|preferred='||self~preferredBranch

::class MLBranchComparator public
::method compare class
  use strict arg model,branchA,branchB,dataset,metricName='MSE',positiveLabel='',direction='AUTO'
  if model~branch(branchA)==.nil | model~branch(branchB)==.nil then raise syntax 88.900 array('branch comparison requires retained named branches')
  originalPoint=model~journalPoint; pointA=model~branchHead(branchA); pointB=model~branchHead(branchB)
  model~journalMoveTo(pointA,.false); predA=self~predictDataset(model,dataset)
  model~journalMoveTo(pointB,.false); predB=self~predictDataset(model,dataset)
  model~journalMoveTo(originalPoint,.false)
  expected=dataset~targets; valueA=.MLMetrics~evaluate(metricName,expected,predA,positiveLabel); valueB=.MLMetrics~evaluate(metricName,expected,predB,positiveLabel)
  d=direction~translate
  if d='AUTO' then do
    m=metricName~translate; if m='ACCURACY' | m='PRECISION' | m='RECALL' | m='F1' | m='R2' | m='RSQUARED' then d='MAXIMIZE'; else d='MINIMIZE'
  end
  if d='MINIMIZE' then do; if valueA<=valueB then preferred=branchA; else preferred=branchB; end
  else if d='MAXIMIZE' then do; if valueA>=valueB then preferred=branchA; else preferred=branchB; end
  else raise syntax 88.900 array('branch comparison direction must be AUTO, MINIMIZE or MAXIMIZE')
  return .MLBranchComparisonResult~new(model~stableId,branchA,branchB,pointA~string,pointB~string,metricName,valueA,valueB,preferred,predA,predB)
::method predictDataset class private
  use strict arg model,dataset
  out=.array~new; do i=1 to dataset~sampleCount; out~append(model~predict(dataset~row(i))); end; return out

::requires "MLCore.cls"
::requires "MLStandard.cls"
::requires "MLEvolution.cls"
