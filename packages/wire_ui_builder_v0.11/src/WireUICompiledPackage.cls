/* Compiler output consumed later by a Wire UI runtime adapter. */
::class WireUICompiledPackage subclass AlchemyObject public
::attribute packageId get
::attribute packageVersion get
::attribute releaseRef get
::attribute contentAddress get
::method init
  expose packageId packageVersion releaseRef definitions journeyPlans experiments materials compositions conditions presentationPolicies previewContract contentAddress
  use arg packageId, packageVersion, releaseRef
  self~init:super(.WireUIDesignAlchemy~metadata("Versioned compiled interaction package"))
  definitions=.array~new; journeyPlans=.array~new; experiments=.array~new; materials=.array~new; compositions=.array~new; conditions=.array~new; presentationPolicies=.array~new
  previewContract=.table~new
  previewContract["requiresRenderedCapture"]=.true
  previewContract["captureBindsReleaseContentAddress"]=.true
  previewContract["captureBindsScenarioContentAddress"]=.true
  previewContract["semanticManifestAvailable"]=.true
  previewContract["conditionsRequireAuthoritativeRuntimeEvaluation"]=.true
  previewContract["conditionalTransitionsRequireAuthoritativeRuntimeEvaluation"]=.true
  previewContract["authoringPreviewAcceptsExplicitConditionOutcomes"]=.true
  previewContract["unknownPreviewConditionPolicy"]="OMIT_OR_DENY"
  previewContract["resourceBytesAreExternalToBuilder"]=.true
  contentAddress=""
::method addDefinition
  expose definitions contentAddress; use arg d; definitions~append(d); contentAddress=""; return self
::method addJourneyPlan
  expose journeyPlans contentAddress; use arg p; journeyPlans~append(p); contentAddress=""; return self
::method addExperiment
  expose experiments contentAddress; use arg e; experiments~append(e); contentAddress=""; return self
::method addMaterial
  expose materials contentAddress; use arg m; materials~append(m); contentAddress=""; return self
::method addComposition
  expose compositions contentAddress; use arg c; compositions~append(c); contentAddress=""; return self
::method addCondition
  expose conditions contentAddress; use arg c; conditions~append(c); contentAddress=""; return self
::method addPresentationPolicy
  expose presentationPolicies contentAddress; use arg p; presentationPolicies~append(p); contentAddress=""; return self
::method definitions
  expose definitions; return .WireUIDesignUtil~copyArray(definitions)
::method journeyPlans
  expose journeyPlans; return .WireUIDesignUtil~copyArray(journeyPlans)
::method experiments
  expose experiments; return .WireUIDesignUtil~copyArray(experiments)
::method materials
  expose materials; return .WireUIDesignUtil~copyArray(materials)
::method compositions
  expose compositions; return .WireUIDesignUtil~copyArray(compositions)
::method conditions
  expose conditions; return .WireUIDesignUtil~copyArray(conditions)
::method presentationPolicies
  expose presentationPolicies; return .WireUIDesignUtil~copyArray(presentationPolicies)
::method previewContract
  expose previewContract; return .WireUIDesignUtil~copyTable(previewContract)
::method asWire
  expose packageId packageVersion releaseRef definitions journeyPlans experiments materials compositions conditions presentationPolicies previewContract contentAddress
  d=.directory~new; d["packageId"]=packageId; d["packageVersion"]=packageVersion; d["releaseRef"]=releaseRef~asWire; d["contentAddress"]=contentAddress
  d["definitions"]=.WireUIDesignUtil~copyArray(definitions); d["journeyPlans"]=.WireUIDesignUtil~copyArray(journeyPlans); d["experiments"]=.WireUIDesignUtil~copyArray(experiments); d["materials"]=.WireUIDesignUtil~copyArray(materials); d["compositions"]=.WireUIDesignUtil~copyArray(compositions); d["conditions"]=.WireUIDesignUtil~copyArray(conditions); d["presentationPolicies"]=.WireUIDesignUtil~copyArray(presentationPolicies); d["previewContract"]=.WireUIDesignUtil~copyTable(previewContract)
  return d
::method seal
  expose packageId packageVersion releaseRef definitions journeyPlans experiments materials compositions conditions presentationPolicies previewContract contentAddress
  text=packageId"|"packageVersion"|"releaseRef~canonicalText"|".WireUIDesignUtil~canonicalArray(definitions)"|".WireUIDesignUtil~canonicalArray(journeyPlans)"|".WireUIDesignUtil~canonicalArray(experiments)"|".WireUIDesignUtil~canonicalArray(materials)"|".WireUIDesignUtil~canonicalArray(compositions)"|".WireUIDesignUtil~canonicalArray(conditions)"|".WireUIDesignUtil~canonicalArray(presentationPolicies)"|".WireUIDesignUtil~canonicalTable(previewContract)
  contentAddress=.WireUIDesignUtil~token(text); return self
::requires "WireUIDesignSupport.cls"
