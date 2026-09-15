/* FlyLo legal model. Regulatory semantics are compiler-admitted Legal Effect
   artefacts, not prompt text and not model-owned policy. */

::class FlyLoLegalRules public

::method build class
  provider = .LegalSha512DigestProvider~new("flylo-legal-sha512")
  verifier = .LegalSourceVerifier~new(provider, "flylo-legal-source-verifier")
  unit = .LegalCompilationUnit~new("FLYLO-PASSENGER-RIGHTS", "2026.08.24", "flylo-legal-compiler", "0.1")

  ignored = self~addSource(unit, verifier, provider, -
    "UK261", "LEGISLATION", "UK passenger rights: Regulation 261/2004 as amended", -
    "UK PARLIAMENT / SECRETARY OF STATE FOR TRANSPORT", "UNITED_KINGDOM", -
    "2026-08-24-expression", "https://www.legislation.gov.uk/uksi/2023/1370", self~ukSourceText)

  ignored = self~addProvision(unit, verifier, provider, "UK261", "ART3_SCOPE", "Article 3 / UK territorial scope", self~ukScopeText)
  ignored = self~addProvision(unit, verifier, provider, "UK261", "ART6_DELAY", "Article 6 delay", self~ukDelayText)
  ignored = self~addProvision(unit, verifier, provider, "UK261", "ART8_REIMBURSE_REROUTE", "Article 8 reimbursement or rerouting", self~ukRefundText)
  ignored = self~addProvision(unit, verifier, provider, "UK261", "ART9_CARE", "Article 9 care", self~ukCareText)
  ignored = self~addProvision(unit, verifier, provider, "UK261", "ART7_COMPENSATION", "Article 7 compensation", self~ukCompensationText)

  ignored = self~addSource(unit, verifier, provider, -
    "US14CFR260", "REGULATION", "14 CFR Part 260 - Refunds for Airline Fare and Ancillary Service Fees", -
    "US DEPARTMENT OF TRANSPORTATION", "UNITED_STATES", -
    "2026-08-20-expression", "https://www.ecfr.gov/current/title-14/chapter-II/subchapter-A/part-260", self~usSourceText)

  ignored = self~addProvision(unit, verifier, provider, "US14CFR260", "260.2", "14 CFR 260.2 definitions", self~usDefinitionsText)
  ignored = self~addProvision(unit, verifier, provider, "US14CFR260", "260.6", "14 CFR 260.6 fare refunds", self~usRefundText)

  ignored = self~addSource(unit, verifier, provider, -
    "USDOT-REN-2026", "ADMINISTRATIVE_ORDER", "DOT enforcement discretion for merely renumbered flights", -
    "US DEPARTMENT OF TRANSPORTATION", "UNITED_STATES", -
    "2026-07-08-expression", "https://www.transportation.gov/airconsumer/ticket-refunds", self~usEnforcementText)
  ignored = self~addProvision(unit, verifier, provider, "USDOT-REN-2026", "ENFORCEMENT-DISCRETION", "July 2026 enforcement discretion", self~usEnforcementText)

  ukTemporal = .LegalTemporalScope~new("2023-12-14", "2023-12-14", "", "2023-12-14", "")
  usTemporal = .LegalTemporalScope~new("2024-05-16", "2024-05-16", "", "2024-05-16", "")
  usEnforcementTemporal = .LegalTemporalScope~new("2026-07-08", "2026-07-08", "2027-07-07", "2026-07-08", "2027-07-07")

  /* UK: cancelled flight -> reimbursement/rerouting choice. */
  norm = .LegalNorm~new("UK261-CANCEL-CHOICE", "UK261", "ART8_REIMBURSE_REROUTE", "RIGHT", "OFFER_REFUND_OR_REROUTE", "REQUIRES_OBLIGATION", "AIR_PASSENGER", "Cancellation on a covered UK departure requires reimbursement or rerouting choice", ukTemporal)
  ignored = self~ukDeparture(norm)
  call must norm~addCondition(.LegalPredicate~new("FLIGHT_CANCELLED", "KNOWN_TRUE"))
  ignored = self~propose(unit, norm, "UK-P-001", unit~provisionReference("UK261", "ART8_REIMBURSE_REROUTE"))

  /* UK: 5h delay and passenger elects not to travel -> reimbursement. */
  norm = .LegalNorm~new("UK261-DELAY5-REFUND", "UK261", "ART8_REIMBURSE_REROUTE", "RIGHT", "OFFER_DELAY_REFUND", "REQUIRES_OBLIGATION", "AIR_PASSENGER", "Five-hour delay can create reimbursement right when passenger elects not to travel", ukTemporal)
  ignored = self~ukDeparture(norm)
  call must norm~addCondition(.LegalPredicate~new("DELAY_AT_LEAST_5H", "KNOWN_TRUE"))
  call must norm~addCondition(.LegalPredicate~new("PASSENGER_CHOOSES_NOT_TO_TRAVEL", "KNOWN_TRUE"))
  ignored = self~propose(unit, norm, "UK-P-002", unit~provisionReference("UK261", "ART8_REIMBURSE_REROUTE"))

  /* UK: route-specific long-haul care threshold. Derived threshold fact keeps
     distance arithmetic outside the legal rule while preserving its evidence. */
  norm = .LegalNorm~new("UK261-LONGHAUL-CARE", "UK261", "ART9_CARE", "OBLIGATION", "PROVIDE_CARE", "REQUIRES_OBLIGATION", "AIR_PASSENGER", "Care is due when the applicable UK261 delay-care threshold has been reached", ukTemporal)
  ignored = self~ukDeparture(norm)
  call must norm~addCondition(.LegalPredicate~new("CARE_THRESHOLD_REACHED", "KNOWN_TRUE"))
  ignored = self~propose(unit, norm, "UK-P-003", unit~provisionReference("UK261", "ART9_CARE"))

  /* UK: 3h arrival delay compensation. Unknown extraordinary circumstances
     deliberately causes REVIEW_REQUIRED rather than model guesswork. */
  norm = .LegalNorm~new("UK261-DELAY3-COMP", "UK261", "ART7_COMPENSATION", "RIGHT", "ASSESS_FIXED_COMPENSATION", "REQUIRES_OBLIGATION", "AIR_PASSENGER", "Three-hour arrival delay engages compensation subject to extraordinary-circumstances defence", ukTemporal)
  ignored = self~ukDeparture(norm)
  call must norm~addCondition(.LegalPredicate~new("ARRIVAL_DELAY_AT_LEAST_3H", "KNOWN_TRUE"))
  call must norm~addException(.LegalPredicate~new("EXTRAORDINARY_CIRCUMSTANCES", "KNOWN_TRUE"))
  ignored = self~propose(unit, norm, "UK-P-004", unit~provisionReference("UK261", "ART7_COMPENSATION"))

  /* US Part 260: substantive refund entitlement. */
  norm = .LegalNorm~new("US260-CANCEL-CHANGE-REFUND", "US14CFR260", "260.6", "OBLIGATION", "ISSUE_US_REFUND", "REQUIRES_OBLIGATION", "AIR_PASSENGER", "Merchant-of-record carrier must refund cancelled or significantly changed covered itinerary when alternative is not accepted", usTemporal)
  call must norm~addJurisdiction(.LegalJurisdictionClaim~new("US_DOT", "UNITED_STATES", "AIR_PASSENGER", "flight to/from/within United States"))
  call must norm~addCondition(.LegalPredicate~new("US_COVERED_FLIGHT", "KNOWN_TRUE"))
  call must norm~addCondition(.LegalPredicate~new("FLYLO_MERCHANT_OF_RECORD", "KNOWN_TRUE"))
  call must norm~addCondition(.LegalPredicate~new("CANCELLED_OR_US_SIGNIFICANT_CHANGE", "KNOWN_TRUE"))
  call must norm~addCondition(.LegalPredicate~new("PASSENGER_DID_NOT_ACCEPT_ALTERNATIVE", "KNOWN_TRUE"))
  ignored = self~propose(unit, norm, "US-P-001", unit~provisionReference("US14CFR260", "260.6"))

  norm = .LegalNorm~new("US260-REFUND-DEADLINE", "US14CFR260", "260.2", "OBLIGATION", "MEET_US_REFUND_DEADLINE", "REQUIRES_OBLIGATION", "AIR_PASSENGER", "Prompt refund deadline is seven business days for credit-card purchases or twenty calendar days for other payment forms", usTemporal)
  call must norm~addJurisdiction(.LegalJurisdictionClaim~new("US_DOT", "UNITED_STATES", "AIR_PASSENGER", "flight to/from/within United States"))
  call must norm~addCondition(.LegalPredicate~new("US_REFUND_DUE", "KNOWN_TRUE"))
  ignored = self~propose(unit, norm, "US-P-002", unit~provisionReference("US14CFR260", "260.2"))

  /* Enforcement discretion is modelled separately from entitlement. It must
     never suppress the substantive refund norm. */
  norm = .LegalNorm~new("USDOT-REN-ENFORCEMENT-POSTURE", "USDOT-REN-2026", "ENFORCEMENT-DISCRETION", "STATUS", "ASSESS_US_ENFORCEMENT_POSTURE", "STATUS_EFFECT", "AIR_PASSENGER", "Temporary enforcement pause for merely renumbered flights without significant change or delay", usEnforcementTemporal)
  call must norm~addJurisdiction(.LegalJurisdictionClaim~new("US_DOT", "UNITED_STATES", "AIR_PASSENGER", "DOT enforcement posture"))
  call must norm~addCondition(.LegalPredicate~new("FLIGHT_MERELY_RENUMBERED", "KNOWN_TRUE"))
  call must norm~addCondition(.LegalPredicate~new("PASSENGER_REBOOKED_ON_RENUMBERED_FLIGHT", "KNOWN_TRUE"))
  call must norm~addCondition(.LegalPredicate~new("NO_US_SIGNIFICANT_CHANGE_OR_DELAY", "KNOWN_TRUE"))
  ignored = self~propose(unit, norm, "US-P-003", unit~provisionReference("USDOT-REN-2026", "ENFORCEMENT-DISCRETION"))

  report = .LegalRuleCompiler~new~compile(unit)
  if \report~ok then do
    detail = "FlyLo legal compilation failed"
    if report~diagnostics~items > 0 then detail ||= ": " || report~diagnostics[1]~code
    raise syntax 88.900 array(detail)
  end
  return report~generation

::method assess class
  use arg generation, actionCode, eventId, eventDate, facts, includeUk = .true, includeUs = .true
  context = .LegalContext~new(eventId, eventDate, eventDate, facts)
  if includeUk then ignored = context~addJurisdiction(.LegalJurisdictionClaim~new("UNITED_KINGDOM", "UNITED_KINGDOM", "AIR_PASSENGER", "departure from United Kingdom"))
  if includeUs then do
    ignored = context~addJurisdiction(.LegalJurisdictionClaim~new("US_DOT", "UNITED_STATES", "AIR_PASSENGER", "flight to/from United States"))
    ignored = context~bindSource("USDOT-REN-2026", "public DOT enforcement document in FlyLo legal framework")
  end
  return .LegalEffectEngine~new~evaluate(.LegalAction~new(actionCode), generation, context)

::method ukDeparture private class
  use arg norm
  call must norm~addJurisdiction(.LegalJurisdictionClaim~new("UNITED_KINGDOM", "UNITED_KINGDOM", "AIR_PASSENGER", "flight departs from UK airport"))
  call must norm~addCondition(.LegalPredicate~new("DEPARTS_UK", "KNOWN_TRUE"))
  return norm

::method propose private class
  use arg unit, norm, proposalId, reference
  p = .LegalCompileProposal~new(proposalId, "NORM", norm, "flylo-legal-authoring", "TOOL", "reviewed")
  call must p~addEvidenceReference(reference)
  call must unit~addProposal(p)
  return p

::method addSource private class
  use arg unit, verifier, provider, sourceId, sourceKind, title, authority, jurisdiction, expressionId, uri, text
  sourceDoc = .directory~new
  sourceDoc["content"] = text
  identity = .LegalSourceIdentity~new(sourceId, sourceKind, expressionId, uri, "sha512:" || provider~digest(text), authority, jurisdiction, "VERIFIED")
  source = .NormativeSource~new(sourceId, sourceKind, title, authority, jurisdiction)
  call must unit~addSource(identity, source)
  call must unit~verifySource(sourceId, .LegalVerificationMaterial~fromText(sourceDoc, text, uri, "RAW_NORMATIVE_SOURCE"), verifier)
  return source

::method addProvision private class
  use arg unit, verifier, provider, sourceId, provisionId, locator, text
  doc = .directory~new
  doc["content"] = text
  expressionId = unit~sourceIdentity(sourceId)~expressionId
  ref = .LegalProvisionReference~new(sourceId, provisionId, expressionId, locator, "sha512:" || provider~digest(text), text, "VERIFIED")
  provision = .LegalProvision~new(sourceId, provisionId, "ACTIVE", "BASE", text)
  call must unit~addProvision(ref, provision)
  call must unit~verifyProvision(sourceId, provisionId, .LegalVerificationMaterial~fromText(doc, text, locator, "PROVISION_LEXICAL_TEXT"), verifier)
  return provision

::method ukSourceText private class
  return "UK Regulation 261/2004 passenger rights, retained in UK law and amended by SI 2023/1370. FlyLo retained representation for compiler verification; authoritative publisher chain remains external."
::method ukScopeText private class
  return "UK passenger rights apply to a flight departing from an airport in the United Kingdom on any airline."
::method ukDelayText private class
  return "Delay duties include care at the applicable threshold; a delay of at least five hours can give a passenger a reimbursement choice; arrival delay of three hours or more can engage Article 7 compensation, subject to extraordinary circumstances."
::method ukRefundText private class
  return "For cancellation the passenger is offered reimbursement for unused travel or rerouting. A five-hour delay can also create reimbursement rights when the passenger chooses not to travel."
::method ukCareText private class
  return "Care and assistance include appropriate refreshments and, where necessary, accommodation and transport; the delay threshold varies with distance and route category."
::method ukCompensationText private class
  return "Article 7 compensation applies in qualifying cancellation and long-delay cases. The 2023 amendment codifies three-hour arrival-delay compensation and the extraordinary-circumstances defence."
::method usSourceText private class
  return "14 CFR Part 260 applies to covered scheduled passenger flights to, from, or within the United States and requires prompt refunds for covered cancellations, significant changes, unprovided ancillary services, and specified baggage delay cases."
::method usDefinitionsText private class
  return "Part 260 defines covered flight, automatic refund, prompt refund, and significant delay or change. For international itineraries a six-hour time change is significant. Prompt refund is seven business days for credit-card purchases and twenty calendar days for other payment forms."
::method usRefundText private class
  return "A covered carrier that is merchant of record must provide a full and prompt refund for a cancelled or significantly delayed or changed covered flight where the consumer does not accept the changed flight, rebooking, voucher, credit, or other compensation."
::method usEnforcementText private class
  return "DOT July 2026 enforcement discretion extends through 7 July 2027 for merely renumbered flights when the passenger is rebooked and the itinerary operates without significant change or delay. It is enforcement posture and does not rewrite the underlying Part 260 rule."

::routine must
  use arg result
  if result~isA(.LegalResult) then if \result~ok then raise syntax 88.900 array(result~code, result~detail)
  return result

::requires "LegalRuntimeCryptoBridge.cls"
