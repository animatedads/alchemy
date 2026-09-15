/* Compile exact release graph to profile-aware runtime-neutral Wire UI artifacts. */
::class WireUICompiler subclass AlchemyObject public
::method init
  self~init:super(.WireUIDesignAlchemy~metadata("Wire UI design graph validator/compiler"))

::method compile
  use arg workspace, release
  if \release~isA(.WireUISiteRelease) | \release~isSealed then return .WireUIDesignResult~failure("RELEASE_NOT_SEALED")
  pkg=.WireUICompiledPackage~new(release~releaseId, release~version, release~ref)
  refs=release~refs
  pinned=.table~new
  do r over refs; pinned[r~key]=r; end
  /* Every exact release ref must exist with exactly the pinned content address. */
  do r over refs
    a=workspace~artifact(r~kind,r~artifactId,r~version)
    if a==.nil then return .WireUIDesignResult~failure("PINNED_ARTIFACT_MISSING",r~key)
    if r~contentAddress="" | a~ref~contentAddress \= r~contentAddress then return .WireUIDesignResult~failure("PINNED_CONTENT_MISMATCH",r~key)
  end
  /* Material and projection definitions are emitted independently; multiple versions coexist. */
  do r over refs
    a=workspace~artifact(r~kind,r~artifactId,r~version)
    select
      when r~kind="MATERIAL" then pkg~addMaterial(a~asWire)
      when r~kind="CONDITION" then pkg~addCondition(a~asWire)
      when r~kind="PRESENTATION_POLICY" then pkg~addPresentationPolicy(a~asWire)
      when r~kind="PROJECTION" then do
        er=a~elementRef; cr=a~componentRef
        if \pinned~hasIndex(er~key) then return .WireUIDesignResult~failure("PROJECTION_ELEMENT_NOT_PINNED",a~projectionId)
        if \pinned~hasIndex(cr~key) then return .WireUIDesignResult~failure("PROJECTION_COMPONENT_NOT_PINNED",a~projectionId)
        component=workspace~artifact(cr~kind,cr~artifactId,cr~version)
        d=.table~new
        d["semanticElementRef"]=er~asWire
        d["projectionRef"]=a~ref~asWire
        d["definitionId"]=a~definitionId
        d["definitionVersion"]=a~version
        d["definitionKey"]=a~definitionId"@"a~version
        d["profile"]=a~profile
        d["primitive"]=component~primitive
        d["componentRef"]=cr~asWire
        d["styleRole"]=a~styleRole
        d["materialRole"]=a~materialRole
        aw=a~asWire; d["action"]=aw["action"]; d["bindings"]=aw["bindings"]; d["resourceBindings"]=aw["resourceBindings"]
        md=.WireUIDesignUtil~copyTable(aw["metadata"])
        hints=self~compositionHints(workspace,refs,a)
        if hints~items>0 then md["compositionHints"]=hints
        d["metadata"]=md
        d["contentAddress"]=.WireUIDesignUtil~token(.WireUIDesignUtil~canonicalTable(d))
        pkg~addDefinition(d)
      end
      when r~kind="JOURNEY" then do
        if \a~isSealed then return .WireUIDesignResult~failure("JOURNEY_NOT_SEALED",a~journeyId)
        /* Compile each journey state against every profile represented in the pinned projections.
           Conditional-only placements are NOT ordinary ACTIVE/PREFETCH/ON_DEMAND participants.
           They are emitted separately so a runtime which does not implement authoritative
           condition evaluation fails closed by never subscribing/delivering those definitions. */
        profiles=.set~new
        do rr over refs
          if rr~kind="PROJECTION" then profiles~put(workspace~artifact(rr~kind,rr~artifactId,rr~version)~profile)
        end
        do profile over profiles
          plan=.table~new; plan["journeyRef"]=a~ref~asWire; plan["profile"]=profile; plan["initialState"]=a~initialState; plan["initialFlowId"]=a~initialFlowId; plan["flows"]=a~flows
          plan["conditionalParticipationContract"]="AUTHORITATIVE_ADMISSION_REQUIRED"
          plan["unknownConditionalRuntimePolicy"]="OMIT"
          plan["conditionalTransitionContract"]="AUTHORITATIVE_ADMISSION_REQUIRED"
          plan["unknownConditionalTransitionPolicy"]="DENY"
          states=.array~new
          do stateId over a~stateIds
            source=a~state(stateId); row=.table~new; row["stateId"]=stateId; row["flowId"]=source["flowId"]
            conditional=self~conditionalParticipants(workspace,refs,a,profile,stateId,source)
            conditionalOnly=.set~new
            do cp over conditional
              if cp["definitionAdmissionRequired"] then conditionalOnly~put(cp["elementId"])
            end
            row["CONDITIONAL_PARTICIPANTS"]=conditional
            do tier over .array~of("ACTIVE","PREFETCH","ON_DEMAND")
              elements=.array~new; defs=.array~new
              do elementId over source[tier]
                if conditionalOnly~hasIndex(elementId) then iterate
                elements~append(elementId)
                do rr over refs
                  if rr~kind="PROJECTION" then do
                    p=workspace~artifact(rr~kind,rr~artifactId,rr~version)
                    if p~profile=profile & p~elementRef~artifactId=elementId then defs~append(p~definitionId"@"p~version)
                  end
                end
              end
              row[tier || "_ELEMENTS"]=elements
              row[tier]=defs
            end
            states~append(row)
          end
          compiledTransitions=.array~new
          do tr over a~transitions
            ct=.WireUIDesignUtil~copyTable(tr)
            do conditionListName over .array~of("whenConditionIds","suppressConditionIds")
              ids=.WireUIDesignUtil~copyArray(self~field(tr,conditionListName,.array~new))
              do cid over ids
                matches=0
                do rr over refs
                  if rr~kind="CONDITION" & rr~artifactId=cid then matches+=1
                end
                if matches<>1 then return .WireUIDesignResult~failure("JOURNEY_TRANSITION_CONDITION_NOT_EXACTLY_PINNED",a~journeyId"|"cid"|"matches)
              end
            end
            ct["whenMode"]=self~field(tr,"whenMode","ALL")
            ct["whenConditionRefs"]=self~conditionRefs(workspace,refs,self~field(tr,"whenConditionIds",.array~new))
            ct["suppressConditionRefs"]=self~conditionRefs(workspace,refs,self~field(tr,"suppressConditionIds",.array~new))
            conditional=(ct["whenConditionRefs"]~items>0 | ct["suppressConditionRefs"]~items>0)
            if conditional then do; ct["admissionMode"]="AUTHORITATIVE"; ct["unknownConditionPolicy"]="DENY"; end
            else do; ct["admissionMode"]="UNCONDITIONAL"; ct["unknownConditionPolicy"]="NOT_APPLICABLE"; end
            compiledTransitions~append(ct)
          end
          plan["states"]=states; plan["transitions"]=compiledTransitions
          pkg~addJourneyPlan(plan)
        end
      end
      when r~kind="COMPOSITION" then do
        jr=a~journeyRef
        if \pinned~hasIndex(jr~key) then return .WireUIDesignResult~failure("COMPOSITION_JOURNEY_NOT_PINNED",a~compositionId)
        journey=workspace~artifact(jr~kind,jr~artifactId,jr~version)
        state=journey~state(a~stateId)
        if state==.nil then return .WireUIDesignResult~failure("COMPOSITION_STATE_NOT_FOUND",a~compositionId"|"a~stateId)
        active=.set~new; do elementId over state["ACTIVE"]; active~put(elementId); end
        pref=a~presentationPolicyRef
        if pref<>.nil then if \pinned~hasIndex(pref~key) then return .WireUIDesignResult~failure("COMPOSITION_PRESENTATION_POLICY_NOT_PINNED",a~compositionId)
        do placement over a~placements
          do conditionListName over .array~of("whenConditionIds","suppressConditionIds")
            do cid over placement[conditionListName]
              matches=0
              do rr over refs
                if rr~kind="CONDITION" & rr~artifactId=cid then matches+=1
              end
              if matches<>1 then return .WireUIDesignResult~failure("COMPOSITION_CONDITION_NOT_EXACTLY_PINNED",a~compositionId"|"cid"|"matches)
            end
          end
          if \active~hasIndex(placement["elementId"]) then return .WireUIDesignResult~failure("COMPOSITION_ELEMENT_NOT_ACTIVE",a~compositionId"|"placement["elementId"])
          if placement["projectionId"]<>"" then do
            found=.false
            do rr over refs
              if rr~kind<>"PROJECTION" then iterate
              prj=workspace~artifact(rr~kind,rr~artifactId,rr~version)
              if prj~projectionId=placement["projectionId"] & prj~profile=a~profile & prj~elementRef~artifactId=placement["elementId"] then found=.true
            end
            if \found then return .WireUIDesignResult~failure("COMPOSITION_PROJECTION_NOT_PINNED",a~compositionId"|"placement["projectionId"])
          end
        end
        compiledComposition=a~asWire
        compiledPlacements=.array~new
        do placement over a~placements
          cp=.WireUIDesignUtil~copyTable(placement)
          cp["whenConditionRefs"]=self~conditionRefs(workspace,refs,placement["whenConditionIds"])
          cp["suppressConditionRefs"]=self~conditionRefs(workspace,refs,placement["suppressConditionIds"])
          conditional=(placement["whenConditionIds"]~items>0 | placement["suppressConditionIds"]~items>0)
          if conditional then do
            cp["admissionMode"]="AUTHORITATIVE"
            cp["unknownConditionPolicy"]="OMIT"
          end
          else do
            cp["admissionMode"]="UNCONDITIONAL"
            cp["unknownConditionPolicy"]="NOT_APPLICABLE"
          end
          compiledPlacements~append(cp)
        end
        compiledComposition["placements"]=compiledPlacements
        compiledComposition["conditionalParticipationContract"]="AUTHORITATIVE_ADMISSION_REQUIRED"
        pkg~addComposition(compiledComposition)
      end
      when r~kind="EXPERIMENT" then do
        vars=a~variants
        do v over vars
          pr=v["projectionRef"]
          if \pinned~hasIndex(pr~key) then return .WireUIDesignResult~failure("EXPERIMENT_VARIANT_NOT_PINNED",a~experimentId)
          p=workspace~artifact(pr~kind,pr~artifactId,pr~version)
          if p~elementRef~artifactId \= a~targetElementId then return .WireUIDesignResult~failure("EXPERIMENT_TARGET_MISMATCH",a~experimentId)
        end
        e=.table~new; e["experimentRef"]=a~ref~asWire; e["experimentId"]=a~experimentId; e["targetElementId"]=a~targetElementId; e["assignmentUnit"]=a~assignmentUnit; e["variants"]=vars
        pkg~addExperiment(e)
      end
      otherwise nop
    end
  end
  pkg~seal
  return .WireUIDesignResult~success(pkg,"COMPILED")

::method previewManifest
  use arg workspace, compiledPackage, scenario
  if scenario~releaseRef~contentAddress \= compiledPackage~releaseRef~contentAddress then return .WireUIDesignResult~failure("PREVIEW_RELEASE_MISMATCH")

  selectedPlan=.nil
  do p over compiledPackage~journeyPlans
    if p["profile"]=scenario~profile then do; selectedPlan=p; leave; end
  end
  if selectedPlan==.nil then return .WireUIDesignResult~failure("PREVIEW_PROFILE_NOT_COMPILED",scenario~profile)
  selectedState=.nil
  do row over selectedPlan["states"]
    if row["stateId"]=scenario~journeyState then do; selectedState=row; leave; end
  end
  if selectedState==.nil then return .WireUIDesignResult~failure("PREVIEW_JOURNEY_STATE_NOT_COMPILED",scenario~journeyState)

  m=.table~new
  m["scenarioRef"]=scenario~ref~asWire
  m["releaseRef"]=compiledPackage~releaseRef~asWire
  m["profile"]=scenario~profile
  m["journeyState"]=scenario~journeyState
  m["authenticated"]=scenario~authenticated
  m["subjectId"]=scenario~subjectId
  m["requestedExperimentAssignments"]=scenario~assignments
  m["conditionOutcomes"]=scenario~conditionOutcomes
  resolved=.table~new

  /* Start with the unconditional state vocabulary. Conditional-only definitions
     are appended only after their placements win condition evaluation and any
     presentation arbitration. */
  do tier over .array~of("ACTIVE","PREFETCH","ON_DEMAND")
    chosen=.array~new
    do elementId over selectedState[tier || "_ELEMENTS"]
      dr=self~previewDefinitionForElement(workspace,compiledPackage,scenario,elementId,"",resolved)
      if \dr~ok then return dr
      picked=dr~value
      if picked<>.nil then self~appendDefinitionUnique(chosen,picked)
    end
    m[tier || "Definitions"]=chosen
  end

  compositions=.array~new; admissionEvidence=.array~new
  do c over compiledPackage~compositions
    if c["profile"]<>scenario~profile | c["stateId"]<>scenario~journeyState then iterate
    cr=self~previewComposition(c,compiledPackage,scenario~conditionOutcomes)
    if \cr~ok then return cr
    pc=cr~value
    compositions~append(pc)
    do ev over self~field(pc,"conditionalDecisions",.array~new); admissionEvidence~append(ev); end

    /* A conditional placement which was admitted may now contribute its exact
       definition to the source tier declared by the journey. */
    do placement over pc["placements"]
      if self~field(placement,"admissionMode","UNCONDITIONAL")<>"AUTHORITATIVE" then iterate
      sourceTier=""
      do cp over self~field(selectedState,"CONDITIONAL_PARTICIPANTS",.array~new)
        if cp["elementId"]<>placement["elementId"] then iterate
        if self~field(cp,"projectionId","")<>self~field(placement,"projectionId","") then iterate
        cref=self~field(cp,"compositionRef",.nil)
        if cref<>.nil then if self~field(cref,"id","")<>c["compositionId"] then iterate
        sourceTier=cp["sourceTier"]; leave
      end
      if sourceTier="" then iterate
      dr=self~previewDefinitionForElement(workspace,compiledPackage,scenario,placement["elementId"],self~field(placement,"projectionId",""),resolved)
      if \dr~ok then return dr
      picked=dr~value
      if picked<>.nil then self~appendDefinitionUnique(m[sourceTier || "Definitions"],picked)
    end
  end
  m["compositions"]=compositions
  m["conditionalAdmissionEvidence"]=admissionEvidence
  m["resolvedExperiments"]=resolved

  transitionDecisions=.array~new; admissibleTransitions=.array~new
  do tr over selectedPlan["transitions"]
    if tr["fromState"]<>scenario~journeyState then iterate
    decision=self~transitionPreviewDecision(tr,scenario~conditionOutcomes)
    td=.WireUIDesignUtil~copyTable(tr); td["previewAdmissionDecision"]=decision
    transitionDecisions~append(td)
    if decision="ADMITTED" then admissibleTransitions~append(td)
  end
  m["transitionDecisions"]=transitionDecisions
  m["admissibleTransitions"]=admissibleTransitions
  m["previewContract"]=compiledPackage~previewContract
  m["manifestContentAddress"]=.WireUIDesignUtil~token(.WireUIDesignUtil~canonicalTable(m))
  return .WireUIDesignResult~success(m)

::method previewDefinitionForElement private
  use arg workspace, compiledPackage, scenario, elementId, projectionId="", resolved=.nil
  candidates=.array~new
  do d over compiledPackage~definitions
    if d["profile"] \= scenario~profile then iterate
    if d["semanticElementRef"]["id"] \= elementId then iterate
    if projectionId<>"" & d["projectionRef"]["id"]<>projectionId then iterate
    candidates~append(d)
  end
  if candidates~items=0 then return .WireUIDesignResult~success(.nil)
  picked=.nil
  if candidates~items=1 then picked=candidates[1]
  else do
    matchingExperiment=.nil; matches=0
    do e over compiledPackage~experiments
      if e["targetElementId"]=elementId then do; matchingExperiment=e; matches+=1; end
    end
    if matches \= 1 then return .WireUIDesignResult~failure("PREVIEW_PROJECTION_AMBIGUOUS",scenario~profile"|"elementId)
    variant=self~resolveVariant(matchingExperiment,scenario)
    if variant==.nil then return .WireUIDesignResult~failure("PREVIEW_VARIANT_NOT_RESOLVED",matchingExperiment["experimentId"])
    pr=variant["projectionRef"]
    do d over candidates
      rr=d["projectionRef"]
      if rr["id"]=pr~artifactId & rr["version"]=pr~version & rr["contentAddress"]=pr~contentAddress then do; picked=d; leave; end
    end
    if picked==.nil then return .WireUIDesignResult~failure("PREVIEW_VARIANT_DEFINITION_MISSING",matchingExperiment["experimentId"])
    if resolved<>.nil then resolved[matchingExperiment["experimentId"]]=variant["variantId"]
  end
  er=picked["semanticElementRef"]
  element=workspace~artifact(er["kind"],er["id"],er["version"])
  policy=element~audiencePolicyRef~translate
  allowed=(policy="PUBLIC") | (policy="AUTHENTICATED" & scenario~authenticated)
  if \allowed then return .WireUIDesignResult~success(.nil)
  return .WireUIDesignResult~success(picked)

::method appendDefinitionUnique private
  use arg definitions, definition
  key=definition["definitionKey"]
  do existing over definitions
    if existing["definitionKey"]=key then return .false
  end
  definitions~append(definition); return .true

::method previewComposition private
  use arg composition, compiledPackage, outcomes
  previewComposition=.WireUIDesignUtil~copyTable(composition)
  unconditional=.array~new; conditionalEligible=.array~new; decisions=.array~new
  do placement over composition["placements"]
    p=.WireUIDesignUtil~copyTable(placement)
    if self~field(p,"admissionMode","UNCONDITIONAL")="UNCONDITIONAL" then do
      unconditional~append(p); iterate
    end
    whenResult=self~conditionGroupResult(self~field(p,"whenConditionRefs",.array~new),self~field(p,"whenMode","ALL"),outcomes)
    suppressResult=self~suppressionGroupResult(self~field(p,"suppressConditionRefs",.array~new),outcomes)
    decision="ADMITTED"
    if whenResult="UNKNOWN" | suppressResult="UNKNOWN" then decision="REJECTED_UNKNOWN"
    else if whenResult<>"TRUE" then decision="REJECTED_CONDITION"
    else if suppressResult="TRUE" then decision="REJECTED_SUPPRESSION"
    ev=self~placementDecisionEvidence(composition,p,decision,whenResult,suppressResult)
    decisions~append(ev)
    if decision="ADMITTED" then conditionalEligible~append(p)
  end

  selected=self~applyPresentationPolicy(conditionalEligible,composition,compiledPackage)
  selectedKeys=.set~new
  do p over selected; selectedKeys~put(self~placementIdentity(p)); end
  do ev over decisions
    if ev["decision"]="ADMITTED" & \selectedKeys~hasIndex(ev["placementKey"]) then ev["decision"]="REJECTED_CAPACITY"
  end

  final=.array~new
  /* Preserve authored order in the resulting composition. */
  do original over composition["placements"]
    if self~field(original,"admissionMode","UNCONDITIONAL")="UNCONDITIONAL" then do; final~append(.WireUIDesignUtil~copyTable(original)); iterate; end
    if selectedKeys~hasIndex(self~placementIdentity(original)) then final~append(.WireUIDesignUtil~copyTable(original))
  end
  previewComposition["placements"]=final
  previewComposition["conditionalDecisions"]=decisions
  return .WireUIDesignResult~success(previewComposition)

::method placementDecisionEvidence private
  use arg composition, placement, decision, whenResult, suppressResult
  ev=.table~new
  ev["compositionId"]=composition["compositionId"]; ev["stateId"]=composition["stateId"]
  ev["placementKey"]=self~placementIdentity(placement); ev["elementId"]=placement["elementId"]; ev["projectionId"]=self~field(placement,"projectionId","")
  ev["region"]=self~field(placement,"region",""); ev["presentationClass"]=self~field(placement,"presentationClass","STANDARD")
  ev["whenResult"]=whenResult; ev["suppressResult"]=suppressResult; ev["decision"]=decision
  return ev

::method placementIdentity private
  use arg p
  return self~field(p,"elementId","")"|"self~field(p,"projectionId","")"|"self~field(p,"viewportClass","DEFAULT")"|"self~field(p,"region","")"|"self~field(p,"order",0)

::method conditionGroupResult private
  use arg refs, mode="ALL", outcomes=.nil
  if refs==.nil | refs~items=0 then return "TRUE"
  if outcomes==.nil then outcomes=.table~new
  mode=mode~string~strip~translate
  sawUnknown=.false
  if mode="ANY" then do
    do rr over refs
      cid=self~field(rr,"id",""); outcome="UNKNOWN"; if outcomes~hasIndex(cid) then outcome=outcomes[cid]
      outcome=outcome~string~strip~translate
      if outcome="TRUE" then return "TRUE"
      if outcome="UNKNOWN" then sawUnknown=.true
    end
    if sawUnknown then return "UNKNOWN"
    return "FALSE"
  end
  do rr over refs
    cid=self~field(rr,"id",""); outcome="UNKNOWN"; if outcomes~hasIndex(cid) then outcome=outcomes[cid]
    outcome=outcome~string~strip~translate
    if outcome="FALSE" then return "FALSE"
    if outcome<>"TRUE" then sawUnknown=.true
  end
  if sawUnknown then return "UNKNOWN"
  return "TRUE"

::method suppressionGroupResult private
  use arg refs, outcomes=.nil
  if refs==.nil | refs~items=0 then return "FALSE"
  return self~conditionGroupResult(refs,"ANY",outcomes)

::method transitionPreviewDecision private
  use arg transition, outcomes
  if self~field(transition,"admissionMode","UNCONDITIONAL")="UNCONDITIONAL" then return "ADMITTED"
  whenResult=self~conditionGroupResult(self~field(transition,"whenConditionRefs",.array~new),self~field(transition,"whenMode","ALL"),outcomes)
  suppressResult=self~suppressionGroupResult(self~field(transition,"suppressConditionRefs",.array~new),outcomes)
  if whenResult="UNKNOWN" | suppressResult="UNKNOWN" then return "REJECTED_UNKNOWN"
  if whenResult<>"TRUE" then return "REJECTED_CONDITION"
  if suppressResult="TRUE" then return "REJECTED_SUPPRESSION"
  return "ADMITTED"

::method applyPresentationPolicy private
  use arg candidates, composition, compiledPackage
  if candidates~items=0 then return .array~new
  pref=self~field(composition,"presentationPolicyRef",.nil)
  if pref==.nil then return .WireUIDesignUtil~copyArray(candidates)
  policy=.nil
  do p over compiledPackage~presentationPolicies
    if p["policyId"]=self~field(pref,"id","") & p["version"]=self~field(pref,"version","") & p["contentAddress"]=self~field(pref,"contentAddress","") then do; policy=p; leave; end
  end
  if policy==.nil then return .WireUIDesignUtil~copyArray(candidates)
  capacities=self~field(policy,"capacities",.table~new); precedence=self~field(policy,"precedence",.array~new)
  selected=.array~new; regions=.set~new
  do p over candidates; regions~put(self~field(p,"region","")); end
  do region over regions
    regional=.array~new
    do p over candidates; if self~field(p,"region","")=region then regional~append(p); end
    capacity=regional~items; if capacities~hasIndex(region) then capacity=capacities[region]+0
    used=.set~new
    do pickNo=1 to capacity
      best=.nil; bestIndex=0
      do i=1 to regional~items
        if used~hasIndex(i) then iterate
        candidate=regional[i]
        if best==.nil then do; best=candidate; bestIndex=i; end
        else if self~placementBetter(candidate,best,precedence) then do; best=candidate; bestIndex=i; end
      end
      if best==.nil then leave
      used~put(bestIndex); selected~append(best)
    end
  end
  return selected

::method placementBetter private
  use arg a,b,precedence
  ar=self~presentationRank(self~field(a,"presentationClass","STANDARD"),precedence)
  br=self~presentationRank(self~field(b,"presentationClass","STANDARD"),precedence)
  if ar<br then return .true
  if ar>br then return .false
  ao=self~field(a,"order",0)+0; bo=self~field(b,"order",0)+0
  if ao<bo then return .true
  if ao>bo then return .false
  return self~placementIdentity(a)~compare(self~placementIdentity(b))<0

::method presentationRank private
  use arg className, precedence
  do i=1 to precedence~items
    if precedence[i]=className then return i
  end
  return 100000

::method conditionalParticipants private
  use arg workspace, refs, journey, profile, stateId, sourceState
  out=.array~new; conditionalElements=.set~new; unconditionalElements=.set~new
  sourceTierByElement=.table~new
  do tier over .array~of("ACTIVE","PREFETCH","ON_DEMAND")
    do elementId over sourceState[tier]
      if \sourceTierByElement~hasIndex(elementId) then sourceTierByElement[elementId]=tier
    end
  end
  candidates=.array~new
  do rr over refs
    if rr~kind<>"COMPOSITION" then iterate
    c=workspace~artifact(rr~kind,rr~artifactId,rr~version)
    if c~profile<>profile | c~stateId<>stateId then iterate
    jr=c~journeyRef
    if jr~artifactId<>journey~journeyId | jr~version<>journey~version | jr~contentAddress<>journey~contentAddress then iterate
    do placement over c~placements
      if \sourceTierByElement~hasIndex(placement["elementId"]) then iterate
      conditional=(placement["whenConditionIds"]~items>0 | placement["suppressConditionIds"]~items>0)
      if conditional then conditionalElements~put(placement["elementId"]); else unconditionalElements~put(placement["elementId"])
      if \conditional then iterate
      cp=.table~new
      cp["elementId"]=placement["elementId"]
      cp["projectionId"]=placement["projectionId"]
      cp["sourceTier"]=sourceTierByElement[placement["elementId"]]
      cp["compositionRef"]=c~ref~asWire
      cp["presentationPolicyRef"]=.nil
      if c~presentationPolicyRef<>.nil then cp["presentationPolicyRef"]=c~presentationPolicyRef~asWire
      cp["whenMode"]=placement["whenMode"]
      cp["whenConditionRefs"]=self~conditionRefs(workspace,refs,placement["whenConditionIds"])
      cp["suppressConditionRefs"]=self~conditionRefs(workspace,refs,placement["suppressConditionIds"])
      cp["presentationClass"]=placement["presentationClass"]
      cp["placement"]=.WireUIDesignUtil~copyTable(placement)
      cp["definitionKeys"]=self~definitionKeysForPlacement(workspace,refs,profile,placement)
      cp["admissionMode"]="AUTHORITATIVE"
      cp["unknownConditionPolicy"]="OMIT"
      cp["definitionAdmissionRequired"]=.false
      candidates~append(cp)
    end
  end
  do cp over candidates
    if \unconditionalElements~hasIndex(cp["elementId"]) then cp["definitionAdmissionRequired"]=.true
    out~append(cp)
  end
  return out

::method conditionRefs private
  use arg workspace, refs, ids
  out=.array~new
  do cid over ids
    found=.nil
    do rr over refs
      if rr~kind="CONDITION" & rr~artifactId=cid then do; found=rr; leave; end
    end
    if found<>.nil then out~append(found~asWire)
  end
  return out

::method definitionKeysForPlacement private
  use arg workspace, refs, profile, placement
  out=.array~new
  do rr over refs
    if rr~kind<>"PROJECTION" then iterate
    p=workspace~artifact(rr~kind,rr~artifactId,rr~version)
    if p~profile<>profile | p~elementRef~artifactId<>placement["elementId"] then iterate
    if placement["projectionId"]<>"" & p~projectionId<>placement["projectionId"] then iterate
    out~append(p~definitionId"@"p~version)
  end
  return out

::method compositionHints private
  use arg workspace, refs, projection
  out=.array~new
  do rr over refs
    if rr~kind<>"COMPOSITION" then iterate
    c=workspace~artifact(rr~kind,rr~artifactId,rr~version)
    if c~profile<>projection~profile then iterate
    placements=c~placementsFor(projection~elementRef~artifactId,projection~projectionId)
    do placement over placements
      h=.table~new; h["compositionRef"]=c~ref~asWire; h["journeyRef"]=c~journeyRef~asWire
      h["stateId"]=c~stateId; h["layoutModel"]=c~layoutModel; h["placement"]=placement
      out~append(h)
    end
  end
  return out

::method field private
  use arg t,k,default=.nil
  if t==.nil then return default
  if t~hasIndex(k) then return t[k]
  return default

::method resolveVariant private
  use arg experiment, scenario
  requested=scenario~assignments
  expId=experiment["experimentId"]
  if requested~hasIndex(expId) then do
    wanted=requested[expId]
    do v over experiment["variants"]; if v["variantId"]=wanted then return v; end
    return .nil
  end
  total=0
  do v over experiment["variants"]; total += v["weight"]; end
  if total<=0 then return .nil
  numeric digits 20
  bucket=.WireUIDesignUtil~hashNumber(scenario~subjectId || "|" || experiment["experimentRef"]["contentAddress"]) // total
  cursor=0
  do v over experiment["variants"]
    cursor += v["weight"]
    if bucket < cursor then return v
  end
  return experiment["variants"][experiment["variants"]~items]
::requires "WireUIDesignWorkspace.cls"
::requires "WireUISiteRelease.cls"
::requires "WireUICompiledPackage.cls"
::requires "WireUIExperiment.cls"
::requires "WireUIPreviewScenario.cls"
::requires "WireUIJourneyDesign.cls"
::requires "WireUIMaterialSet.cls"
::requires "WireUIVisualComponent.cls"
::requires "WireUISemanticElement.cls"

::requires "WireUICompositionDesign.cls"

::requires "WireUIConditionDesign.cls"
::requires "WireUIPresentationPolicy.cls"
