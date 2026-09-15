/* MLTechniques.cls - additional conventional ML techniques for ooRexx ML.
 *
 * v0.1-dev7 adds a balanced pure-ooRexx reference catalogue:
 *   - binary logistic regression
 *   - Gaussian Naive Bayes
 *   - Gini decision-tree classification
 *   - deterministic k-means clustering
 *   - principal-component analysis (power iteration + deflation)
 *
 * These objects preserve the core ML rule: learned state is journalled through
 * MLDriveableObject and remains branchable/rollback-capable.  Implementations
 * are intentionally reference implementations; accelerated providers may
 * replace execution but not semantics, evidence, or state shape.
 */

::class MLTechniqueCatalogue public
::method names class
  return .array~of('LOGISTIC_REGRESSION','GAUSSIAN_NAIVE_BAYES','DECISION_TREE_CLASSIFIER','KMEANS','PCA','CLOSE_NEIGHBOUR_HASHING','PATTERN_HASHING','TEMPORAL_PATTERN_HASHING','WOBBLY_FIT')
::method describe class
  use strict arg name
  n=name~translate
  d=.directory~new
  if n='LOGISTIC_REGRESSION' then do
    d['family']='SUPERVISED_CLASSIFICATION'; d['probabilistic']=.true; d['iterative']=.true; d['requiresLabels']=.true
  end
  else if n='GAUSSIAN_NAIVE_BAYES' then do
    d['family']='SUPERVISED_CLASSIFICATION'; d['probabilistic']=.true; d['iterative']=.false; d['requiresLabels']=.true
  end
  else if n='DECISION_TREE_CLASSIFIER' then do
    d['family']='SUPERVISED_CLASSIFICATION'; d['probabilistic']=.false; d['iterative']=.false; d['requiresLabels']=.true
  end
  else if n='KMEANS' then do
    d['family']='UNSUPERVISED_CLUSTERING'; d['probabilistic']=.false; d['iterative']=.true; d['requiresLabels']=.false
  end
  else if n='PCA' then do
    d['family']='UNSUPERVISED_TRANSFORM'; d['probabilistic']=.false; d['iterative']=.true; d['requiresLabels']=.false
  end
  else if n='CLOSE_NEIGHBOUR_HASHING' then do
    d['family']='APPROXIMATE_NEIGHBOUR_SEARCH'; d['probabilistic']=.false; d['iterative']=.false; d['requiresLabels']=.false
  end
  else if n='PATTERN_HASHING' then do
    d['family']='SHAPE_RECOGNITION'; d['probabilistic']=.false; d['iterative']=.false; d['requiresLabels']=.false
  end
  else if n='TEMPORAL_PATTERN_HASHING' then do
    d['family']='TEMPORAL_SHAPE_RECOGNITION'; d['probabilistic']=.false; d['iterative']=.false; d['requiresLabels']=.false
  end
  else if n='WOBBLY_FIT' then do
    d['family']='FIT_DIAGNOSTIC'; d['probabilistic']=.false; d['iterative']=.true; d['requiresLabels']=.false
  end
  else raise syntax 88.900 array('unknown ML technique',name)
  d['name']=n; d['referenceImplementation']='PURE_OOREXX'; return d

::class MLNumerics private
::method exp class
  use strict arg x
  numeric digits 40
  x=x+0
  if x>80 then x=80
  if x< -80 then x=-80
  halves=0; y=x
  do while abs(y)>.5
    y=y/2; halves=halves+1
  end
  term=1; total=1
  do k=1 to 48
    term=term*y/k; total=total+term
  end
  do i=1 to halves; total=total*total; end
  return total
::method sigmoid class
  use strict arg x
  numeric digits 40
  if x>=0 then do
    e=self~exp(-x); return 1/(1+e)
  end
  e=self~exp(x); return e/(1+e)
::method ln class
  use strict arg x
  numeric digits 40
  x=x+0
  if x<=0 then raise syntax 88.900 array('natural log requires positive value',x)
  k=0; m=x
  do while m>1.5; m=m/2; k=k+1; end
  do while m<.75; m=m*2; k=k-1; end
  y=(m-1)/(m+1); y2=y*y; term=y; s=0
  do n=1 by 2 to 79
    s=s+term/n; term=term*y2
  end
  return 2*s+k*0.6931471805599453094172321214581765680755
::method sqrt class
  use strict arg x
  numeric digits 40
  x=x+0
  if x<0 then raise syntax 88.900 array('square root requires non-negative value',x)
  if x=0 then return 0
  if x<1 then guess=1; else guess=x
  do i=1 to 48; guess=(guess+x/guess)/2; end
  return guess
::method squaredDistance class
  use strict arg a,b
  if a~items<>b~items then raise syntax 88.900 array('vector width mismatch')
  numeric digits 40; d=0
  do i=1 to a~items; x=(a[i]+0)-(b[i]+0); d=d+x*x; end
  return d
::method copyArray class
  use strict arg source
  out=.array~new; do x over source; out~append(x); end; return out
::method normalise class
  use strict arg v
  numeric digits 40; norm2=0
  do x over v; norm2=norm2+(x+0)*(x+0); end
  if norm2=0 then return .nil
  norm=self~sqrt(norm2); out=.array~new; do x over v; out~append((x+0)/norm); end; return out
::method dot class
  use strict arg a,b
  if a~items<>b~items then raise syntax 88.900 array('dot width mismatch')
  numeric digits 40; s=0; do i=1 to a~items; s=s+(a[i]+0)*(b[i]+0); end; return s

::class MLBinaryLogisticRegression subclass MLDriveableObject public
::method init
  use strict arg stableId='LOGISTIC_REGRESSION',learningRate=.1,epochs=200,l2=0
  if learningRate<=0 then raise syntax 88.900 array('logistic learning rate must be positive')
  if epochs<1 then raise syntax 88.900 array('logistic epochs must be positive')
  if l2<0 then raise syntax 88.900 array('logistic L2 must be non-negative')
  initial=.directory~new; initial['fitted']=.false; initial['learningRate']=learningRate; initial['epochs']=epochs; initial['l2']=l2
  self~init:super(stableId,'LOGISTIC_REGRESSION',initial)
::method setPolicy
  use strict arg learningRate,epochs,l2=0
  if learningRate<=0 | epochs<1 | l2<0 then raise syntax 88.900 array('invalid logistic policy')
  c=.directory~new; c['learningRate']=learningRate; c['epochs']=epochs; c['l2']=l2; return self~mutate(c,'LOGISTIC_POLICY')
::method fit
  use strict arg dataset,positiveLabel=.nil
  if dataset~sampleCount<2 then raise syntax 88.900 array('logistic regression requires at least two samples')
  labelSet=.directory~new; do y over dataset~targets; labelSet[y]=1; end
  labels=labelSet~allIndexes; labels~sort
  if labels~items<>2 then raise syntax 88.900 array('binary logistic regression requires exactly two labels')
  if positiveLabel==.nil then positive=labels[2]
  else do
    if \labelSet~hasIndex(positiveLabel) then raise syntax 88.900 array('requested logistic positive label is not present',positiveLabel)
    positive=positiveLabel
  end
  if labels[1]==positive then negative=labels[2]; else negative=labels[1]
  p=dataset~featureCount; weights=.array~new; do j=0 to p; weights~append(0); end
  rate=self~at('learningRate'); epochs=self~at('epochs'); l2=self~at('l2'); n=dataset~sampleCount
  numeric digits 40
  lastMse=0
  do epoch=1 to epochs
    grad=.array~new; do j=0 to p; grad~append(0); end
    mse=0
    do i=1 to n
      row=dataset~row(i); z=weights[1]; do j=1 to p; z=z+weights[j+1]*row[j]; end
      prob=.MLNumerics~sigmoid(z); if dataset~target(i)==positive then target=1; else target=0
      error=prob-target; mse=mse+error*error; grad[1]=grad[1]+error
      do j=1 to p; grad[j+1]=grad[j+1]+error*row[j]; end
    end
    grad[1]=grad[1]/n
    do j=2 to grad~items; grad[j]=(grad[j]/n)+(l2*weights[j]); end
    do j=1 to weights~items; weights[j]=weights[j]-rate*grad[j]; end
    lastMse=mse/n
  end
  c=.directory~new; c['weights']=.MLFrozenVector~new(weights); c['featureCount']=p; c['negativeLabel']=negative; c['positiveLabel']=positive
  c['samples']=n; c['datasetId']=dataset~id; c['epochsTrained']=epochs; c['probabilityMSE']=lastMse; c['fitted']=.true
  return self~mutate(c,'FIT_LOGISTIC_REGRESSION')
::method weights
  if \self~at('fitted') then raise syntax 88.900 array('logistic regression is not fitted')
  return self~at('weights')
::method predictProbability
  use strict arg row
  if \self~at('fitted') then raise syntax 88.900 array('logistic regression is not fitted')
  if row~items<>self~at('featureCount') then raise syntax 88.900 array('logistic row width mismatch')
  w=self~at('weights'); z=w[1]; do j=1 to row~items; z=z+w[j+1]*row[j]; end
  return .MLNumerics~sigmoid(z)
::method predict
  use strict arg row,threshold=.5
  p=self~predictProbability(row); if p>=threshold then return self~at('positiveLabel'); return self~at('negativeLabel')

::class MLGaussianNaiveBayes subclass MLDriveableObject public
::method init
  use strict arg stableId='GAUSSIAN_NAIVE_BAYES',varianceFloor=1E-12
  if varianceFloor<=0 then raise syntax 88.900 array('Gaussian NB variance floor must be positive')
  initial=.directory~new; initial['fitted']=.false; initial['varianceFloor']=varianceFloor
  self~init:super(stableId,'GAUSSIAN_NAIVE_BAYES',initial)
::method fit
  use strict arg dataset
  if dataset~sampleCount<1 then raise syntax 88.900 array('cannot fit Gaussian NB on empty dataset')
  p=dataset~featureCount; sums=.directory~new; sums2=.directory~new; counts=.directory~new
  do i=1 to dataset~sampleCount
    label=dataset~target(i); row=dataset~row(i)
    if \counts~hasIndex(label) then do
      counts[label]=0; a=.array~new; b=.array~new; do j=1 to p; a~append(0); b~append(0); end; sums[label]=a; sums2[label]=b
    end
    counts[label]=counts[label]+1; a=sums[label]; b=sums2[label]
    do j=1 to p; x=row[j]+0; a[j]=a[j]+x; b[j]=b[j]+x*x; end
  end
  labels=counts~allIndexes; labels~sort; means=.directory~new; variances=.directory~new; priors=.directory~new; floor=self~at('varianceFloor')
  do classLabel over labels
    n=counts[classLabel]; ma=.array~new; va=.array~new; a=sums[classLabel]; b=sums2[classLabel]
    do j=1 to p
      mean=a[j]/n; variance=(b[j]/n)-(mean*mean); if variance<floor then variance=floor
      ma~append(mean); va~append(variance)
    end
    means[classLabel]=.MLFrozenVector~new(ma); variances[classLabel]=.MLFrozenVector~new(va); priors[classLabel]=n/dataset~sampleCount
  end
  c=.directory~new; c['labels']=.MLFrozenVector~new(labels); c['means']=.MLFrozenMap~new(means); c['variances']=.MLFrozenMap~new(variances); c['priors']=.MLFrozenMap~new(priors)
  c['featureCount']=p; c['samples']=dataset~sampleCount; c['datasetId']=dataset~id; c['fitted']=.true
  return self~mutate(c,'FIT_GAUSSIAN_NB')
::method logScores
  use strict arg row
  if \self~at('fitted') then raise syntax 88.900 array('Gaussian NB is not fitted')
  if row~items<>self~at('featureCount') then raise syntax 88.900 array('Gaussian NB row width mismatch')
  labels=self~at('labels'); means=self~at('means'); variances=self~at('variances'); priors=self~at('priors'); out=.directory~new
  numeric digits 40
  do classLabel over labels~toArray
    score=.MLNumerics~ln(priors[classLabel]); m=means[classLabel]; v=variances[classLabel]
    do j=1 to row~items
      d=(row[j]+0)-(m[j]+0); score=score-.5*.MLNumerics~ln(v[j])-(d*d)/(2*v[j])
    end
    out[classLabel]=score
  end
  return out
::method predict
  use strict arg row
  scores=self~logScores(row); labels=self~at('labels'); best=''; bestScore=0; first=.true
  do classLabel over labels~toArray
    if first | scores[classLabel]>bestScore then do; best=classLabel; bestScore=scores[classLabel]; first=.false; end
  end
  return best

::class MLDecisionNode public
::method init
  expose leaf label featureIndex threshold left right sampleCount impurity
  use strict arg leafValue,labelValue=.nil,featureIndexValue=0,thresholdValue=0,leftValue=.nil,rightValue=.nil,sampleCountValue=0,impurityValue=0
  leaf=leafValue; label=labelValue; featureIndex=featureIndexValue; threshold=thresholdValue; left=leftValue; right=rightValue; sampleCount=sampleCountValue; impurity=impurityValue
::method isLeaf; expose leaf; return leaf
::method label; expose label; return label
::method featureIndex; expose featureIndex; return featureIndex
::method threshold; expose threshold; return threshold
::method left; expose left; return left
::method right; expose right; return right
::method sampleCount; expose sampleCount; return sampleCount
::method impurity; expose impurity; return impurity
::method canonicalText
  expose leaf label featureIndex threshold left right sampleCount impurity
  if leaf then return 'LEAF='||label||'|n='||sampleCount||'|gini='||impurity
  return 'NODE=f'||featureIndex||'<='||threshold||'|n='||sampleCount||'|gini='||impurity||'|L={'||left~canonicalText||'}|R={'||right~canonicalText||'}'

::class MLNumericComparator public
::method compare
  use strict arg a,b
  if a+0<b+0 then return -1
  if a+0>b+0 then return 1
  return 0

::class MLDecisionTreeClassifier subclass MLDriveableObject public
::method init
  use strict arg stableId='DECISION_TREE',maxDepth=5,minSamplesSplit=2,minGain=1E-12
  if maxDepth<1 | minSamplesSplit<2 | minGain<0 then raise syntax 88.900 array('invalid decision-tree policy')
  initial=.directory~new; initial['fitted']=.false; initial['maxDepth']=maxDepth; initial['minSamplesSplit']=minSamplesSplit; initial['minGain']=minGain
  self~init:super(stableId,'DECISION_TREE_CLASSIFIER',initial)
::method setPolicy
  use strict arg maxDepth,minSamplesSplit=2,minGain=1E-12
  if maxDepth<1 | minSamplesSplit<2 | minGain<0 then raise syntax 88.900 array('invalid decision-tree policy')
  c=.directory~new; c['maxDepth']=maxDepth; c['minSamplesSplit']=minSamplesSplit; c['minGain']=minGain; return self~mutate(c,'TREE_POLICY')
::method fit
  use strict arg dataset
  if dataset~sampleCount<1 then raise syntax 88.900 array('cannot fit decision tree on empty dataset')
  indices=.array~new; do i=1 to dataset~sampleCount; indices~append(i); end
  root=self~buildNode(dataset,indices,0)
  c=.directory~new; c['root']=root; c['featureCount']=dataset~featureCount; c['samples']=dataset~sampleCount; c['datasetId']=dataset~id; c['fitted']=.true
  return self~mutate(c,'FIT_DECISION_TREE')
::method root
  if \self~at('fitted') then raise syntax 88.900 array('decision tree is not fitted')
  return self~at('root')
::method predict
  use strict arg row
  if \self~at('fitted') then raise syntax 88.900 array('decision tree is not fitted')
  if row~items<>self~at('featureCount') then raise syntax 88.900 array('decision-tree row width mismatch')
  node=self~at('root')
  do while \node~isLeaf
    if row[node~featureIndex]+0<=node~threshold then node=node~left; else node=node~right
  end
  return node~label
::method buildNode private
  use strict arg dataset,indices,depth
  impurity=self~gini(dataset,indices); majority=self~majorityLabel(dataset,indices)
  if impurity=0 | depth>=self~at('maxDepth') | indices~items<self~at('minSamplesSplit') then return .MLDecisionNode~new(.true,majority,0,0,.nil,.nil,indices~items,impurity)
  bestGain=-1; bestFeature=0; bestThreshold=0; bestLeft=.nil; bestRight=.nil
  do feature=1 to dataset~featureCount
    values=.array~new; do idx over indices; row=dataset~row(idx); values~append(row[feature]+0); end
    values~sortWith(.MLNumericComparator~new)
    do pos=1 to values~items-1
      if values[pos]=values[pos+1] then iterate
      threshold=(values[pos]+values[pos+1])/2; left=.array~new; right=.array~new
      do idx over indices
        row=dataset~row(idx); if row[feature]+0<=threshold then left~append(idx); else right~append(idx)
      end
      if left~items=0 | right~items=0 then iterate
      weighted=(left~items/indices~items)*self~gini(dataset,left)+(right~items/indices~items)*self~gini(dataset,right)
      gain=impurity-weighted
      if gain>bestGain | (gain=bestGain & (bestFeature=0 | feature<bestFeature | (feature=bestFeature & threshold<bestThreshold))) then do
        bestGain=gain; bestFeature=feature; bestThreshold=threshold; bestLeft=left; bestRight=right
      end
    end
  end
  if bestFeature=0 | bestGain<self~at('minGain') then return .MLDecisionNode~new(.true,majority,0,0,.nil,.nil,indices~items,impurity)
  leftNode=self~buildNode(dataset,bestLeft,depth+1); rightNode=self~buildNode(dataset,bestRight,depth+1)
  return .MLDecisionNode~new(.false,.nil,bestFeature,bestThreshold,leftNode,rightNode,indices~items,impurity)
::method gini private
  use strict arg dataset,indices
  if indices~items=0 then return 0
  counts=.directory~new; do idx over indices; y=dataset~target(idx); if \counts~hasIndex(y) then counts[y]=0; counts[y]=counts[y]+1; end
  numeric digits 40; sumSq=0; do y over counts~allIndexes; p=counts[y]/indices~items; sumSq=sumSq+p*p; end
  return 1-sumSq
::method majorityLabel private
  use strict arg dataset,indices
  counts=.directory~new; do idx over indices; y=dataset~target(idx); if \counts~hasIndex(y) then counts[y]=0; counts[y]=counts[y]+1; end
  labels=counts~allIndexes; labels~sort; best=labels[1]; bestCount=-1
  do y over labels; if counts[y]>bestCount then do; best=y; bestCount=counts[y]; end; end
  return best

::class MLKMeans subclass MLDriveableObject public
::method init
  use strict arg stableId='KMEANS',k=2,maxIterations=100,tolerance=1E-9
  if k<1 | maxIterations<1 | tolerance<0 then raise syntax 88.900 array('invalid k-means policy')
  initial=.directory~new; initial['fitted']=.false; initial['k']=k; initial['maxIterations']=maxIterations; initial['tolerance']=tolerance
  self~init:super(stableId,'KMEANS',initial)
::method setPolicy
  use strict arg k,maxIterations=100,tolerance=1E-9
  if k<1 | maxIterations<1 | tolerance<0 then raise syntax 88.900 array('invalid k-means policy')
  c=.directory~new; c['k']=k; c['maxIterations']=maxIterations; c['tolerance']=tolerance; return self~mutate(c,'KMEANS_POLICY')
::method fit
  use strict arg dataset
  n=dataset~sampleCount; p=dataset~featureCount; k=self~at('k')
  if n<k then raise syntax 88.900 array('k-means k exceeds sample count')
  if p<1 then raise syntax 88.900 array('k-means requires at least one feature')
  centroids=self~initialCentroids(dataset,k); assignments=.array~new; iterations=0; tol2=self~at('tolerance')*self~at('tolerance')
  do iter=1 to self~at('maxIterations')
    iterations=iter; assignments=self~assign(dataset,centroids); newCentroids=self~recompute(dataset,assignments,centroids,k,p)
    maxShift=0; do cidx=1 to k; d=.MLNumerics~squaredDistance(centroids[cidx],newCentroids[cidx]); if d>maxShift then maxShift=d; end
    centroids=newCentroids
    if maxShift<=tol2 then leave
  end
  assignments=self~assign(dataset,centroids); inertia=0
  do i=1 to n; row=dataset~row(i); cidx=assignments[i]; inertia=inertia+.MLNumerics~squaredDistance(row,centroids[cidx]); end
  frozenCentroids=.array~new; do c over centroids; frozenCentroids~append(.MLFrozenVector~new(c)); end
  c=.directory~new; c['centroids']=.MLFrozenVector~new(frozenCentroids); c['assignments']=.MLFrozenVector~new(assignments); c['inertia']=inertia; c['iterations']=iterations
  c['featureCount']=p; c['samples']=n; c['datasetId']=dataset~id; c['fitted']=.true
  return self~mutate(c,'FIT_KMEANS')
::method centroids
  if \self~at('fitted') then raise syntax 88.900 array('k-means is not fitted')
  return self~at('centroids')
::method assignments
  if \self~at('fitted') then raise syntax 88.900 array('k-means is not fitted')
  return self~at('assignments')
::method inertia
  if \self~at('fitted') then raise syntax 88.900 array('k-means is not fitted')
  return self~at('inertia')
::method predict
  use strict arg row
  if \self~at('fitted') then raise syntax 88.900 array('k-means is not fitted')
  if row~items<>self~at('featureCount') then raise syntax 88.900 array('k-means row width mismatch')
  centroids=self~at('centroids'); best=1; bestD=.MLNumerics~squaredDistance(row,centroids[1]~toArray)
  do i=2 to centroids~items; d=.MLNumerics~squaredDistance(row,centroids[i]~toArray); if d<bestD then do; best=i; bestD=d; end; end
  return best
::method initialCentroids private
  use strict arg dataset,k
  centroids=.array~new; centroids~append(dataset~row(1))
  do while centroids~items<k
    bestIdx=0; bestDistance=-1
    do i=1 to dataset~sampleCount
      row=dataset~row(i); minDistance=-1
      do c over centroids
        d=.MLNumerics~squaredDistance(row,c); if minDistance<0 | d<minDistance then minDistance=d
      end
      if minDistance>bestDistance then do; bestDistance=minDistance; bestIdx=i; end
    end
    centroids~append(dataset~row(bestIdx))
  end
  return centroids
::method assign private
  use strict arg dataset,centroids
  out=.array~new
  do i=1 to dataset~sampleCount
    row=dataset~row(i); best=1; bestD=.MLNumerics~squaredDistance(row,centroids[1])
    do cidx=2 to centroids~items; d=.MLNumerics~squaredDistance(row,centroids[cidx]); if d<bestD then do; best=cidx; bestD=d; end; end
    out~append(best)
  end
  return out
::method recompute private
  use strict arg dataset,assignments,oldCentroids,k,p
  sums=.array~new; counts=.array~new
  do cidx=1 to k; a=.array~new; do j=1 to p; a~append(0); end; sums~append(a); counts~append(0); end
  do i=1 to dataset~sampleCount
    cidx=assignments[i]; row=dataset~row(i); a=sums[cidx]; counts[cidx]=counts[cidx]+1; do j=1 to p; a[j]=a[j]+row[j]; end
  end
  out=.array~new
  do cidx=1 to k
    if counts[cidx]=0 then out~append(.MLNumerics~copyArray(oldCentroids[cidx]))
    else do; a=.array~new; do j=1 to p; a~append(sums[cidx][j]/counts[cidx]); end; out~append(a); end
  end
  return out

::class MLPrincipalComponentAnalysis subclass MLDriveableObject public
::method init
  use strict arg stableId='PCA',componentCount=2,maxIterations=150,tolerance=1E-12
  if componentCount<1 | maxIterations<1 | tolerance<0 then raise syntax 88.900 array('invalid PCA policy')
  initial=.directory~new; initial['fitted']=.false; initial['componentCount']=componentCount; initial['maxIterations']=maxIterations; initial['tolerance']=tolerance
  self~init:super(stableId,'PCA',initial)
::method setPolicy
  use strict arg componentCount,maxIterations=150,tolerance=1E-12
  if componentCount<1 | maxIterations<1 | tolerance<0 then raise syntax 88.900 array('invalid PCA policy')
  c=.directory~new; c['componentCount']=componentCount; c['maxIterations']=maxIterations; c['tolerance']=tolerance; return self~mutate(c,'PCA_POLICY')
::method fit
  use strict arg dataset
  n=dataset~sampleCount; p=dataset~featureCount; requested=self~at('componentCount')
  if n<2 | p<1 then raise syntax 88.900 array('PCA requires at least two samples and one feature')
  if requested>p then raise syntax 88.900 array('PCA component count exceeds feature count')
  numeric digits 40
  means=.array~new
  do j=1 to p; s=0; do i=1 to n; row=dataset~row(i); s=s+row[j]; end; means~append(s/n); end
  covariance=.array~new
  do a=1 to p
    r=.array~new
    do b=1 to p
      s=0; do i=1 to n; row=dataset~row(i); s=s+(row[a]-means[a])*(row[b]-means[b]); end; r~append(s/(n-1))
    end
    covariance~append(r)
  end
  originalTrace=0; do j=1 to p; originalTrace=originalTrace+covariance[j][j]; end
  work=self~copyMatrix(covariance); components=.array~new; eigenvalues=.array~new
  do comp=1 to requested
    v=.array~new; do j=1 to p; v~append(1+(comp*j)/(p+1)); end; v=.MLNumerics~normalise(v)
    if v==.nil then do; v=.array~new; do j=1 to p; if j=comp then v~append(1); else v~append(0); end; end
    do iter=1 to self~at('maxIterations')
      w=self~matVec(work,v); w=self~orthogonalise(w,components); next=.MLNumerics~normalise(w)
      if next==.nil then leave
      delta=0; do j=1 to p; d=next[j]-v[j]; delta=delta+d*d; end
      v=next; if delta<=self~at('tolerance')*self~at('tolerance') then leave
    end
    w=self~matVec(work,v); eigen=.MLNumerics~dot(v,w); if eigen<0 & abs(eigen)<1E-18 then eigen=0
    components~append(.MLFrozenVector~new(v)); eigenvalues~append(eigen)
    do a=1 to p; do b=1 to p; work[a][b]=work[a][b]-eigen*v[a]*v[b]; end; end
  end
  ratios=.array~new; do e over eigenvalues; if originalTrace=0 then ratios~append(0); else ratios~append(e/originalTrace); end
  c=.directory~new; c['means']=.MLFrozenVector~new(means); c['components']=.MLFrozenVector~new(components); c['eigenvalues']=.MLFrozenVector~new(eigenvalues); c['explainedVarianceRatio']=.MLFrozenVector~new(ratios)
  c['featureCount']=p; c['samples']=n; c['datasetId']=dataset~id; c['fitted']=.true
  return self~mutate(c,'FIT_PCA')
::method components
  if \self~at('fitted') then raise syntax 88.900 array('PCA is not fitted')
  return self~at('components')
::method explainedVarianceRatio
  if \self~at('fitted') then raise syntax 88.900 array('PCA is not fitted')
  return self~at('explainedVarianceRatio')
::method transformRow
  use strict arg row
  if \self~at('fitted') then raise syntax 88.900 array('PCA is not fitted')
  if row~items<>self~at('featureCount') then raise syntax 88.900 array('PCA row width mismatch')
  means=self~at('means'); centered=.array~new; do j=1 to row~items; centered~append(row[j]-means[j]); end
  out=.array~new; comps=self~at('components'); do comp over comps~toArray; out~append(.MLNumerics~dot(centered,comp~toArray)); end; return out
::method transform
  use strict arg dataset,newId=''
  rows=.array~new; do i=1 to dataset~sampleCount; rows~append(self~transformRow(dataset~row(i))); end
  if newId='' then newId=dataset~id||':PCA'
  names=.array~new; do i=1 to self~at('components')~items; names~append('PC'||i); end
  if dataset~provenance==.nil then prov=.MLDatasetProvenance~new('','','','',dataset~id,'PCA','TRANSFORMED')
  else prov=dataset~provenance~derive(dataset~id,'PCA','TRANSFORMED')
  return .MLDataset~new(rows,dataset~targets,names,newId,prov,dataset~sampleIds)
::method matVec private
  use strict arg matrix,v
  out=.array~new; do i=1 to matrix~items; s=0; do j=1 to v~items; s=s+matrix[i][j]*v[j]; end; out~append(s); end; return out
::method orthogonalise private
  use strict arg vector,components
  out=.MLNumerics~copyArray(vector)
  do comp over components
    basis=comp~toArray; projection=.MLNumerics~dot(out,basis); do j=1 to out~items; out[j]=out[j]-projection*basis[j]; end
  end
  return out
::method copyMatrix private
  use strict arg source
  out=.array~new; do row over source; out~append(.MLNumerics~copyArray(row)); end; return out

::requires "MLCore.cls"
::requires "MLStandard.cls"
