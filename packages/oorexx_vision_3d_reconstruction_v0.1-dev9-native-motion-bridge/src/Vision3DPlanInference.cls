/* ooRexx Vision 3D Reconstruction v0.1-dev6
 *
 * Constraint-driven metric floor-plan inference.
 *
 * dev6 deliberately treats architectural knowledge as defeasible evidence.
 * Geometry stays authoritative; semantic object guesses contribute scale and
 * consistency constraints, and every accepted/rejected contribution remains
 * inspectable.
 */

::class VisionPlanRelationKind public
::method adjacent class; return 'ADJACENT'
::method openingBetween class; return 'OPENING_BETWEEN'
::method widthGreaterThan class; return 'WIDTH_GREATER_THAN'
::method approximatelyOrthogonal class; return 'APPROXIMATELY_ORTHOGONAL'
::method approximatelyParallel class; return 'APPROXIMATELY_PARALLEL'
::method sameFloor class; return 'SAME_FLOOR'

::class VisionPlanRelation public
::method init
  expose relationId kind subjectRef objectRef confidence evidenceGrade evidenceRefs note
  use strict arg relationId,kind,subjectRef,objectRef,confidence=1,evidenceGrade='ARCHITECTURAL_PRIOR',note=''
  if relationId='' | subjectRef='' | objectRef='' then raise syntax 40.900 array('plan relation requires id, subject and object')
  if confidence<0 | confidence>1 then raise syntax 40.900 array('relation confidence must be 0..1')
  evidenceRefs=.array~new
::attribute relationId get
::attribute kind get
::attribute subjectRef get
::attribute objectRef get
::attribute confidence get
::attribute evidenceGrade get
::attribute evidenceRefs get
::attribute note get
::method addEvidence
  expose evidenceRefs
  use strict arg evidenceRef
  evidenceRefs~append(evidenceRef); return self

/* Metric estimates stay explicit about what is an estimate versus a bound. */
::class VisionMetricDimensionEstimate public
::method init
  expose entityRef dimensionName sceneLength metricEstimate metricMinimum metricMaximum confidence basis
  use strict arg entityRef,dimensionName,sceneLength=.nil,metricEstimate=.nil,metricMinimum=.nil,metricMaximum=.nil,confidence=0,basis=''
::attribute entityRef get
::attribute dimensionName get
::attribute sceneLength get
::attribute metricEstimate get
::attribute metricMinimum get
::attribute metricMaximum get
::attribute confidence get
::attribute basis get

::class VisionMetricEntityEstimate public
::method init
  expose entityRef entityKind dimensions evidenceRefs
  use strict arg entityRef,entityKind
  dimensions=.directory~new; evidenceRefs=.array~new
::attribute entityRef get
::attribute entityKind get
::attribute dimensions get
::attribute evidenceRefs get
::method addDimension
  expose dimensions
  use strict arg estimate
  if \estimate~isA(.VisionMetricDimensionEstimate) then raise syntax 40.900 array('VisionMetricDimensionEstimate required')
  dimensions[estimate~dimensionName]=estimate; return self
::method addEvidence
  expose evidenceRefs
  use strict arg evidenceRef
  evidenceRefs~append(evidenceRef); return self

::class VisionMetricBuildingPlan public
::method init
  expose sourcePlanId scaleSolution spaces openings topologyFindings evidenceRefs
  use strict arg sourcePlanId,scaleSolution=.nil
  spaces=.directory~new; openings=.directory~new; topologyFindings=.array~new; evidenceRefs=.array~new
::attribute sourcePlanId get
::attribute scaleSolution get
::attribute spaces get
::attribute openings get
::attribute topologyFindings get
::attribute evidenceRefs get
::method addSpace; expose spaces; use strict arg e; spaces[e~entityRef]=e; return self
::method addOpening; expose openings; use strict arg e; openings[e~entityRef]=e; return self
::method addFinding; expose topologyFindings; use strict arg f; topologyFindings~append(f); return self
::method addEvidence; expose evidenceRefs; use strict arg e; evidenceRefs~append(e); return self

/* Grade weighting is intentionally conservative: a shape/context guess may be
 * useful without becoming equivalent to a direct observation. */
::routine rx_v3_grade_weight
  use strict arg grade
  select
    when grade=.VisionSemanticEvidenceGrade~directObservation then return 1.00
    when grade=.VisionSemanticEvidenceGrade~highConfidenceGuess then return 0.85
    when grade=.VisionSemanticEvidenceGrade~architecturalPrior then return 0.55
    when grade=.VisionSemanticEvidenceGrade~weakGuess then return 0.25
    otherwise return 0.25
  end

/* Robust alternative to the dev5 weighted-average scale solver.  It first
 * selects a weighted-median nominal scale, rejects nominal anchors too far
 * from that consensus, then computes a weighted inlier mean.  Hard minimum /
 * maximum bounds are enforced separately.  No rejected semantic anchor is
 * silently discarded: it is returned in rejectedConstraints. */
::class VisionRobustMetricScaleSolution public
::method init
  expose minimumScale maximumScale nominalScale seedScale confidence constraints acceptedConstraints rejectedConstraints tensions contextualApplied
  use strict arg minimumScale=0,maximumScale=.nil,nominalScale=.nil,seedScale=.nil,confidence=0,constraints=.nil,acceptedConstraints=.nil,rejectedConstraints=.nil,tensions=.nil,contextualApplied=.false
  if constraints==.nil then constraints=.array~new
  if acceptedConstraints==.nil then acceptedConstraints=.array~new
  if rejectedConstraints==.nil then rejectedConstraints=.array~new
  if tensions==.nil then tensions=.array~new
::attribute minimumScale get
::attribute maximumScale get
::attribute nominalScale get
::attribute seedScale get
::attribute confidence get
::attribute constraints get
::attribute acceptedConstraints get
::attribute rejectedConstraints get
::attribute tensions get
::attribute contextualApplied get
::method metricLength
  expose nominalScale
  use strict arg sceneLength
  if nominalScale==.nil then return .nil
  return sceneLength*nominalScale

::class VisionRobustMetricScaleSolver public
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
  use strict arg applyContextual=.false,outlierFraction=.35
  if outlierFraction<=0 then raise syntax 40.900 array('outlierFraction must be positive')
  constraints=.array~new; candidates=.array~new; tensions=.array~new
  lower=0; upper=.nil

  do anchor over anchors
    do dimensionName over anchor~observedDimensions
      c=.VisionMetricScaleConstraint~fromAnchor(anchor,dimensionName,applyContextual)
      if c==.nil then iterate
      constraints~append(c)
      enforceBounds=(c~strength=.VisionMetricPriorStrength~bound) | (c~strength=.VisionMetricPriorStrength~contextual & applyContextual)
      if enforceBounds then do
        if c~minScale\==.nil then lower=max(lower,c~minScale)
        if c~maxScale\==.nil then do
          if upper==.nil then upper=c~maxScale
          else upper=min(upper,c~maxScale)
        end
      end
      if c~nominalScale\==.nil then do
        item=.directory~new
        item['constraint']=c
        item['scale']=c~nominalScale
        item['weight']=max(0.000001,c~confidence*rx_v3_grade_weight(c~evidenceGrade))
        candidates~append(item)
      end
    end
  end

  if upper\==.nil then do
    if lower>upper then tensions~append('BOUND_CONFLICT:' || lower || '>' || upper)
  end
  seed=.nil
  if candidates~items>0 then do
    totalWeight=0
    do item over candidates; totalWeight=totalWeight+item['weight']; end
    /* Weighted median without relying on implementation-specific sort APIs. */
    best=.nil
    do item over candidates
      below=0; above=0; s=item['scale']
      do other over candidates
        if other['scale']<s then below=below+other['weight']
        else if other['scale']>s then above=above+other['weight']
      end
      if below<=totalWeight/2 & above<=totalWeight/2 then do; best=s; leave; end
    end
    if best==.nil then best=candidates[1]['scale']
    seed=best
  end

  accepted=.array~new; rejected=.array~new; weighted=0; acceptedWeight=0; totalCandidateWeight=0
  do item over candidates
    c=item['constraint']; s=item['scale']; w=item['weight']; totalCandidateWeight=totalCandidateWeight+w
    accept=.true
    if seed\==.nil then do
      if seed>0 then do
        deviation=abs(s-seed)/seed
        if deviation>outlierFraction then accept=.false
      end
    end
    if accept then do
      accepted~append(c); weighted=weighted+s*w; acceptedWeight=acceptedWeight+w
    end
    else do
      rejected~append(c)
      tensions~append('SEMANTIC_SCALE_OUTLIER:' || c~anchorId || ':' || s)
    end
  end

  nominal=.nil
  if acceptedWeight>0 then nominal=weighted/acceptedWeight
  else if seed\==.nil then nominal=seed
  if nominal==.nil then do
    if upper==.nil then do; if lower>0 then nominal=lower; end
    else nominal=(lower+upper)/2
  end
  if nominal\==.nil then do
    if nominal<lower then do; tensions~append('NOMINAL_BELOW_LOWER_BOUND'); nominal=lower; end
    if upper\==.nil then do
      if nominal>upper then do; tensions~append('NOMINAL_ABOVE_UPPER_BOUND'); nominal=upper; end
    end
  end

  if totalCandidateWeight>0 then consensus=acceptedWeight/totalCandidateWeight
  else if constraints~items>0 then consensus=.5
  else consensus=0
  if constraints~items=0 then meanConfidence=0
  else do
    sumConfidence=0
    do c over constraints; sumConfidence=sumConfidence+c~confidence; end
    meanConfidence=sumConfidence/constraints~items
  end
  confidence=consensus*meanConfidence
  return .VisionRobustMetricScaleSolution~new(lower,upper,nominal,seed,confidence,constraints,accepted,rejected,tensions,applyContextual)

/* Converts scene-unit dimensions into metric estimates while preserving lower
 * and upper scale bounds when an exact nominal scale is not justified. */
::class VisionMetricPlanInference public
::method infer
  use strict arg plan,scaleSolution
  if \plan~isA(.VisionBuildingPlanHypothesis) then raise syntax 40.900 array('VisionBuildingPlanHypothesis required')
  metricPlan=.VisionMetricBuildingPlan~new(plan~planId,scaleSolution)
  nominal=scaleSolution~nominalScale; lower=scaleSolution~minimumScale; upper=scaleSolution~maximumScale

  do id over plan~spaces
    s=plan~spaces[id]; e=.VisionMetricEntityEstimate~new(id,'SPACE:' || s~kind)
    if s~widthSceneUnits\==.nil then e~addDimension(self~estimate(id,'WIDTH',s~widthSceneUnits,nominal,lower,upper,scaleSolution~confidence,'COMMON_FLOOR_SCALE'))
    if s~depthSceneUnits\==.nil then e~addDimension(self~estimate(id,'DEPTH',s~depthSceneUnits,nominal,lower,upper,scaleSolution~confidence,'COMMON_FLOOR_SCALE'))
    if s~ceilingHeightSceneUnits\==.nil then e~addDimension(self~estimate(id,'CEILING_HEIGHT',s~ceilingHeightSceneUnits,nominal,lower,upper,scaleSolution~confidence,'VERTICAL_SCALE_ASSUMED_SHARED'))
    do ev over s~evidenceRefs; e~addEvidence(ev); end
    metricPlan~addSpace(e)
  end

  do id over plan~openings
    o=plan~openings[id]; e=.VisionMetricEntityEstimate~new(id,'OPENING')
    if o~widthSceneUnits\==.nil then e~addDimension(self~estimate(id,'WIDTH',o~widthSceneUnits,nominal,lower,upper,scaleSolution~confidence,'COMMON_FLOOR_SCALE'))
    if o~heightSceneUnits\==.nil then e~addDimension(self~estimate(id,'HEIGHT',o~heightSceneUnits,nominal,lower,upper,scaleSolution~confidence,'VERTICAL_SCALE_ASSUMED_SHARED'))
    if o~thicknessSceneUnits\==.nil then e~addDimension(self~estimate(id,'THICKNESS',o~thicknessSceneUnits,nominal,lower,upper,scaleSolution~confidence,'COMMON_SCALE'))
    do ev over o~evidenceRefs; e~addEvidence(ev); end
    metricPlan~addOpening(e)
  end

  validator=.VisionPlanTopologyValidator~new
  do finding over validator~check(plan); metricPlan~addFinding(finding); end
  return metricPlan

::method estimate private
  use strict arg entityRef,dimensionName,sceneLength,nominal,lower,upper,confidence,basis
  metric=.nil; minMetric=.nil; maxMetric=.nil
  if nominal\==.nil then metric=sceneLength*nominal
  if lower>0 then minMetric=sceneLength*lower
  if upper\==.nil then maxMetric=sceneLength*upper
  return .VisionMetricDimensionEstimate~new(entityRef,dimensionName,sceneLength,metric,minMetric,maxMetric,confidence,basis)

/* Topology is independently testable before any metric solve.  This is
 * important for bodycam work: a wrong adjacency graph should fail before we
 * spend computation refining centimetres or meshes. */
::class VisionPlanTopologyValidator public
::method check
  use strict arg plan
  findings=.array~new
  do id over plan~openings
    o=plan~openings[id]
    if \plan~spaces~hasIndex(o~fromSpace) then findings~append('OPENING_UNKNOWN_FROM_SPACE:' || id || ':' || o~fromSpace)
    if \plan~spaces~hasIndex(o~toSpace) then findings~append('OPENING_UNKNOWN_TO_SPACE:' || id || ':' || o~toSpace)
    if o~fromSpace=o~toSpace then findings~append('OPENING_SELF_CONNECT:' || id)
  end
  /* Every declared OPENING_BETWEEN relation must correspond to an opening. */
  do rel over plan~relations
    if rel~isA(.VisionPlanRelation) & rel~kind=.VisionPlanRelationKind~openingBetween then do
      found=.false
      do id over plan~openings
        o=plan~openings[id]
        if (o~fromSpace=rel~subjectRef & o~toSpace=rel~objectRef) | (o~fromSpace=rel~objectRef & o~toSpace=rel~subjectRef) then do; found=.true; leave; end
      end
      if \found then findings~append('RELATION_WITHOUT_OPENING:' || rel~relationId)
    end
  end
  return findings

/* Consensus carrier for semantic guesses seen from multiple views/sources.
 * Corroboration raises confidence but never rewrites the evidence grade. */
::class VisionSemanticConsensus public
::method init
  expose priorId observations
  use strict arg priorId
  observations=.array~new
::attribute priorId get
::attribute observations get
::method add
  expose observations priorId
  use strict arg hypothesis,sourceRef=''
  if \hypothesis~isA(.VisionSemanticHypothesis) then raise syntax 40.900 array('VisionSemanticHypothesis required')
  if hypothesis~priorId<>priorId then raise syntax 40.900 array('semantic hypothesis prior mismatch')
  d=.directory~new; d['hypothesis']=hypothesis; d['sourceRef']=sourceRef; observations~append(d); return self
::method distinctSourceCount
  expose observations
  seen=.directory~new
  do d over observations
    s=d['sourceRef']; if s<>'' then seen[s]=1
  end
  return seen~items
::method confidence
  expose observations
  if observations~items=0 then return 0
  product=1
  do d over observations
    h=d['hypothesis']; product=product*(1-h~confidence)
  end
  /* independent-observation accumulation, capped below certainty */
  return min(.99,1-product)
::method corroborated
  return self~distinctSourceCount>=2

::requires 'Vision3DSemanticPriors.cls'
