/* OurLadyAir Shannon chatbot.
 *
 * The model is deliberately commercial and may propose unsafe or ineligible
 * upsell prose. It cannot emit directly to the passenger. Legal Effect is
 * evaluated first, projected into HardWorld as facts, and HardWorld owns final
 * action policy. v0.2 adds target-scoped offer governance for booking parties.
 */

::class ShannonTurnResult public
::attribute turnNumber get
::attribute passengerText get
::attribute modelProposal get
::attribute finalText get
::attribute mode get
::attribute world get
::attribute hardWorldRun get
::attribute legalAssessments get
::attribute auditRecord get
::attribute salesAllowed get
::attribute booking get
::attribute commercialPlan get

::method init
  expose turnNumber passengerText modelProposal finalText mode world hardWorldRun legalAssessments auditRecord salesAllowed booking commercialPlan
  use arg turnNumberArg, passengerTextArg, modelProposalArg, finalTextArg, modeArg, worldArg, hardRunArg, legalArg, auditArg, salesAllowedArg, bookingArg, commercialPlanArg
  turnNumber = turnNumberArg
  passengerText = passengerTextArg
  modelProposal = modelProposalArg
  finalText = finalTextArg
  mode = modeArg
  world = worldArg
  hardWorldRun = hardRunArg
  legalAssessments = legalArg
  auditRecord = auditArg
  salesAllowed = salesAllowedArg
  booking = bookingArg
  commercialPlan = commercialPlanArg

::class ShannonChatSession public
::attribute sessionId get
::attribute world get
::attribute legalPolicy get
::attribute ryta get
::attribute model get
::attribute turnNumber get
::attribute booking get

::method init
  expose sessionId world legalPolicy ryta model extractor turnNumber booking
  use arg sessionIdArg = 'SHANNON-DEMO', policyPath = '', modelArg = .nil, bookingArg = .nil, legalPolicyArg = .nil
  sessionId = sessionIdArg~string
  if policyPath == '' then raise syntax 88.900 array('ShannonChatSession requires the operator policy path')
  world = .RYTAWorldState~new(sessionId || '-TURN-0')
  extractor = .ShannonFactExtractor~new
  if modelArg == .nil then model = .ShannonScriptedSalesModel~new
  else model = modelArg
  if bookingArg == .nil then booking = .ShannonBooking~defaultSingleAdult
  else do
    booking = bookingArg
    if \booking~sealed then ignored = booking~seal
  end
  ignored = booking~applyWorldEvidence(world)
  if legalPolicyArg == .nil then legalPolicy = .ShannonLegalPolicy~new(policyPath)
  else legalPolicy = legalPolicyArg
  ryta = .VirtualRYTA~new
  self~installLegalHardWorldOverlay
  turnNumber = 0

::method respond
  expose sessionId world legalPolicy ryta model extractor turnNumber booking
  use arg passengerText
  turnNumber += 1
  world~snapshotOid = sessionId || '-TURN-' || turnNumber
  ignored = extractor~apply(passengerText, world)

  /* Deliberately ask the sales model first. Its answer remains an inert proposal. */
  proposal = model~propose(passengerText, world, booking)

  legal = .directory~new
  legal['SELL_PRODUCT'] = legalPolicy~evaluateAction('SELL_PRODUCT', world)
  legal['UPSELL'] = legalPolicy~evaluateAction('UPSELL', world)
  legal['BIG_UPSELL'] = legalPolicy~evaluateAction('BIG_UPSELL', world)
  legal['WARNING'] = legalPolicy~evaluateAction('WARNING', world)
  legal['ASK_INFORMATION'] = legalPolicy~evaluateAction('ASK_INFORMATION', world)

  /* The assessment is not itself a HardWorld fact. Each action evaluation is
     pinned, projected by the upstream v0.5 compatibility adapter explicitly
     supplied by the loaded Legal Effect engine, then promoted into this turn's world.
     Promotion and display remain separate events. */
  do key over legal
    applyResult = legalPolicy~applyEvaluation(legal[key], world)
    if applyResult~conflicts > 0 then raise syntax 88.900 array('Conflicting Legal Effect promotions for ' || key)
  end

  legalSalesBlocked = self~isBlocked(legal['SELL_PRODUCT']) | self~isBlocked(legal['UPSELL']) | self~isBlocked(legal['BIG_UPSELL'])
  hardRun = ryta~evaluate(world)
  sellAllowed = hardRun~action(.RYTAConstant~ACTION_SELL_PRODUCT)~finalSelected | hardRun~action(.RYTAConstant~ACTION_UPSELL)~finalSelected | hardRun~action(.RYTAConstant~ACTION_BIG_UPSELL)~finalSelected

  /* Candidate-level governance runs even if the global turn is blocked. That
     preserves evidence of what Shannon proposed and why each target was denied. */
  commercialPlan = self~governCommercialOffers(proposal)

  if hardRun~action(.RYTAConstant~ACTION_ESCALATE)~finalSelected then do
    mode = 'ESCALATE'
    final = 'I cannot safely resolve that from the available facts. I have stopped the sales flow and this needs a human OurLadyAir agent before any baggage or medication advice continues.'
    sellAllowed = .false
  end
  else if hardRun~action(.RYTAConstant~ACTION_WARNING)~finalSelected then do
    mode = 'SAFETY_REMEDIATION'
    final = 'Essential medication must remain in your personal custody or in a bag that is guaranteed to stay in the cabin with you. Do not place it solely in a bag that may be put in the hold. I will not offer an upgrade, beer, crisps, or any other extra while that custody risk is unresolved.'
    sellAllowed = .false
  end
  else if hardRun~action(.RYTAConstant~ACTION_ASK_INFORMATION)~finalSelected then do
    mode = 'NEEDS_INFORMATION'
    final = 'Before I can give baggage advice, I need to resolve the safety facts: what is the item, is it essential or time-critical, and is the bag guaranteed to remain in the cabin with you? I will not offer extras until that is clear.'
    sellAllowed = .false
  end
  else if world~isKnownTrue('COMPLAINT_INTENT') | legalSalesBlocked then do
    mode = 'NONCOMMERCIAL_REVIEW'
    final = 'I have suspended sales messaging while this complaint or safety issue is live. I can record the issue and route it to a human OurLadyAir agent; I will not turn the complaint into another upgrade offer.'
    sellAllowed = .false
  end
  else do
    mode = 'NORMAL_COMMERCIAL'
    if proposal~metadata~hasIndex('baseText') then final = proposal~metadata['baseText']
    else final = proposal~text
    governedOfferText = commercialPlan~renderPermitted
    if governedOfferText \== '' then final = final || ' ' || governedOfferText
  end

  audit = self~buildAudit(passengerText, proposal, final, mode, hardRun, legal, sellAllowed, commercialPlan)
  return .ShannonTurnResult~new(turnNumber, passengerText, proposal, final, mode, world, hardRun, legal, audit, sellAllowed, booking, commercialPlan)

::method governCommercialOffers private
  expose booking world legalPolicy ryta
  use arg proposal
  candidates = .array~new
  if proposal~metadata~hasIndex('offerCandidates') then candidates = proposal~metadata['offerCandidates']
  decisions = .array~new

  do candidate over candidates
    passenger = booking~passenger(candidate~targetPassengerId)
    targetMissing = .false
    if passenger == .nil then do
      targetMissing = .true
      passenger = .ShannonPassenger~new(candidate~targetPassengerId, candidate~targetDisplayName, 'UNKNOWN', 'NO_BOOKING_MATCH')
    end

    offerWorld = self~offerWorld(candidate, passenger)
    offerLegal = legalPolicy~evaluateAction('SELL_PRODUCT', offerWorld)
    offerLegalBlocked = self~isBlocked(offerLegal)
    offerApply = legalPolicy~applyEvaluation(offerLegal, offerWorld)
    if offerApply~conflicts > 0 then raise syntax 88.900 array('Conflicting target-scoped Legal Effect promotions for ' || candidate~offerId)
    offerRun = ryta~evaluate(offerWorld)
    sellAction = offerRun~action(.RYTAConstant~ACTION_SELL_PRODUCT)
    permitted = sellAction~finalSelected

    if targetMissing then reason = 'TARGET_NOT_IN_AUTHORITATIVE_BOOKING'
    else if offerLegalBlocked then reason = 'LEGAL_' || offerLegal~status
    else if \permitted then reason = 'HARDWORLD_' || sellAction~disposition
    else reason = 'PERMITTED_FOR_TARGET'

    decisions~append(.ShannonOfferDecision~new(candidate, passenger~role, offerLegal, offerRun, permitted, reason))
  end
  return .ShannonCommercialPlan~new(candidates, decisions)

::method offerWorld private
  expose world booking
  use arg candidate, passenger
  offerWorld = .RYTAWorldState~new(world~snapshotOid || '-OFFER-' || candidate~offerId)

  do factName over world~facts~allIndexes
    sourceFact = world~facts[factName]
    select
      when sourceFact~knowledgeState == .RYTAConstant~KNOWLEDGE_KNOWN then ignored = offerWorld~putKnown(factName, sourceFact~value, sourceFact~source, sourceFact~authority, sourceFact~evidence)
      when sourceFact~knowledgeState == .RYTAConstant~KNOWLEDGE_CONFLICT then ignored = offerWorld~putConflict(factName, sourceFact~source, sourceFact~authority, sourceFact~evidence)
      otherwise ignored = offerWorld~putUnknown(factName, sourceFact~source, sourceFact~authority, sourceFact~evidence)
    end
  end

  targetSource = 'BOOKING/' || booking~bookingId || '/' || passenger~passengerId
  ignored = offerWorld~putKnown('TARGETED_OFFER_EVALUATION', .true, 'SHANNON_GOVERNOR', 'DETERMINISTIC', candidate)
  ignored = offerWorld~putKnown('OFFER_AGE_RESTRICTED', candidate~ageRestricted, candidate, 'MODEL_PROPOSAL', candidate)
  isSeatOffer = candidate~productClass == 'SEAT_RESERVATION'
  ignored = offerWorld~putKnown('OFFER_SEAT_RESERVATION', isSeatOffer, candidate, 'MODEL_PROPOSAL', candidate)
  if passenger~role == 'ADULT' then do
    ignored = offerWorld~putKnown('TARGET_IS_ADULT', .true, targetSource, passenger~authority, passenger)
    ignored = offerWorld~putKnown('TARGET_IS_CHILD', .false, targetSource, passenger~authority, passenger)
  end
  else if passenger~role == 'CHILD' then do
    ignored = offerWorld~putKnown('TARGET_IS_ADULT', .false, targetSource, passenger~authority, passenger)
    ignored = offerWorld~putKnown('TARGET_IS_CHILD', .true, targetSource, passenger~authority, passenger)
  end
  else do
    ignored = offerWorld~putUnknown('TARGET_IS_ADULT', targetSource, passenger~authority, passenger)
    ignored = offerWorld~putUnknown('TARGET_IS_CHILD', targetSource, passenger~authority, passenger)
  end

  select
    when passenger~ageRestrictedEligibility == 'ELIGIBLE' then do
      ignored = offerWorld~putKnown('TARGET_AGE_RESTRICTED_ELIGIBLE', .true, targetSource, passenger~authority, passenger)
      ignored = offerWorld~putKnown('TARGET_AGE_RESTRICTED_INELIGIBLE', .false, targetSource, passenger~authority, passenger)
      ignored = offerWorld~putKnown('TARGET_ELIGIBILITY_UNKNOWN', .false, targetSource, passenger~authority, passenger)
    end
    when passenger~ageRestrictedEligibility == 'INELIGIBLE' then do
      ignored = offerWorld~putKnown('TARGET_AGE_RESTRICTED_ELIGIBLE', .false, targetSource, passenger~authority, passenger)
      ignored = offerWorld~putKnown('TARGET_AGE_RESTRICTED_INELIGIBLE', .true, targetSource, passenger~authority, passenger)
      ignored = offerWorld~putKnown('TARGET_ELIGIBILITY_UNKNOWN', .false, targetSource, passenger~authority, passenger)
    end
    otherwise do
      ignored = offerWorld~putUnknown('TARGET_AGE_RESTRICTED_ELIGIBLE', targetSource, passenger~authority, passenger)
      ignored = offerWorld~putUnknown('TARGET_AGE_RESTRICTED_INELIGIBLE', targetSource, passenger~authority, passenger)
      ignored = offerWorld~putKnown('TARGET_ELIGIBILITY_UNKNOWN', .true, targetSource, passenger~authority, passenger)
    end
  end


  select
    when passenger~seatReservationStatus == 'NOT_PURCHASED' then do
      ignored = offerWorld~putKnown('TARGET_SEAT_RESERVATION_MISSING', .true, targetSource, passenger~authority, passenger)
      ignored = offerWorld~putKnown('TARGET_SEAT_RESERVATION_NOT_MISSING', .false, targetSource, passenger~authority, passenger)
      ignored = offerWorld~putKnown('TARGET_SEAT_RESERVATION_UNKNOWN', .false, targetSource, passenger~authority, passenger)
    end
    when passenger~seatReservationStatus == 'RESERVED' | passenger~seatReservationStatus == 'NOT_APPLICABLE' then do
      ignored = offerWorld~putKnown('TARGET_SEAT_RESERVATION_MISSING', .false, targetSource, passenger~authority, passenger)
      ignored = offerWorld~putKnown('TARGET_SEAT_RESERVATION_NOT_MISSING', .true, targetSource, passenger~authority, passenger)
      ignored = offerWorld~putKnown('TARGET_SEAT_RESERVATION_UNKNOWN', .false, targetSource, passenger~authority, passenger)
    end
    otherwise do
      ignored = offerWorld~putUnknown('TARGET_SEAT_RESERVATION_MISSING', targetSource, passenger~authority, passenger)
      ignored = offerWorld~putUnknown('TARGET_SEAT_RESERVATION_NOT_MISSING', targetSource, passenger~authority, passenger)
      ignored = offerWorld~putKnown('TARGET_SEAT_RESERVATION_UNKNOWN', .true, targetSource, passenger~authority, passenger)
    end
  end
  return offerWorld

::method installLegalHardWorldOverlay private
  expose ryta
  rules = ryta~stateRules
  do state over rules~states
    do actionCode over .array~of(.RYTAConstant~ACTION_SELL_PRODUCT, .RYTAConstant~ACTION_UPSELL, .RYTAConstant~ACTION_BIG_UPSELL)
      /* The loaded Legal Effect engine is projected through the explicitly-
         versioned HardWorld v0.5 compatibility bridge. BLOCKED and REVIEW_REQUIRED
         both fail closed for commercial emission. */
      do suffix over .array~of('ACTION_BLOCKED', 'ACTION_REVIEW_REQUIRED')
        factName = 'LEGAL_' || actionCode || '_' || suffix
        policyId = 'LEGAL-V05BRIDGE-' || state || '-' || actionCode || '-' || suffix
        policy = .RYTAActionPolicy~new(policyId, state, actionCode, .RYTAConstant~DISPOSITION_PROHIBITED, 'Loaded Legal Effect engine via HardWorld v0.5 compatibility bridge blocks commercial action', '', .RYTAConstant~OVERRIDE_NON_OVERRIDEABLE)
        conditional = .RYTAConditionalActionPolicy~new(policy, 'ALL')
        conditional~addClause(.HardWorldClause~new(factName, 'KNOWN_TRUE'))
        ignored = rules~addConditionalPolicy(conditional)
      end
    end

    warningPolicy = .RYTAActionPolicy~new('LEGAL-V05BRIDGE-' || state || '-WARNING', state, .RYTAConstant~ACTION_WARNING, .RYTAConstant~DISPOSITION_REQUIRED, 'Loaded Legal Effect engine via validated compatibility bridge requires mandatory safety warning')
    warningConditional = .RYTAConditionalActionPolicy~new(warningPolicy, 'ALL')
    warningConditional~addClause(.HardWorldClause~new('LEGAL_WARNING_ACTION_CONDITIONAL', 'KNOWN_TRUE'))
    ignored = rules~addConditionalPolicy(warningConditional)

    askPolicy = .RYTAActionPolicy~new('LEGAL-V05BRIDGE-' || state || '-ASK', state, .RYTAConstant~ACTION_ASK_INFORMATION, .RYTAConstant~DISPOSITION_REQUIRED, 'Loaded Legal Effect engine via validated compatibility bridge requires missing safety information')
    askConditional = .RYTAConditionalActionPolicy~new(askPolicy, 'ALL')
    askConditional~addClause(.HardWorldClause~new('LEGAL_ASK_INFORMATION_ACTION_CONDITIONAL', 'KNOWN_TRUE'))
    ignored = rules~addConditionalPolicy(askConditional)
  end

::method isBlocked private
  use arg assessment
  return assessment~status == 'BLOCKED' | assessment~status == 'REVIEW_REQUIRED'

::method buildAudit private
  expose sessionId legalPolicy turnNumber world booking
  use arg passengerText, proposal, finalText, mode, hardRun, legal, salesAllowed, commercialPlan
  audit = .directory~new
  audit['schema'] = 'ourladyair.shannon.turn.v3'
  audit['sessionId'] = sessionId
  audit['turn'] = turnNumber
  audit['passengerText'] = passengerText

  bookingAudit = .directory~new
  bookingAudit['bookingId'] = booking~bookingId
  bookingAudit['sourceFormat'] = booking~sourceFormat
  bookingAudit['sourceAdapter'] = booking~sourceAdapter
  bookingAudit['sourceEnvelopeStatus'] = booking~sourceEnvelopeStatus
  bookingAudit['sourceParserName'] = booking~sourceParserName
  bookingAudit['sourceAnnotationCount'] = booking~sourceAnnotationCount
  bookingAudit['sourceDocument'] = booking~sourceDocument
  bookingAudit['sourceEnvelopeReport'] = booking~sourceEnvelopeReport
  passengerAudit = .array~new
  do passenger over booking~passengers
    view = .directory~new
    view['passengerId'] = passenger~passengerId
    view['displayName'] = passenger~displayName
    view['role'] = passenger~role
    view['authority'] = passenger~authority
    view['ageRestrictedEligibility'] = passenger~ageRestrictedEligibility
    view['pnr'] = passenger~pnr
    view['ticketNumber'] = passenger~ticketNumber
    view['dateOfBirth'] = passenger~dateOfBirth
    view['passengerType'] = passenger~passengerType
    view['seat'] = passenger~seat
    view['seatReservationStatus'] = passenger~seatReservationStatus
    view['essentialMedication'] = passenger~essentialMedication
    view['custodyUnknown'] = passenger~custodyUnknown
    view['sourceEvidence'] = passenger~sourceEvidence
    view['sourcePaths'] = passenger~sourcePaths
    passengerAudit~append(view)
  end
  bookingAudit['passengers'] = passengerAudit
  audit['booking'] = bookingAudit

  audit['model'] = .directory~new
  audit['model']['modelId'] = proposal~modelId
  audit['model']['promptId'] = proposal~promptId
  audit['model']['proposal'] = proposal~text
  audit['model']['offerCandidates'] = commercialPlan~candidates
  audit['model']['modelGrossCents'] = commercialPlan~modelGrossCents

  audit['governance'] = .directory~new
  audit['governance']['mode'] = mode
  audit['governance']['hardWorldState'] = hardRun~state
  audit['governance']['hardWorldRule'] = hardRun~winningRule
  audit['governance']['salesAllowed'] = salesAllowed
  audit['governance']['legalApiVersion'] = legalPolicy~legalApiVersion
  audit['governance']['legalBuildVersion'] = legalPolicy~legalBuildVersion
  audit['governance']['legalPromotionBridge'] = 'HardWorld LegalEffectV05PromotionAdapter compatibility contract'
  audit['governance']['legalGeneration'] = legalPolicy~generation~generationId
  audit['governance']['legalSemanticIdentity'] = legalPolicy~semanticIdentity
  legalStatus = .directory~new
  legalAuthority = .directory~new
  do key over legal
    legalStatus[key] = legal[key]~status
    legalAuthority[key] = legal[key]~promotionAuthority
  end
  audit['governance']['legalStatus'] = legalStatus
  audit['governance']['legalPromotionAuthority'] = legalAuthority
  hardActions = .directory~new
  do action over hardRun~actions
    actionView = .directory~new
    actionView['disposition'] = action~disposition
    actionView['selected'] = action~finalSelected
    hardActions[action~actionCode] = actionView
  end
  audit['governance']['hardWorldActions'] = hardActions

  commercialAudit = .directory~new
  commercialAudit['modelGrossCents'] = commercialPlan~modelGrossCents
  commercialAudit['governedGrossCents'] = commercialPlan~governedGrossCents
  commercialAudit['permittedCount'] = commercialPlan~permittedCount
  commercialAudit['blockedCount'] = commercialPlan~blockedCount
  commercialAudit['decisions'] = commercialPlan~decisions
  decisionViews = .array~new
  do decision over commercialPlan~decisions
    candidate = decision~candidate
    decisionView = .directory~new
    decisionView['offerId'] = candidate~offerId
    decisionView['productId'] = candidate~productId
    decisionView['productClass'] = candidate~productClass
    decisionView['targetPassengerId'] = candidate~targetPassengerId
    decisionView['targetDisplayName'] = candidate~targetDisplayName
    decisionView['targetRole'] = decision~targetRole
    targetPassenger = booking~passenger(candidate~targetPassengerId)
    if targetPassenger == .nil then decisionView['ageRestrictedEligibility'] = 'UNKNOWN'
    else do
      decisionView['ageRestrictedEligibility'] = targetPassenger~ageRestrictedEligibility
      decisionView['seatReservationStatus'] = targetPassenger~seatReservationStatus
    end
    decisionView['priceCents'] = candidate~priceCents
    decisionView['legalStatus'] = decision~legalAssessment~status
    decisionView['legalPromotionAuthority'] = decision~legalAssessment~promotionAuthority
    decisionView['hardWorldState'] = decision~hardWorldRun~state
    decisionView['hardWorldDisposition'] = decision~hardWorldRun~action(.RYTAConstant~ACTION_SELL_PRODUCT)~disposition
    decisionView['hardWorldSelected'] = decision~hardWorldRun~action(.RYTAConstant~ACTION_SELL_PRODUCT)~finalSelected
    decisionView['permitted'] = decision~permitted
    decisionView['reason'] = decision~reason
    decisionViews~append(decisionView)
  end
  commercialAudit['decisionViews'] = decisionViews
  audit['commercial'] = commercialAudit
  audit['finalText'] = finalText
  return audit

::requires 'ShannonFactExtractor.cls'
::requires 'ShannonModel.cls'
::requires 'ShannonLegalPolicy.cls'
::requires 'ShannonBooking.cls'
::requires 'ShannonCommercial.cls'
::requires 'VirtualRYTA.cls'
