/* Apron SLAM v0.1-dev4 — ephemeral, multi-hypothesis road/cuboid fit.
 * NO plate text, crops, images, frames, OCR, face data or persistence.
 * Maths owns physical projection and transcendental functions in the
 * ApronRoadGeometry dependency. This class uses squared pixel residuals
 * only: no substitute Maths package or unqualified probabilities.
 */
::options digits 30

::class ApronCalibrationSample public
::attribute ptsUs get
::attribute sigmaPixels get
::attribute imageWidth get
::attribute imageHeight get
::method init
  expose ptsUs sigmaPixels imageWidth imageHeight rectangle
  use strict arg sourcePts,sourceBox,w,h,sigma=3
  if \datatype(sourcePts,'W') | sourcePts<0 | -
     \datatype(w,'W') | \datatype(h,'W') | w<1 | h<1 | -
     \datatype(sigma,'N') | sigma<.25 | sigma>100 then -
    raise syntax 88.900 array('invalid source-time box sample')
  if \sourceBox~isA(.Array) | sourceBox~items<>4 then -
    raise syntax 88.900 array('XYWH Array required')
  do value over sourceBox
    if \datatype(value,'N') then raise syntax 88.900 array('numeric bounding box required')
  end
  if sourceBox[3]<=0 | sourceBox[4]<=0 | sourceBox[1]<0 | sourceBox[2]<0 | -
     sourceBox[1]+sourceBox[3]>w | sourceBox[2]+sourceBox[4]>h then -
    raise syntax 88.900 array('observed box must fit source image')
  ptsUs=sourcePts+0; sigmaPixels=sigma+0;imageWidth=w;imageHeight=h
  rectangle=.array~of(sourceBox[1]+0,sourceBox[2]+0,sourceBox[3]+0,sourceBox[4]+0)
::method box
  expose rectangle
  return .array~of(rectangle[1],rectangle[2],rectangle[3],rectangle[4])

::class ApronRoadAnchor public
::attribute worldX get
::attribute sigmaPixels get
::attribute basis get
::method init
  expose worldX nearPx farPx sigmaPixels basis
  use strict arg x,near,far,sigma=3,origin='ESTIMATED'
  if \datatype(x,'N') | \datatype(sigma,'N') | sigma<.25 | sigma>100 then -
    raise syntax 88.900 array('invalid road anchor values')
  if \near~isA(.Array) | \far~isA(.Array) | near~items<>2 | far~items<>2 then -
    raise syntax 88.900 array('road anchor near/far must be pixel pairs')
  do v over near
    if \datatype(v,'N') then raise syntax 88.900 array('near road point must be numeric')
  end
  do v over far
    if \datatype(v,'N') then raise syntax 88.900 array('far road point must be numeric')
  end
  origin=origin~upper
  if origin<>'ESTIMATED' & origin<>'SURVEYED' then -
    raise syntax 88.900 array('road anchor provenance must be ESTIMATED or SURVEYED')
  worldX=x+0;nearPx=.array~of(near[1]+0,near[2]+0)
  farPx=.array~of(far[1]+0,far[2]+0);sigmaPixels=sigma+0;basis=origin
::method near
  expose nearPx
  return .array~of(nearPx[1],nearPx[2])
::method far
  expose farPx
  return .array~of(farPx[1],farPx[2])

::class ApronCalibrationTrack public
::attribute count get
::attribute surveyedAnchorCount get
::attribute estimatedAnchorCount get
::attribute startPtsUs get
::method init
  expose sourceToken trackToken frames anchors closed count surveyedAnchorCount estimatedAnchorCount startPtsUs lastPtsUs
  use strict arg source,track
  if source='' | track='' then raise syntax 88.900 array('opaque source and track tokens required')
  sourceToken=source;trackToken=track;frames=.array~new;anchors=.array~new
  closed=.false;count=0;surveyedAnchorCount=0;estimatedAnchorCount=0
  startPtsUs=.nil;lastPtsUs=.nil
::method add
  expose frames closed count lastPtsUs startPtsUs
  use strict arg item
  if closed | \item~isA(.ApronCalibrationSample) then -
    raise syntax 88.900 array('track closed or non-sample admission')
  if lastPtsUs\==.nil then do
    if item~ptsUs<=lastPtsUs then raise syntax 88.900 array('non-monotonic source PTS')
    if item~ptsUs-lastPtsUs>1000000 then -
      raise syntax 88.900 array('gap greater than 1 second: begin new track')
    if item~imageWidth<>frames[1]~imageWidth | item~imageHeight<>frames[1]~imageHeight then -
      raise syntax 88.900 array('image geometry changed across a track')
  end
  if count>=512 then raise syntax 88.900 array('ephemeral track frame cap')
  if count=0 then startPtsUs=item~ptsUs
  lastPtsUs=item~ptsUs;frames~append(item);count+=1
  return self
::method addAnchor
  expose anchors closed surveyedAnchorCount estimatedAnchorCount
  use strict arg anchor
  if closed | \anchor~isA(.ApronRoadAnchor) then -
    raise syntax 88.900 array('track closed or invalid road anchor')
  if anchors~items>=32 then raise syntax 88.900 array('ephemeral road anchor cap')
  anchors~append(anchor)
  if anchor~basis='SURVEYED' then surveyedAnchorCount+=1
  else estimatedAnchorCount+=1
  return self
::method samples
  expose frames closed
  if closed then raise syntax 88.900 array('track closed')
  out=.array~new
  do f over frames; out~append(f);end
  return out
::method anchors
  expose anchors closed
  if closed then raise syntax 88.900 array('track closed')
  out=.array~new
  do a over anchors; out~append(a);end
  return out
::method spanUs
  expose count startPtsUs lastPtsUs
  if count=0 then return 0
  return lastPtsUs-startPtsUs
::method close
  expose sourceToken trackToken frames anchors closed count surveyedAnchorCount estimatedAnchorCount startPtsUs lastPtsUs
  frames=.array~new;anchors=.array~new;sourceToken='';trackToken=''
  count=0;surveyedAnchorCount=0;estimatedAnchorCount=0
  startPtsUs=.nil;lastPtsUs=.nil;closed=.true
  return self

::class ApronRoadHypothesis public
::attribute label get
::attribute scene get
::method init
  expose label scene
  use strict arg title,model
  if title='' | \model~isA(.ApronRoadScene) then -
    raise syntax 88.900 array('named ApronRoadScene hypothesis required')
  label=title;scene=model

::class ApronRoadFitScore public
::attribute label get
::attribute normalizedCost get
::attribute boxCost get
::attribute roadCost get
::attribute frameCount get
::attribute roadAnchorCount get
::method init
  expose label normalizedCost boxCost roadCost frameCount roadAnchorCount
  use strict arg title,total,box,road,frames,anchors
  label=title;normalizedCost=total;boxCost=box;roadCost=road
  frameCount=frames;roadAnchorCount=anchors

::class ApronRoadFitScoreComparator public
::method compare
  use strict arg a,b
  if a~normalizedCost<b~normalizedCost then return -1
  if a~normalizedCost>b~normalizedCost then return 1
  if a~label<b~label then return -1
  if a~label>b~label then return 1
  return 0

::class ApronCalibrationResult public
::attribute status get
::attribute reason get
::attribute scores get
::method init
  expose status reason scores
  use strict arg resultStatus,resultReason,ordered
  status=resultStatus;reason=resultReason;scores=ordered
::method best
  expose scores
  if scores~items=0 then return .nil
  return scores[1]
::method runnerUp
  expose scores
  if scores~items<2 then return .nil
  return scores[2]

::class ApronRoadCalibrator public
::method evaluate
  use strict arg hypotheses,track,maximumSigma2=9,nearTieCost=.25
  if \hypotheses~isA(.Array) | hypotheses~items=0 | -
     \track~isA(.ApronCalibrationTrack) | -
     \datatype(maximumSigma2,'N') | maximumSigma2<=0 | -
     \datatype(nearTieCost,'N') | nearTieCost<0 then -
    raise syntax 88.900 array('calibration requires hypotheses, track and positive policy')
  frames=track~samples;anchors=track~anchors
  if frames~items<4 | track~spanUs<250000 then -
    return .ApronCalibrationResult~new('INSUFFICIENT','at least four source frames spanning 0.25 s required',.array~new)
  results=.array~new
  labels=.directory~new
  do h over hypotheses
    if \h~isA(.ApronRoadHypothesis) then raise syntax 88.900 array('non-hypothesis in candidate set')
    if labels~hasIndex(h~label) then raise syntax 88.900 array('duplicate hypothesis label')
    labels[h~label]=1
    model=h~scene
    if model~camera~width<>frames[1]~imageWidth | model~camera~height<>frames[1]~imageHeight then -
      raise syntax 88.900 array('model/source image dimensions differ')
    boxSum=0
    do f over frames
      t=(f~ptsUs-track~startPtsUs)/1000000
      residual=model~boxResidualSquared(t,f~box)
      boxSum=boxSum+residual/(4*f~sigmaPixels*f~sigmaPixels)
    end
    boxMean=boxSum/frames~items
    roadSum=0
    do a over anchors
      predicted=model~roadEdgesAt(a~worldX)
      near=a~near;far=a~far
      do j=1 to 2
        dn=predicted[1][j]-near[j];df=predicted[2][j]-far[j]
        roadSum=roadSum+(dn*dn+df*df)/(4*a~sigmaPixels*a~sigmaPixels)
      end
    end
    roadMean=0
    if anchors~items>0 then roadMean=roadSum/anchors~items
    /* Road and box each have an independent block average. A hundred
       correlated frames must not drown one independently surveyed anchor. */
    combined=boxMean
    if anchors~items>0 then combined=(boxMean+roadMean)/2
    results~append(.ApronRoadFitScore~new(h~label,combined,boxMean,roadMean,frames~items,anchors~items))
  end
  results~sortWith(.ApronRoadFitScoreComparator~new)
  best=results[1]
  if best~normalizedCost>maximumSigma2 then -
    return .ApronCalibrationResult~new('HIGH_RESIDUAL','none of the tested camera/box models explains the observations',results)
  if results~items>1 then do
    if results[2]~normalizedCost-best~normalizedCost<=nearTieCost then -
      return .ApronCalibrationResult~new('AMBIGUOUS','multiple tested models fit similarly; not a metric calibration',results)
  end
  if track~surveyedAnchorCount=0 then -
    return .ApronCalibrationResult~new('UNANCHORED','no independently surveyed world-to-image road anchor; provisional fit only',results)
  return .ApronCalibrationResult~new('MODEL_CONSISTENT','best tested hypothesis matches surveyed anchors; not a verified absolute pose',results)

::class ApronSamplingVerdict public
::attribute status get
::attribute characterWidthSquared get
::attribute strokeWidthSquared get
::attribute exposureSmearSquared get
::method init
  expose status characterWidthSquared strokeWidthSquared exposureSmearSquared
  use strict arg state,glyphW2,strokeW2,smear2
  status=state;characterWidthSquared=glyphW2;strokeWidthSquared=strokeW2;exposureSmearSquared=smear2

::class ApronPlateSamplingGate public
::method evaluate
  use strict arg scene,timeSeconds,exposureUs=.nil
  if \scene~isA(.ApronRoadScene) then raise syntax 88.900 array('ApronRoadScene required')
  widthHeight=scene~platePixelDimensionsSquared(timeSeconds)
  /* Character body width approx 50 mm and character stroke 14 mm,
     scaled from the measured 520 mm plate plane. These are conservative
     square-pixel sampling tests, not an ANPR recall probability. */
  charW2=widthHeight[1]*(.050/.520)**2
  strokeW2=widthHeight[1]*(.014/.520)**2
  if charW2<25 | strokeW2<1 then -
    return .ApronSamplingVerdict~new('UNDERSAMPLED',charW2,strokeW2,.nil)
  if exposureUs==.nil then -
    return .ApronSamplingVerdict~new('EXPOSURE_UNKNOWN',charW2,strokeW2,.nil)
  smear=scene~plateExposureDisplacement(timeSeconds,exposureUs)
  smear2=smear[1]*smear[1]+smear[2]*smear[2]
  if smear2>charW2 then -
    return .ApronSamplingVerdict~new('MOTION_DOMINATED',charW2,strokeW2,smear2)
  return .ApronSamplingVerdict~new('GEOMETRICALLY_SAMPLED',charW2,strokeW2,smear2)

::requires 'ApronRoadGeometry.cls'
