/* ooRexx Vision 3D Reconstruction v0.1-dev5
 *
 * Semantic architectural priors and metric-scale refinement.
 *
 * This layer is deliberately subordinate to observed geometry.  It allows a
 * reconstruction to say "this looks like a UK double socket" or "this opening
 * is consistent with a modern internal door" and use that as metric evidence
 * without promoting the guess to direct observation.
 *
 * Dimensions in this file are metres.  Scene lengths are arbitrary common-
 * floor / reconstruction units until a scale solution is applied.
 */

::class VisionSemanticEvidenceGrade public
::method directObservation class; return 'DIRECT_OBSERVATION'
::method highConfidenceGuess class; return 'HIGH_CONFIDENCE_SEMANTIC_GUESS'
::method architecturalPrior class; return 'ARCHITECTURAL_PRIOR'
::method weakGuess class; return 'WEAK_GUESS'

::class VisionMetricPriorKind public
::method nominal class; return 'NOMINAL'
::method minimum class; return 'MINIMUM'
::method maximum class; return 'MAXIMUM'
::method range class; return 'RANGE'
::method contextualRange class; return 'CONTEXTUAL_RANGE'

::class VisionMetricPriorStrength public
::method bound class; return 'BOUND'
::method approximate class; return 'APPROXIMATE'
::method contextual class; return 'CONTEXTUAL'

::class VisionDimensionPrior public
::method init
  expose name kind nominal minimum maximum units strength note
  use strict arg name,kind,nominal=.nil,minimum=.nil,maximum=.nil,units='m',strength='APPROXIMATE',note=''
  if name='' then raise syntax 40.900 array('dimension prior name required')
  select
    when kind=.VisionMetricPriorKind~nominal then do
      if nominal==.nil | nominal<=0 then raise syntax 40.900 array('nominal prior requires positive nominal value')
    end
    when kind=.VisionMetricPriorKind~minimum then do
      if minimum==.nil | minimum<=0 then raise syntax 40.900 array('minimum prior requires positive minimum value')
    end
    when kind=.VisionMetricPriorKind~maximum then do
      if maximum==.nil | maximum<=0 then raise syntax 40.900 array('maximum prior requires positive maximum value')
    end
    when kind=.VisionMetricPriorKind~range | kind=.VisionMetricPriorKind~contextualRange then do
      if minimum==.nil | maximum==.nil | minimum<=0 | maximum<minimum then raise syntax 40.900 array('range prior requires valid positive minimum/maximum')
    end
    otherwise raise syntax 40.900 array('unknown dimension prior kind: ' || kind)
  end
::attribute name get
::attribute kind get
::attribute nominal get
::attribute minimum get
::attribute maximum get
::attribute units get
::attribute strength get
::attribute note get

::method nominal class
  use strict arg name,value,note='',strength='APPROXIMATE'
  return self~new(name,.VisionMetricPriorKind~nominal,value,.nil,.nil,'m',strength,note)
::method minimum class
  use strict arg name,value,note='',strength='BOUND'
  return self~new(name,.VisionMetricPriorKind~minimum,.nil,value,.nil,'m',strength,note)
::method range class
  use strict arg name,minimum,maximum,note='',strength='APPROXIMATE'
  return self~new(name,.VisionMetricPriorKind~range,.nil,minimum,maximum,'m',strength,note)
::method contextualRange class
  use strict arg name,minimum,maximum,note=''
  return self~new(name,.VisionMetricPriorKind~contextualRange,.nil,minimum,maximum,'m',.VisionMetricPriorStrength~contextual,note)

::class VisionArchitecturalPrior public
::method init
  expose priorId label category dimensions note
  use strict arg priorId,label,category,note=''
  if priorId='' then raise syntax 40.900 array('architectural prior id required')
  dimensions=.directory~new
::attribute priorId get
::attribute label get
::attribute category get
::attribute dimensions get
::attribute note get
::method addDimension
  expose dimensions
  use strict arg prior
  if \prior~isA(.VisionDimensionPrior) then raise syntax 40.900 array('VisionDimensionPrior required')
  dimensions[prior~name]=prior
  return self
::method dimension
  expose dimensions
  use strict arg name
  if dimensions~hasIndex(name) then return dimensions[name]
  return .nil

/* User-supplied practical UK domestic priors.  They are reconstruction aids,
 * not building-code claims and not universal truths. */
::class VisionUKDomesticPriorCatalog public
::method init
  expose priors relations
  priors=.directory~new; relations=.array~new

  p=.VisionArchitecturalPrior~new('UK.INTERNAL_DOOR.MODERN','Modern internal door','OPENING','Practical modern-door prior; historic/special doors may differ.')
  p~addDimension(.VisionDimensionPrior~minimum('WIDTH',0.76,'Practical minimum clear/leaf-width scale prior.'))
  p~addDimension(.VisionDimensionPrior~minimum('HEIGHT',1.97,'Practical minimum modern door-height prior.'))
  p~addDimension(.VisionDimensionPrior~range('THICKNESS',0.04,0.05,'Ordinary internal door-leaf thickness prior.'))
  priors[p~priorId]=p

  p=.VisionArchitecturalPrior~new('UK.HALL.ORDINARY','Ordinary hall/corridor','SPACE','Hall width lower-bound prior.')
  p~addDimension(.VisionDimensionPrior~minimum('WIDTH',0.80,'Practical minimum hall width prior.'))
  priors[p~priorId]=p

  p=.VisionArchitecturalPrior~new('UK.WALL_SOCKET.DOUBLE','UK double wall socket','WALL_FIXTURE','Approximate faceplate calibration anchor.')
  p~addDimension(.VisionDimensionPrior~nominal('WIDTH',0.15,'User-supplied approximate across-faceplate width.'))
  priors[p~priorId]=p

  p=.VisionArchitecturalPrior~new('UK.LIGHT_SWITCH.SQUARE','UK square light switch','WALL_FIXTURE','Approximate square faceplate calibration anchor.')
  p~addDimension(.VisionDimensionPrior~nominal('WIDTH',0.10,'User-supplied approximate square width.'))
  p~addDimension(.VisionDimensionPrior~nominal('HEIGHT',0.10,'User-supplied approximate square height.'))
  priors[p~priorId]=p

  p=.VisionArchitecturalPrior~new('INTERIOR.CEILING.NORMAL','Ordinary interior ceiling','SPACE','Contextual range only; historic and large-volume spaces can legitimately fall outside it.')
  p~addDimension(.VisionDimensionPrior~contextualRange('HEIGHT',2.4384,3.6576,'About 8-12 ft for an ordinary interior.'))
  priors[p~priorId]=p

  p=.VisionArchitecturalPrior~new('LIGHT.BARE_BULB.TYPICAL','Typical bare lightbulb','CEILING_FIXTURE','Apply only when the bulb itself is visible, not a lampshade.')
  p~addDimension(.VisionDimensionPrior~nominal('DIAMETER',0.07,'Approximate typical bare-bulb diameter.'))
  priors[p~priorId]=p

  p=.VisionArchitecturalPrior~new('UK.RADIATOR.ORDINARY','Ordinary wall radiator','WALL_FIXTURE','Wall-offset and body-depth consistency prior.')
  p~addDimension(.VisionDimensionPrior~minimum('WALL_STANDOFF',0.025,'Radiator cannot be flush to the wall; practical minimum stand-off.'))
  p~addDimension(.VisionDimensionPrior~range('DEPTH',0.05,0.12,'Approximate body depth depending on model.'))
  priors[p~priorId]=p

  relations~append('ROOM_WIDTH_GT_HALL_WIDTH')
::attribute priors get
::attribute relations get
::method byId
  expose priors
  use strict arg priorId
  if priors~hasIndex(priorId) then return priors[priorId]
  return .nil
::method all
  expose priors
  out=.array~new
  do id over priors; out~append(priors[id]); end
  return out

/* A semantic anchor binds a visual/structural hypothesis to a prior and keeps
 * the distinction between scene units and metric priors explicit. */
::class VisionSemanticAnchor public
::method init
  expose anchorId prior evidenceGrade confidence entityRef planeRef observedDimensions sourceRefs note
  use strict arg anchorId,prior,evidenceGrade,confidence=1,entityRef='',planeRef='',note=''
  if \prior~isA(.VisionArchitecturalPrior) then raise syntax 40.900 array('VisionArchitecturalPrior required')
  if confidence<0 | confidence>1 then raise syntax 40.900 array('semantic anchor confidence must be 0..1')
  observedDimensions=.directory~new; sourceRefs=.array~new
::attribute anchorId get
::attribute prior get
::attribute evidenceGrade get
::attribute confidence get
::attribute entityRef get
::attribute planeRef get
::attribute observedDimensions get
::attribute sourceRefs get
::attribute note get
::method observeDimension
  expose observedDimensions
  use strict arg dimensionName,sceneLength
  if sceneLength<=0 then raise syntax 40.900 array('observed scene dimension must be positive')
  observedDimensions[dimensionName]=sceneLength
  return self
::method addSource
  expose sourceRefs
  use strict arg sourceRef
  sourceRefs~append(sourceRef); return self

::class VisionMetricScaleConstraint public
::method init
  expose anchorId priorId dimensionName kind strength sceneLength minScale maxScale nominalScale confidence evidenceGrade note
  use strict arg anchorId,priorId,dimensionName,kind,strength,sceneLength,minScale=.nil,maxScale=.nil,nominalScale=.nil,confidence=1,evidenceGrade='ARCHITECTURAL_PRIOR',note=''
::attribute anchorId get
::attribute priorId get
::attribute dimensionName get
::attribute kind get
::attribute strength get
::attribute sceneLength get
::attribute minScale get
::attribute maxScale get
::attribute nominalScale get
::attribute confidence get
::attribute evidenceGrade get
::attribute note get

::method fromAnchor class
  use strict arg anchor,dimensionName,applyContextual=.false
  if \anchor~isA(.VisionSemanticAnchor) then raise syntax 40.900 array('VisionSemanticAnchor required')
  if \anchor~observedDimensions~hasIndex(dimensionName) then return .nil
  priorDimension=anchor~prior~dimension(dimensionName)
  if priorDimension==.nil then return .nil
  if priorDimension~kind=.VisionMetricPriorKind~contextualRange & \applyContextual then return .nil
  sceneLength=anchor~observedDimensions[dimensionName]
  minScale=.nil; maxScale=.nil; nominalScale=.nil
  select
    when priorDimension~kind=.VisionMetricPriorKind~nominal then nominalScale=priorDimension~nominal/sceneLength
    when priorDimension~kind=.VisionMetricPriorKind~minimum then minScale=priorDimension~minimum/sceneLength
    when priorDimension~kind=.VisionMetricPriorKind~maximum then maxScale=priorDimension~maximum/sceneLength
    when priorDimension~kind=.VisionMetricPriorKind~range | priorDimension~kind=.VisionMetricPriorKind~contextualRange then do
      minScale=priorDimension~minimum/sceneLength
      maxScale=priorDimension~maximum/sceneLength
      nominalScale=((priorDimension~minimum+priorDimension~maximum)/2)/sceneLength
    end
    otherwise return .nil
  end
  return self~new(anchor~anchorId,anchor~prior~priorId,dimensionName,priorDimension~kind,priorDimension~strength,sceneLength,minScale,maxScale,nominalScale,anchor~confidence,anchor~evidenceGrade,priorDimension~note)

::class VisionMetricScaleSolution public
::method init
  expose minimumScale maximumScale nominalScale unclampedNominal confidence constraints tensions contextualApplied
  use strict arg minimumScale=0,maximumScale=.nil,nominalScale=.nil,unclampedNominal=.nil,confidence=0,constraints=.nil,tensions=.nil,contextualApplied=.false
  if constraints==.nil then constraints=.array~new
  if tensions==.nil then tensions=.array~new
::attribute minimumScale get
::attribute maximumScale get
::attribute nominalScale get
::attribute unclampedNominal get
::attribute confidence get
::attribute constraints get
::attribute tensions get
::attribute contextualApplied get
::method metricLength
  expose nominalScale
  use strict arg sceneLength
  if nominalScale==.nil then return .nil
  return sceneLength*nominalScale

/* Combines lower/upper-bound priors with approximate calibration anchors.
 * Approximate anchors contribute a weighted nominal scale but do not silently
 * become hard facts.  Contextual ceiling ranges are opt-in per space. */
::class VisionMetricScaleSolver public
::method init
  expose anchors
  anchors=.array~new
::attribute anchors get
::method addAnchor
  expose anchors
  use strict arg anchor
  if \anchor~isA(.VisionSemanticAnchor) then raise syntax 40.900 array('VisionSemanticAnchor required')
  anchors~append(anchor); return self

::method solve
  expose anchors
  use strict arg applyContextual=.false
  constraints=.array~new; tensions=.array~new
  lower=0; upper=.nil; weighted=0; weightTotal=0
  do anchor over anchors
    do dimensionName over anchor~observedDimensions
      c=.VisionMetricScaleConstraint~fromAnchor(anchor,dimensionName,applyContextual)
      if c==.nil then iterate
      constraints~append(c)
      /* Only explicit bounds constrain the solution.  Approximate ranges
       * (door-leaf thickness, radiator depth, etc.) contribute a nominal
       * estimate but remain defeasible.  Contextual ranges constrain only
       * when the caller deliberately enabled that context. */
      enforceBounds=(c~strength=.VisionMetricPriorStrength~bound) | (c~strength=.VisionMetricPriorStrength~contextual & applyContextual)
      if enforceBounds then do
        if c~minScale\==.nil then lower=max(lower,c~minScale)
        if c~maxScale\==.nil then do
          if upper==.nil then upper=c~maxScale
          else upper=min(upper,c~maxScale)
        end
      end
      if c~nominalScale\==.nil then do
        w=max(0.000001,c~confidence)
        weighted=weighted+c~nominalScale*w; weightTotal=weightTotal+w
      end
    end
  end
  if upper\==.nil then do
    if lower>upper then tensions~append('BOUND_CONFLICT:' || lower || '>' || upper)
  end
  if weightTotal>0 then rawNominal=weighted/weightTotal
  else rawNominal=.nil
  nominal=rawNominal
  if nominal==.nil then do
    if upper==.nil then do
      if lower>0 then nominal=lower
    end
    else nominal=(lower+upper)/2
  end
  if nominal\==.nil then do
    if nominal<lower then do; tensions~append('NOMINAL_BELOW_LOWER_BOUND'); nominal=lower; end
    if upper\==.nil then do
      if nominal>upper then do; tensions~append('NOMINAL_ABOVE_UPPER_BOUND'); nominal=upper; end
    end
  end
  if constraints~items=0 then confidence=0
  else do
    sum=0
    do c over constraints; sum=sum+c~confidence; end
    confidence=sum/constraints~items
  end
  return .VisionMetricScaleSolution~new(lower,upper,nominal,rawNominal,confidence,constraints,tensions,applyContextual)

/* Explicit semantic hypotheses from simple wall-rectangle shape/context.
 * This does not inspect raw pixels; upstream Vision/Line Assessment owns the
 * observation.  The classifier merely turns a described wall rectangle into
 * bounded UK-domestic hypotheses. */
::class VisionSemanticHypothesis public
::method init
  expose priorId evidenceGrade confidence reason
  use strict arg priorId,evidenceGrade,confidence,reason=''
::attribute priorId get
::attribute evidenceGrade get
::attribute confidence get
::attribute reason get

::class VisionUKWallFixtureClassifier public
::method init
  expose catalog
  use strict arg catalog=.nil
  if catalog==.nil then catalog=.VisionUKDomesticPriorCatalog~new
::attribute catalog get

::method classifyRectangle
  use strict arg width,height,wallConfidence=1,rectangleConfidence=1,patternHint=''
  out=.array~new
  if width<=0 | height<=0 then return out
  baseConfidence=min(wallConfidence,rectangleConfidence)
  ratio=width/height
  hint=translate(patternHint)
  if hint='DOUBLE_SOCKET' | hint='POWER_POINT' then do
    out~append(.VisionSemanticHypothesis~new('UK.WALL_SOCKET.DOUBLE',.VisionSemanticEvidenceGrade~highConfidenceGuess,baseConfidence,'explicit wall-fixture pattern hint'))
    return out
  end
  if hint='LIGHT_SWITCH' then do
    out~append(.VisionSemanticHypothesis~new('UK.LIGHT_SWITCH.SQUARE',.VisionSemanticEvidenceGrade~highConfidenceGuess,baseConfidence,'explicit wall-fixture pattern hint'))
    return out
  end
  /* Shape-only rules remain priors, not recognition facts. */
  if ratio>=1.35 & ratio<=2.30 then out~append(.VisionSemanticHypothesis~new('UK.WALL_SOCKET.DOUBLE',.VisionSemanticEvidenceGrade~architecturalPrior,baseConfidence,'horizontal wall rectangle consistent with a UK double socket'))
  if ratio>=0.80 & ratio<=1.25 then out~append(.VisionSemanticHypothesis~new('UK.LIGHT_SWITCH.SQUARE',.VisionSemanticEvidenceGrade~architecturalPrior,baseConfidence,'near-square wall rectangle consistent with a square light switch'))
  return out

::class VisionPlanSpace public
::method init
  expose spaceId kind widthSceneUnits depthSceneUnits ceilingHeightSceneUnits evidenceRefs
  use strict arg spaceId,kind,widthSceneUnits=.nil,depthSceneUnits=.nil,ceilingHeightSceneUnits=.nil
  evidenceRefs=.array~new
::attribute spaceId get
::attribute kind get
::attribute widthSceneUnits
::attribute depthSceneUnits
::attribute ceilingHeightSceneUnits
::attribute evidenceRefs get
::method addEvidence; expose evidenceRefs; use strict arg e; evidenceRefs~append(e); return self

::class VisionPlanOpening public
::method init
  expose openingId fromSpace toSpace widthSceneUnits heightSceneUnits thicknessSceneUnits evidenceRefs
  use strict arg openingId,fromSpace,toSpace,widthSceneUnits=.nil,heightSceneUnits=.nil,thicknessSceneUnits=.nil
  evidenceRefs=.array~new
::attribute openingId get
::attribute fromSpace get
::attribute toSpace get
::attribute widthSceneUnits
::attribute heightSceneUnits
::attribute thicknessSceneUnits
::attribute evidenceRefs get
::method addEvidence; expose evidenceRefs; use strict arg e; evidenceRefs~append(e); return self

::class VisionBuildingPlanHypothesis public
::method init
  expose planId spaces openings anchors relations scaleSolution evidenceRefs
  use strict arg planId
  spaces=.directory~new; openings=.directory~new; anchors=.array~new; relations=.array~new; evidenceRefs=.array~new; scaleSolution=.nil
::attribute planId get
::attribute spaces get
::attribute openings get
::attribute anchors get
::attribute relations get
::attribute scaleSolution
::attribute evidenceRefs get
::method addSpace; expose spaces; use strict arg s; spaces[s~spaceId]=s; return self
::method addOpening; expose openings; use strict arg o; openings[o~openingId]=o; return self
::method addAnchor; expose anchors; use strict arg a; anchors~append(a); return self
::method addRelation; expose relations; use strict arg r; relations~append(r); return self
::method addEvidence; expose evidenceRefs; use strict arg e; evidenceRefs~append(e); return self

::class VisionPlanSanityChecker public
::method check
  use strict arg plan,catalog=.nil
  if catalog==.nil then catalog=.VisionUKDomesticPriorCatalog~new
  findings=.array~new
  hallPrior=catalog~byId('UK.HALL.ORDINARY')
  hallMin=hallPrior~dimension('WIDTH')~minimum
  scale=.nil
  if plan~scaleSolution\==.nil then scale=plan~scaleSolution~nominalScale
  do id over plan~spaces
    s=plan~spaces[id]
    if translate(s~kind)='HALL' & s~widthSceneUnits\==.nil & scale\==.nil then do
      metricWidth=s~widthSceneUnits*scale
      if metricWidth<hallMin then findings~append('HALL_WIDTH_BELOW_PRIOR:' || id || ':' || metricWidth)
    end
  end
  /* Relation is scale-independent. */
  hallWidth=.nil
  do id over plan~spaces
    s=plan~spaces[id]
    if translate(s~kind)='HALL' & s~widthSceneUnits\==.nil then do; hallWidth=s~widthSceneUnits; leave; end
  end
  if hallWidth\==.nil then do
    do id over plan~spaces
      s=plan~spaces[id]
      if translate(s~kind)='ROOM' & s~widthSceneUnits\==.nil then do
        if s~widthSceneUnits<=hallWidth then findings~append('ROOM_NOT_WIDER_THAN_HALL:' || id)
      end
    end
  end
  return findings

::requires 'Vision3DStructure.cls'
