/*
 * Brand Journey v0.1
 *
 * Privacy-minimised cross-domain brand-experience continuity model.
 * It is deliberately not CRM, identity resolution, telemetry, or a causal
 * engine.  Access/correlation components supply opaque journey references;
 * this package preserves the semantic residue of how the organisation was
 * experienced across support, delivery, billing, sales and operations.
 */

::class BrandJourneyBuild public
::constant VERSION "0.1"
::constant API_VERSION "brand.journey/0.1"
::constant PRODUCT "ooRexx Brand Journey"

::class BrandJourneyAlchemySupport public
::method metadata class
  use arg purposeArg
  d=.directory~new
  d["purpose"]=purposeArg~string
  d["package_version"]=.BrandJourneyBuild~VERSION
  d["api_version"]=.BrandJourneyBuild~API_VERSION
  d["component"]="BRAND_JOURNEY"
  return d

::class BrandJourneyConstant public
/* Operational domains.  Department boundaries are not customer boundaries. */
::constant DOMAIN_SUPPORT "SUPPORT"
::constant DOMAIN_DELIVERY "DELIVERY"
::constant DOMAIN_BILLING "BILLING"
::constant DOMAIN_SALES "SALES"
::constant DOMAIN_OPERATIONS "OPERATIONS"
::constant DOMAIN_DIGITAL "DIGITAL"
::constant DOMAIN_OTHER "OTHER"

/* Service/journey state. */
::constant STATE_UNKNOWN "UNKNOWN"
::constant STATE_OPEN "OPEN"
::constant STATE_IN_PROGRESS "IN_PROGRESS"
::constant STATE_UNRESOLVED "UNRESOLVED"
::constant STATE_RESOLVED "RESOLVED"
::constant STATE_ABANDONED "ABANDONED"
::constant STATE_COMMERCIAL_EXIT "COMMERCIAL_EXIT"

/* Handoff continuity. */
::constant CONTEXT_CARRIED "CONTEXT_CARRIED"
::constant CONTEXT_PARTIAL "CONTEXT_PARTIAL"
::constant CONTEXT_LOST "CONTEXT_LOST"
::constant CONTEXT_UNKNOWN "CONTEXT_UNKNOWN"

/* Brand functions - significance, not action authority. */
::constant BRAND_ENGAGEMENT "BRAND_ENGAGEMENT"
::constant PROMOTIONAL_WORK "PROMOTIONAL_WORK"
::constant REPUTATIONAL_WORK "REPUTATIONAL_WORK"
::constant COMMERCIAL_RELATIONSHIP_WORK "COMMERCIAL_RELATIONSHIP_WORK"

/* Journey findings. */
::constant FIND_TOUCHPOINT "BRAND_JOURNEY_TOUCHPOINT"
::constant FIND_SERVICE_AS_SALES "SERVICE_AS_SALES_JOURNEY"
::constant FIND_CROSS_DOMAIN_CONTINUITY "CROSS_DOMAIN_CONTINUITY"
::constant FIND_CONTEXT_LOSS "CROSS_DOMAIN_CONTEXT_LOSS"
::constant FIND_REPEAT_BURDEN "CUSTOMER_REPEAT_BURDEN"
::constant FIND_UNRESOLVED_CARRY "UNRESOLVED_STATE_CARRIED"
::constant FIND_COMMERCIAL_WHILE_UNRESOLVED "COMMERCIAL_TRANSITION_WHILE_UNRESOLVED"
::constant FIND_RECOVERY_ACROSS_DOMAIN "SERVICE_RECOVERY_ACROSS_DOMAIN"
::constant FIND_RELATIONSHIP_PRESERVED "RELATIONSHIP_PRESERVED_ACROSS_TOUCHPOINTS"

::class BrandJourneyResult public
::attribute ok get
::attribute value get
::attribute code get
::attribute detail get
::method init
  expose ok value code detail
  use arg okArg, valueArg=.nil, codeArg="", detailArg=""
  ok=okArg; value=valueArg; code=codeArg; detail=detailArg
::method success class
  use arg value=.nil, detail=""
  return self~new(.true,value,"OK",detail)
::method failure class
  use arg codeArg, detailArg=""
  return self~new(.false,.nil,codeArg,detailArg)

::class BrandJourneyCanonical public
::method token class
  use arg value
  if value==.nil then return ""
  t=value~string~strip~translate
  t=changestr(" ",t,"_")
  return t
::method copyArray class
  use arg source
  out=.array~new
  if source==.nil then return out
  do x over source; out~append(x); end
  return out
::method contains class
  use arg values, wanted
  if values==.nil then return .false
  do x over values
    if x~string == wanted~string then return .true
  end
  return .false
::method field class
  use arg name,value
  return name~string || "=" || value~string || '0a'x
::method join class
  use arg name,values
  out=""
  if values==.nil then return out
  do x over values; out ||= self~field(name,x); end
  return out

/* A privacy-minimised organisational touchpoint.  It contains no raw
   conversation and no customer identity. */
::class BrandJourneyTouchpoint subclass AlchemyObject public
::attribute touchpointId get
::attribute domain get
::attribute sourcePoint get
::attribute surface get
::attribute occurredAt get
::attribute stateBefore get
::attribute stateAfter get
::attribute unresolvedBefore get
::attribute unresolvedAfter get
::attribute explicitSalesProposition get
::attribute sealed get
::method init
  expose touchpointId domain sourcePoint surface occurredAt stateBefore stateAfter unresolvedBefore unresolvedAfter explicitSalesProposition purposes brandFunctions brandOpportunities evidencePoints tags sealed
  use arg idArg, domainArg, sourcePointArg="", surfaceArg="", occurredAtArg=.nil, stateBeforeArg="UNKNOWN", stateAfterArg="UNKNOWN", unresolvedBeforeArg=.false, unresolvedAfterArg=.false, explicitSalesArg=.false, alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  touchpointId=idArg~string
  domain=.BrandJourneyCanonical~token(domainArg)
  sourcePoint=sourcePointArg~string
  surface=.BrandJourneyCanonical~token(surfaceArg)
  if occurredAtArg==.nil then occurredAt=.DateTime~new; else occurredAt=occurredAtArg
  stateBefore=.BrandJourneyCanonical~token(stateBeforeArg)
  stateAfter=.BrandJourneyCanonical~token(stateAfterArg)
  unresolvedBefore=unresolvedBeforeArg
  unresolvedAfter=unresolvedAfterArg
  explicitSalesProposition=explicitSalesArg
  if touchpointId="" | domain="" then raise syntax 88.970 array("BrandJourneyTouchpoint requires id and domain")
  purposes=.array~new; brandFunctions=.array~new; brandOpportunities=.array~new; evidencePoints=.array~new; tags=.array~new; sealed=.false
  self~initAlchemy(.BrandJourneyAlchemySupport~metadata("privacy-minimised brand-experience touchpoint across organisational domains"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("touchpointId","CUSTOMER","journey-local touchpoint identifier")
  self~registerStateVariable("domain","CUSTOMER","operational domain experienced by customer")
  self~registerStateVariable("sourcePoint","INTERNAL","upstream evidence point")
  self~registerStateVariable("surface","CUSTOMER","controlled interaction surface")
  self~registerStateVariable("occurredAt","CUSTOMER","touchpoint time")
  self~registerStateVariable("stateBefore","CUSTOMER","controlled journey state before touchpoint")
  self~registerStateVariable("stateAfter","CUSTOMER","controlled journey state after touchpoint")
  self~registerStateVariable("unresolvedBefore","CUSTOMER","whether unresolved need existed before touchpoint")
  self~registerStateVariable("unresolvedAfter","CUSTOMER","whether unresolved need remained after touchpoint")
  self~registerStateVariable("explicitSalesProposition","CUSTOMER","explicit sales proposition observed; never inferred from brand context")
  self~registerStateVariable("purposes","CUSTOMER","controlled communication purposes")
  self~registerStateVariable("brandFunctions","CUSTOMER","brand significance; not action authority")
  self~registerStateVariable("brandOpportunities","CUSTOMER","brand opportunities; not sales permission")
  self~registerStateVariable("evidencePoints","INTERNAL","supporting evidence points")
  self~registerStateVariable("tags","CUSTOMER","privacy-minimised controlled tags")
  self~registerStateVariable("sealed","CUSTOMER","touchpoint immutability")
  self~registerInstrumentationPoint("BRAND.JOURNEY.TOUCHPOINT.SEALED","journey touchpoint sealed",.true,"ALL","INTERNAL")
  self~registerMethodContract("SEAL","seal journey touchpoint",.array~new,"BRANDJOURNEYTOUCHPOINT",.false,"AUTO","CUSTOMER","NORMAL","MUTATE","NONE")
::method addPurpose
  expose purposes sealed
  use arg value
  if sealed then return .false
  t=.BrandJourneyCanonical~token(value); if t="" then return .false
  if \.BrandJourneyCanonical~contains(purposes,t) then purposes~append(t)
  return .true
::method addBrandFunction
  expose brandFunctions sealed
  use arg value
  if sealed then return .false
  t=.BrandJourneyCanonical~token(value); if t="" then return .false
  if \.BrandJourneyCanonical~contains(brandFunctions,t) then brandFunctions~append(t)
  return .true
::method addBrandOpportunity
  expose brandOpportunities sealed
  use arg value
  if sealed then return .false
  t=.BrandJourneyCanonical~token(value); if t="" then return .false
  if \.BrandJourneyCanonical~contains(brandOpportunities,t) then brandOpportunities~append(t)
  return .true
::method addEvidencePoint
  expose evidencePoints sealed
  use arg value
  if sealed | value~string="" then return .false
  if \.BrandJourneyCanonical~contains(evidencePoints,value~string) then evidencePoints~append(value~string)
  return .true
::method addTag
  expose tags sealed
  use arg value
  if sealed then return .false
  t=.BrandJourneyCanonical~token(value); if t="" then return .false
  if \.BrandJourneyCanonical~contains(tags,t) then tags~append(t)
  return .true
::method purposes
  expose purposes; return .BrandJourneyCanonical~copyArray(purposes)
::method brandFunctions
  expose brandFunctions; return .BrandJourneyCanonical~copyArray(brandFunctions)
::method brandOpportunities
  expose brandOpportunities; return .BrandJourneyCanonical~copyArray(brandOpportunities)
::method evidencePoints
  expose evidencePoints; return .BrandJourneyCanonical~copyArray(evidencePoints)
::method tags
  expose tags; return .BrandJourneyCanonical~copyArray(tags)
::method hasPurpose
  expose purposes; use arg value; return .BrandJourneyCanonical~contains(purposes,.BrandJourneyCanonical~token(value))
::method hasBrandFunction
  expose brandFunctions; use arg value; return .BrandJourneyCanonical~contains(brandFunctions,.BrandJourneyCanonical~token(value))
::method seal
  expose sealed
  sealed=.true
  self~alchemyTouch("TOUCHPOINT_SEAL")
  self~alchemyInstrument("BRAND.JOURNEY.TOUCHPOINT.SEALED",self~touchpointId)
  return self
::method pointId
  expose touchpointId
  return "BRAND_JOURNEY:TOUCHPOINT:"||touchpointId
::method canonicalText
  expose touchpointId domain sourcePoint surface occurredAt stateBefore stateAfter unresolvedBefore unresolvedAfter explicitSalesProposition purposes brandFunctions brandOpportunities evidencePoints tags sealed
  if \sealed then raise syntax 93.970 additional("BrandJourneyTouchpoint must be sealed")
  out=.BrandJourneyCanonical~field("TOUCHPOINT",touchpointId)
  out||=.BrandJourneyCanonical~field("DOMAIN",domain)
  out||=.BrandJourneyCanonical~field("SURFACE",surface)
  out||=.BrandJourneyCanonical~field("OCCURRED_AT",occurredAt)
  out||=.BrandJourneyCanonical~field("STATE_BEFORE",stateBefore)
  out||=.BrandJourneyCanonical~field("STATE_AFTER",stateAfter)
  out||=.BrandJourneyCanonical~field("UNRESOLVED_BEFORE",unresolvedBefore)
  out||=.BrandJourneyCanonical~field("UNRESOLVED_AFTER",unresolvedAfter)
  out||=.BrandJourneyCanonical~field("EXPLICIT_SALESPROP",explicitSalesProposition)
  out||=.BrandJourneyCanonical~join("PURPOSE",purposes)
  out||=.BrandJourneyCanonical~join("BRAND_FUNCTION",brandFunctions)
  out||=.BrandJourneyCanonical~join("BRAND_OPPORTUNITY",brandOpportunities)
  out||=.BrandJourneyCanonical~join("TAG",tags)
  out||=.BrandJourneyCanonical~join("EVIDENCE_POINT",evidencePoints)
  return out

::class BrandJourneyHandoff subclass AlchemyObject public
::attribute handoffId get
::attribute fromTouchpointId get
::attribute toTouchpointId get
::attribute fromDomain get
::attribute toDomain get
::attribute contextStatus get
::attribute customerRepeatRequired get
::attribute unresolvedCarried get
::attribute gapSeconds get
::attribute sealed get
::method init
  expose handoffId fromTouchpointId toTouchpointId fromDomain toDomain contextStatus customerRepeatRequired unresolvedCarried gapSeconds evidencePoints sealed
  use arg idArg, fromIdArg, toIdArg, fromDomainArg, toDomainArg, contextArg="CONTEXT_UNKNOWN", repeatArg=.false, unresolvedArg=.false, gapSecondsArg=0, alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  handoffId=idArg~string; fromTouchpointId=fromIdArg~string; toTouchpointId=toIdArg~string
  fromDomain=.BrandJourneyCanonical~token(fromDomainArg); toDomain=.BrandJourneyCanonical~token(toDomainArg); contextStatus=.BrandJourneyCanonical~token(contextArg)
  customerRepeatRequired=repeatArg; unresolvedCarried=unresolvedArg
  if datatype(gapSecondsArg,"N") then gapSeconds=max(0,gapSecondsArg+0); else gapSeconds=0
  if handoffId="" | fromTouchpointId="" | toTouchpointId="" | fromDomain="" | toDomain="" then raise syntax 88.971 array("BrandJourneyHandoff requires ids and domains")
  evidencePoints=.array~new; sealed=.false
  self~initAlchemy(.BrandJourneyAlchemySupport~metadata("cross-domain handoff continuity evidence"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("handoffId","CUSTOMER","handoff identifier")
  self~registerStateVariable("fromTouchpointId","INTERNAL","source touchpoint id")
  self~registerStateVariable("toTouchpointId","INTERNAL","target touchpoint id")
  self~registerStateVariable("fromDomain","CUSTOMER","origin operational domain")
  self~registerStateVariable("toDomain","CUSTOMER","destination operational domain")
  self~registerStateVariable("contextStatus","CUSTOMER","whether relevant context was carried")
  self~registerStateVariable("customerRepeatRequired","CUSTOMER","customer had to repeat already supplied context")
  self~registerStateVariable("unresolvedCarried","CUSTOMER","unresolved need crossed handoff")
  self~registerStateVariable("gapSeconds","CUSTOMER","elapsed seconds between touchpoints when known")
  self~registerStateVariable("evidencePoints","INTERNAL","handoff supporting evidence")
  self~registerStateVariable("sealed","CUSTOMER","handoff immutability")
  self~registerInstrumentationPoint("BRAND.JOURNEY.HANDOFF.SEALED","journey handoff sealed",.true,"ALL","INTERNAL")
::method addEvidencePoint
  expose evidencePoints sealed
  use arg value
  if sealed | value~string="" then return .false
  if \.BrandJourneyCanonical~contains(evidencePoints,value~string) then evidencePoints~append(value~string)
  return .true
::method evidencePoints
  expose evidencePoints; return .BrandJourneyCanonical~copyArray(evidencePoints)
::method seal
  expose sealed
  sealed=.true
  self~alchemyTouch("HANDOFF_SEAL")
  self~alchemyInstrument("BRAND.JOURNEY.HANDOFF.SEALED",self~handoffId)
  return self
::method pointId
  expose handoffId; return "BRAND_JOURNEY:HANDOFF:"||handoffId
::method canonicalText
  expose handoffId fromTouchpointId toTouchpointId fromDomain toDomain contextStatus customerRepeatRequired unresolvedCarried gapSeconds evidencePoints sealed
  if \sealed then raise syntax 93.971 additional("BrandJourneyHandoff must be sealed")
  out=.BrandJourneyCanonical~field("HANDOFF",handoffId)
  out||=.BrandJourneyCanonical~field("FROM_DOMAIN",fromDomain)
  out||=.BrandJourneyCanonical~field("TO_DOMAIN",toDomain)
  out||=.BrandJourneyCanonical~field("CONTEXT_STATUS",contextStatus)
  out||=.BrandJourneyCanonical~field("CUSTOMER_REPEAT_REQUIRED",customerRepeatRequired)
  out||=.BrandJourneyCanonical~field("UNRESOLVED_CARRIED",unresolvedCarried)
  out||=.BrandJourneyCanonical~field("GAP_SECONDS",gapSeconds)
  out||=.BrandJourneyCanonical~join("EVIDENCE_POINT",evidencePoints)
  return out

::class BrandJourney subclass AlchemyObject public
::attribute journeyId get
::attribute relationshipClass get
::attribute sealed get
::method init
  expose journeyId relationshipRef relationshipClass touchpoints handoffs tags sealed
  use arg journeyIdArg, relationshipRefArg="", relationshipClassArg="CUSTOMER_RELATIONSHIP", alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  journeyId=journeyIdArg~string; relationshipRef=relationshipRefArg~string; relationshipClass=.BrandJourneyCanonical~token(relationshipClassArg)
  if journeyId="" | relationshipClass="" then raise syntax 88.972 array("BrandJourney requires safe journey id and relationship class")
  touchpoints=.array~new; handoffs=.array~new; tags=.array~new; sealed=.false
  self~initAlchemy(.BrandJourneyAlchemySupport~metadata("cross-domain brand journey; opaque relationship correlation is protected and not CRM identity"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("journeyId","CUSTOMER","safe journey identifier, not customer identity")
  self~registerStateVariable("relationshipRef","SECRET","externally supplied opaque/customer-specific correlation reference")
  self~registerStateVariable("relationshipClass","CUSTOMER","relationship class")
  self~registerStateVariable("touchpoints","INTERNAL","ordered sealed journey touchpoints")
  self~registerStateVariable("handoffs","INTERNAL","sealed cross-domain handoffs")
  self~registerStateVariable("tags","CUSTOMER","privacy-minimised journey tags")
  self~registerStateVariable("sealed","CUSTOMER","journey immutability")
  self~registerInstrumentationPoint("BRAND.JOURNEY.TOUCHPOINT.ADDED","touchpoint appended to journey",.true,"ALL","INTERNAL")
  self~registerInstrumentationPoint("BRAND.JOURNEY.HANDOFF.ADDED","handoff appended to journey",.true,"ALL","INTERNAL")
  self~registerInstrumentationPoint("BRAND.JOURNEY.SEALED","journey sealed",.true,"ALL","INTERNAL")
  self~registerMethodContract("ADDTOUCHPOINT","append sealed touchpoint",.array~of("TOUCHPOINT"),"BOOLEAN",.false,"AUTO","INTERNAL","SENSITIVE","MUTATE","NONE")
  self~registerMethodContract("ADDHANDOFF","append sealed handoff",.array~of("HANDOFF"),"BOOLEAN",.false,"AUTO","INTERNAL","SENSITIVE","MUTATE","NONE")
  self~registerMethodContract("SEAL","seal non-empty brand journey",.array~new,"BRANDJOURNEYRESULT",.false,"AUTO","CUSTOMER","NORMAL","MUTATE","NONE")
::method addTouchpoint
  expose touchpoints sealed
  use arg touchpoint
  if sealed | touchpoint==.nil | \touchpoint~sealed then return .false
  touchpoints~append(touchpoint)
  if touchpoint~hasMethod("ALCHEMYOBJECTID") then self~recordRelationship("CONTAINS",touchpoint,"brand journey touchpoint","INTERNAL")
  self~alchemyTouch("JOURNEY_ADD_TOUCHPOINT")
  self~alchemyInstrument("BRAND.JOURNEY.TOUCHPOINT.ADDED",touchpoint~pointId)
  return .true
::method addHandoff
  expose handoffs sealed
  use arg handoff
  if sealed | handoff==.nil | \handoff~sealed then return .false
  handoffs~append(handoff)
  if handoff~hasMethod("ALCHEMYOBJECTID") then self~recordRelationship("CONTAINS",handoff,"cross-domain journey handoff","INTERNAL")
  self~alchemyTouch("JOURNEY_ADD_HANDOFF")
  self~alchemyInstrument("BRAND.JOURNEY.HANDOFF.ADDED",handoff~pointId)
  return .true
::method addTag
  expose tags sealed
  use arg value
  if sealed then return .false
  t=.BrandJourneyCanonical~token(value); if t="" then return .false
  if \.BrandJourneyCanonical~contains(tags,t) then tags~append(t)
  return .true
::method touchpoints
  expose touchpoints; return .BrandJourneyCanonical~copyArray(touchpoints)
::method handoffs
  expose handoffs; return .BrandJourneyCanonical~copyArray(handoffs)
::method tags
  expose tags; return .BrandJourneyCanonical~copyArray(tags)
::method pointId
  expose journeyId; return "BRAND_JOURNEY:"||journeyId
::method seal
  expose touchpoints sealed
  if touchpoints~items=0 then return .BrandJourneyResult~failure("JOURNEY_EMPTY")
  sealed=.true
  self~alchemyTouch("JOURNEY_SEAL")
  self~alchemyInstrument("BRAND.JOURNEY.SEALED",self~journeyId)
  return .BrandJourneyResult~success(self)
::method canonicalText
  expose journeyId relationshipClass touchpoints handoffs tags sealed
  if \sealed then raise syntax 93.972 additional("BrandJourney must be sealed")
  out=.BrandJourneyCanonical~field("JOURNEY",journeyId)
  out||=.BrandJourneyCanonical~field("RELATIONSHIP_CLASS",relationshipClass)
  out||=.BrandJourneyCanonical~field("TOUCHPOINT_COUNT",touchpoints~items)
  out||=.BrandJourneyCanonical~field("HANDOFF_COUNT",handoffs~items)
  out||=.BrandJourneyCanonical~join("TAG",tags)
  return out

::class BrandJourneyAssessment subclass AlchemyObject public
::attribute assessmentId get
::attribute journeyPoint get
::attribute touchpointCount get
::attribute domainCount get
::attribute handoffCount get
::attribute contextLossCount get
::attribute repeatBurdenCount get
::attribute unresolvedCarryCount get
::attribute explicitSalesCount get
::attribute promotionalTouchpointCount get
::attribute recoveryTouchpointCount get
::attribute sealed get
::method init
  expose assessmentId journeyPoint touchpointCount domainCount handoffCount contextLossCount repeatBurdenCount unresolvedCarryCount explicitSalesCount promotionalTouchpointCount recoveryTouchpointCount findings evidencePoints sealed
  use arg idArg, journeyPointArg, touchpointCountArg=0, domainCountArg=0, handoffCountArg=0, contextLossCountArg=0, repeatBurdenCountArg=0, unresolvedCarryCountArg=0, explicitSalesCountArg=0, promotionalCountArg=0, recoveryCountArg=0, alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  assessmentId=idArg~string; journeyPoint=journeyPointArg~string
  touchpointCount=touchpointCountArg+0; domainCount=domainCountArg+0; handoffCount=handoffCountArg+0; contextLossCount=contextLossCountArg+0; repeatBurdenCount=repeatBurdenCountArg+0; unresolvedCarryCount=unresolvedCarryCountArg+0; explicitSalesCount=explicitSalesCountArg+0; promotionalTouchpointCount=promotionalCountArg+0; recoveryTouchpointCount=recoveryCountArg+0
  if assessmentId="" | journeyPoint="" then raise syntax 88.973 array("BrandJourneyAssessment requires id and journey point")
  findings=.array~new; evidencePoints=.array~new; sealed=.false
  self~initAlchemy(.BrandJourneyAlchemySupport~metadata("privacy-minimised journey continuity and brand-experience assessment"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("assessmentId","CUSTOMER","assessment identifier")
  self~registerStateVariable("journeyPoint","INTERNAL","journey evidence point")
  self~registerStateVariable("touchpointCount","CUSTOMER","touchpoint count")
  self~registerStateVariable("domainCount","CUSTOMER","distinct operational domains")
  self~registerStateVariable("handoffCount","CUSTOMER","handoff count")
  self~registerStateVariable("contextLossCount","CUSTOMER","handoffs losing context")
  self~registerStateVariable("repeatBurdenCount","CUSTOMER","handoffs forcing customer repetition")
  self~registerStateVariable("unresolvedCarryCount","CUSTOMER","unresolved state crossing handoffs")
  self~registerStateVariable("explicitSalesCount","CUSTOMER","explicit sales propositions; separate from brand work")
  self~registerStateVariable("promotionalTouchpointCount","CUSTOMER","touchpoints functioning as promotional/brand work")
  self~registerStateVariable("recoveryTouchpointCount","CUSTOMER","touchpoints resolving prior unresolved state")
  self~registerStateVariable("findings","CUSTOMER","controlled journey findings")
  self~registerStateVariable("evidencePoints","INTERNAL","supporting journey evidence")
  self~registerStateVariable("sealed","CUSTOMER","assessment immutability")
  self~registerInstrumentationPoint("BRAND.JOURNEY.ASSESSMENT.SEALED","journey assessment sealed",.true,"ALL","INTERNAL")
::method addFinding
  expose findings sealed
  use arg value
  if sealed then return .false
  t=.BrandJourneyCanonical~token(value); if t="" then return .false
  if \.BrandJourneyCanonical~contains(findings,t) then findings~append(t)
  return .true
::method addEvidencePoint
  expose evidencePoints sealed
  use arg value
  if sealed | value~string="" then return .false
  if \.BrandJourneyCanonical~contains(evidencePoints,value~string) then evidencePoints~append(value~string)
  return .true
::method findings
  expose findings; return .BrandJourneyCanonical~copyArray(findings)
::method evidencePoints
  expose evidencePoints; return .BrandJourneyCanonical~copyArray(evidencePoints)
::method containsFinding
  expose findings; use arg value; return .BrandJourneyCanonical~contains(findings,.BrandJourneyCanonical~token(value))
::method seal
  expose sealed
  sealed=.true
  self~alchemyTouch("ASSESSMENT_SEAL")
  self~alchemyInstrument("BRAND.JOURNEY.ASSESSMENT.SEALED",self~assessmentId)
  return self
::method pointId
  expose assessmentId; return "BRAND_JOURNEY:ASSESSMENT:"||assessmentId
::method canonicalText
  expose assessmentId touchpointCount domainCount handoffCount contextLossCount repeatBurdenCount unresolvedCarryCount explicitSalesCount promotionalTouchpointCount recoveryTouchpointCount findings evidencePoints sealed
  if \sealed then raise syntax 93.973 additional("BrandJourneyAssessment must be sealed")
  out=.BrandJourneyCanonical~field("ASSESSMENT",assessmentId)
  out||=.BrandJourneyCanonical~field("TOUCHPOINTS",touchpointCount)
  out||=.BrandJourneyCanonical~field("DOMAINS",domainCount)
  out||=.BrandJourneyCanonical~field("HANDOFFS",handoffCount)
  out||=.BrandJourneyCanonical~field("CONTEXT_LOSS",contextLossCount)
  out||=.BrandJourneyCanonical~field("REPEAT_BURDEN",repeatBurdenCount)
  out||=.BrandJourneyCanonical~field("UNRESOLVED_CARRY",unresolvedCarryCount)
  out||=.BrandJourneyCanonical~field("EXPLICIT_SALES",explicitSalesCount)
  out||=.BrandJourneyCanonical~field("PROMOTIONAL_TOUCHPOINTS",promotionalTouchpointCount)
  out||=.BrandJourneyCanonical~field("RECOVERY_TOUCHPOINTS",recoveryTouchpointCount)
  out||=.BrandJourneyCanonical~join("FINDING",findings)
  out||=.BrandJourneyCanonical~join("EVIDENCE_POINT",evidencePoints)
  return out

::class BrandJourneyEngine public
::method evaluate
  use arg journey
  if journey==.nil | \journey~sealed then return .BrandJourneyResult~failure("JOURNEY_NOT_SEALED")
  touchpoints=journey~touchpoints; handoffs=journey~handoffs
  domains=.array~new
  contextLoss=0; repeatBurden=0; unresolvedCarry=0; explicitSales=0; promotional=0; recovery=0
  crossDomain=.false; carriedCrossDomain=.false
  do tp over touchpoints
    if \.BrandJourneyCanonical~contains(domains,tp~domain) then domains~append(tp~domain)
    if tp~explicitSalesProposition then explicitSales+=1
    /* Service as Sales: support and delivery are inherently brand experience
       touchpoints.  PROMOTIONAL_WORK is significance, never permission. */
    if tp~domain=.BrandJourneyConstant~DOMAIN_SUPPORT | tp~domain=.BrandJourneyConstant~DOMAIN_DELIVERY | tp~hasBrandFunction(.BrandJourneyConstant~PROMOTIONAL_WORK) then promotional+=1
    if tp~unresolvedBefore & \tp~unresolvedAfter then recovery+=1
  end
  do h over handoffs
    if h~fromDomain<>h~toDomain then crossDomain=.true
    if h~fromDomain<>h~toDomain & h~contextStatus=.BrandJourneyConstant~CONTEXT_CARRIED then carriedCrossDomain=.true
    if h~contextStatus=.BrandJourneyConstant~CONTEXT_LOST then contextLoss+=1
    if h~customerRepeatRequired then repeatBurden+=1
    if h~unresolvedCarried then unresolvedCarry+=1
  end
  a=.BrandJourneyAssessment~new("ASSESS-"||journey~journeyId,journey~pointId,touchpoints~items,domains~items,handoffs~items,contextLoss,repeatBurden,unresolvedCarry,explicitSales,promotional,recovery)
  a~addFinding(.BrandJourneyConstant~FIND_TOUCHPOINT)
  if promotional>0 then a~addFinding(.BrandJourneyConstant~FIND_SERVICE_AS_SALES)
  if crossDomain & carriedCrossDomain & contextLoss=0 then a~addFinding(.BrandJourneyConstant~FIND_CROSS_DOMAIN_CONTINUITY)
  if contextLoss>0 then a~addFinding(.BrandJourneyConstant~FIND_CONTEXT_LOSS)
  if repeatBurden>0 then a~addFinding(.BrandJourneyConstant~FIND_REPEAT_BURDEN)
  if unresolvedCarry>0 then a~addFinding(.BrandJourneyConstant~FIND_UNRESOLVED_CARRY)
  /* A sales proposition is a real observed act.  Brand/promotional tags alone
     can never trigger this finding. */
  do tp over touchpoints
    if tp~explicitSalesProposition & tp~unresolvedBefore then a~addFinding(.BrandJourneyConstant~FIND_COMMERCIAL_WHILE_UNRESOLVED)
  end
  if recovery>0 & domains~items>1 then a~addFinding(.BrandJourneyConstant~FIND_RECOVERY_ACROSS_DOMAIN)
  if touchpoints~items>1 then do
    last=touchpoints[touchpoints~items]
    if \last~unresolvedAfter & last~stateAfter<>.BrandJourneyConstant~STATE_COMMERCIAL_EXIT & last~stateAfter<>.BrandJourneyConstant~STATE_ABANDONED then a~addFinding(.BrandJourneyConstant~FIND_RELATIONSHIP_PRESERVED)
  end
  a~addEvidencePoint(journey~pointId)
  do tp over touchpoints; a~addEvidencePoint(tp~pointId); end
  do h over handoffs; a~addEvidencePoint(h~pointId); end
  a~seal
  return .BrandJourneyResult~success(a)

::class BrandJourneyLibrary subclass AlchemyObject public
::method init
  expose journeys
  use arg alchemySealerArg=.nil, alchemyAuthorityArg=.nil
  journeys=.directory~new
  self~initAlchemy(.BrandJourneyAlchemySupport~metadata("brand journey registry keyed by safe journey id; not a customer identity store"),alchemySealerArg,alchemyAuthorityArg)
  self~registerStateVariable("journeys","INTERNAL","registered sealed journeys")
  self~registerInstrumentationPoint("BRAND.JOURNEY.REGISTERED","sealed journey registered",.true,"ALL","INTERNAL")
::method registerJourney
  expose journeys
  use arg journey
  if journey==.nil | \journey~sealed then return .BrandJourneyResult~failure("JOURNEY_NOT_SEALED")
  if journeys~hasIndex(journey~journeyId) then return .BrandJourneyResult~failure("JOURNEY_ALREADY_REGISTERED")
  journeys[journey~journeyId]=journey
  self~recordRelationship("CONTAINS",journey,"registered privacy-minimised brand journey","INTERNAL")
  self~alchemyTouch("REGISTER_JOURNEY")
  self~alchemyInstrument("BRAND.JOURNEY.REGISTERED",journey~pointId)
  return .BrandJourneyResult~success(journey)
::method journey
  expose journeys
  use arg idArg
  return journeys~at(idArg~string)

::requires "AlchemyObject.cls"
