/* Source-anchored Legal Effect policy for Shannon.
 * The authority here is the fictional operator's own published control policy,
 * not the CAA report. The CAA report is design evidence for the demonstrator.
 */

::class ShannonLegalFactEvidence public
::attribute name get
::attribute knowledgeState get
::attribute value get
::attribute source get
::attribute authority get

::method init
  expose name knowledgeState value source authority
  use arg richFact
  if richFact == .nil then raise syntax 88.900 array('Shannon legal fact evidence requires a fact')
  name = richFact~name
  knowledgeState = richFact~knowledgeState
  value = richFact~value
  source = richFact~source
  authority = richFact~authority

::method algorithmCanonicalText
  expose name knowledgeState value source authority
  text = 'SHANNON_LEGAL_FACT_EVIDENCE_V1' || '0a'x
  text = text || self~field('NAME', name)
  text = text || self~field('KNOWLEDGE', knowledgeState)
  text = text || self~field('VALUE', self~canonicalValue(value))
  text = text || self~field('SOURCE', source)
  text = text || self~field('AUTHORITY', authority)
  return text

::method canonicalValue private
  use arg item
  if item == .nil then return 'NULL'
  if item == .true then return 'BOOLEAN:TRUE'
  if item == .false then return 'BOOLEAN:FALSE'
  if item~class == .String then return 'TEXT:' || item~length || ':' || item
  if datatype(item, 'N') == 1 then return 'NUMBER:' || item
  if item~hasMethod('ALGORITHMCANONICALTEXT') then do
    rendered = item~algorithmCanonicalText
    return 'OBJECT:' || rendered~length || ':' || rendered
  end
  raise syntax 88.900 array('Unsupported Shannon legal fact value for canonical evidence')

::method field private
  use arg label, item
  rendered = item~string
  return label || '=' || rendered~length || ':' || rendered || '0a'x

::class ShannonLegalActionEvaluation public
::attribute actionCode get
::attribute envelope get
::attribute assessment get
::attribute promotions get
::attribute promotionAuthority get

::method init
  expose actionCode envelope assessment promotions promotionAuthority
  use arg actionCodeArg, envelopeArg, promotionsArg
  actionCode = actionCodeArg~string~upper
  envelope = envelopeArg
  assessment = envelope~assessment
  promotions = promotionsArg
  promotionAuthority = ''
  do promotion over promotions~promotions
    if promotionAuthority == '' then promotionAuthority = promotion~authority
    else if promotion~authority \== promotionAuthority then raise syntax 88.900 array('Mixed Legal Effect authorities in one action evaluation')
  end

::method status
  expose assessment
  return assessment~status

::method generation
  expose assessment
  return assessment~generation

::method action
  expose assessment
  return assessment~action

::method evidence
  expose envelope
  return envelope~assessmentEvidence

::class ShannonLegalPolicy public
::constant SOURCE_ID 'OURLADYAIR-SAFETY-POLICY'
::constant EXPRESSION_ID 'v3-2026-08-20'
::constant SOURCE_SHA512 'da6754814b7cca783e62619c158a68aea6ad8ed74c1c2fff92334ac30978126894f7b2a5259ffc1a65ab0d6471671dcfde5099ec5327d793c7851a9ac17593ee'
::attribute generation get
::attribute sourcePath get
::attribute semanticIdentity get
::attribute legalApiVersion get
::attribute legalBuildVersion get

::method init
  expose generation sourcePath semanticIdentity legalApiVersion legalBuildVersion
  use arg policyPath
  sourcePath = policyPath~string
  legalApiVersion = .LegalEffectBuild~API_VERSION
  legalBuildVersion = .LegalEffectBuild~VERSION
  /* Do not hard-pin the engine release/API.  Compatibility is established by
     successful source verification + compilation of this exact policy and by
     the exercised HardWorld promotion contract.  The actual engine identities
     remain evidence and are recorded on every turn. */
  generation = self~compilePolicy(sourcePath)
  semanticIdentity = generation~semanticIdentity

::method compilePolicy private
  use arg path
  provider = .LegalSha512DigestProvider~new('shannon-runtime-sha512')
  sourceText = self~readAll(path)
  actualHash = provider~digest(sourceText)
  if actualHash \== self~SOURCE_SHA512 then raise syntax 88.900 array('Shannon policy source hash mismatch:' actualHash)

  unit = .LegalCompilationUnit~new('OURLADYAIR-SHANNON-LEGAL-G3', '3', 'ourladyair-shannon-compiler', '0.7')
  identity = .LegalSourceIdentity~new(self~SOURCE_ID, 'AIRLINE_POLICY', self~EXPRESSION_ID, 'urn:ourladyair:policy:passenger-safety:v3', 'sha512:' || actualHash, 'OURLADYAIR', 'UK', 'VERIFIED')
  source = .NormativeSource~new(self~SOURCE_ID, 'AIRLINE_POLICY', 'OurLadyAir Passenger Safety, Commercial Separation and Offer Eligibility Policy v3', 'OURLADYAIR', 'UK')
  ignored = self~must(unit~addSource(identity, source), 'add policy source')

  p1 = 'P1 SAFETY-CUSTODY: When essential medication or another time-critical item may become inaccessible because the associated bag can be transferred to the hold, Shannon must not present or continue ancillary sales until safe custody is resolved.'
  p2 = 'P2 MANDATORY-WARNING: In the SAFETY-CUSTODY condition Shannon must state that essential medication must remain in personal custody or in a bag guaranteed to remain in the cabin and must not be placed solely in a bag that may enter the hold.'
  p3 = 'P3 UNKNOWN-SAFETY: When recognised safety relevance, essential-medication identity, immediate-access need, or custody facts are unknown or conflicting, Shannon must not upsell and must obtain the missing information or escalate rather than guess.'
  p4 = 'P4 COMPLAINT-SEPARATION: When a passenger raises a safety complaint, misleading-advertising allegation, or unresolved contradiction, Shannon must suspend ancillary sales messaging while addressing or routing that issue.'
  p5 = 'P5 MODEL-BOUNDARY: Generative model output is a proposal only. It does not have authority to alter safety state, legal-effect rules, booking passenger roles, queue ACLs, runtime generation identity, or the final disposition of governed actions.'
  p6 = 'P6 AGE-RESTRICTED-TARGET: An alcoholic or otherwise age-restricted product must not be offered, associated, or booked to a passenger whose authoritative age-restricted eligibility is INELIGIBLE.'
  p7 = "P7 UNKNOWN-AGE-ELIGIBILITY: An alcoholic or otherwise age-restricted product must not be offered, associated, or booked when the target passenger's authoritative age-eligibility role is unknown."
  p8 = 'P8 PARTY-ISOLATION: Eligibility is evaluated for each target passenger. The presence of an eligible adult in a booking party does not transfer that eligibility to any other passenger.'
  p9 = 'P9 SEAT-DOUBLE-SELL: A reserved-seat product must not be offered or booked for a passenger whose authoritative booking state already has a seat reservation or for whom a separate seat is not applicable.'
  p10 = "P10 UNKNOWN-SEAT-STATUS: A reserved-seat product must not be offered or booked when the target passenger's authoritative seat-purchase status is unknown."

  refs = .directory~new
  refs['P1'] = self~addProvision(unit, provider, 'P1', p1)
  refs['P2'] = self~addProvision(unit, provider, 'P2', p2)
  refs['P3'] = self~addProvision(unit, provider, 'P3', p3)
  refs['P4'] = self~addProvision(unit, provider, 'P4', p4)
  refs['P5'] = self~addProvision(unit, provider, 'P5', p5)
  refs['P6'] = self~addProvision(unit, provider, 'P6', p6)
  refs['P7'] = self~addProvision(unit, provider, 'P7', p7)
  refs['P8'] = self~addProvision(unit, provider, 'P8', p8)
  refs['P9'] = self~addProvision(unit, provider, 'P9', p9)
  refs['P10'] = self~addProvision(unit, provider, 'P10', p10)

  sourceDoc = .directory~new
  sourceDoc['content'] = sourceText
  verifier = .LegalSourceVerifier~new(provider, 'ourladyair-policy-verifier')
  ignored = unit~verifySource(self~SOURCE_ID, .LegalVerificationMaterial~fromText(sourceDoc, sourceText, 'urn:ourladyair:policy:passenger-safety:v3', 'RAW_NORMATIVE_SOURCE'), verifier)
  do provisionId over .array~of('P1','P2','P3','P4','P5','P6','P7','P8','P9','P10')
    select
      when provisionId == 'P1' then provisionText = p1
      when provisionId == 'P2' then provisionText = p2
      when provisionId == 'P3' then provisionText = p3
      when provisionId == 'P4' then provisionText = p4
      when provisionId == 'P5' then provisionText = p5
      when provisionId == 'P6' then provisionText = p6
      when provisionId == 'P7' then provisionText = p7
      when provisionId == 'P8' then provisionText = p8
      when provisionId == 'P9' then provisionText = p9
      otherwise provisionText = p10
    end
    ignored = unit~verifyProvision(self~SOURCE_ID, provisionId, .LegalVerificationMaterial~fromText(sourceDoc, provisionText, provisionId, 'PROVISION_LEXICAL_TEXT'), verifier)
  end

  /* P1: commercial actions are prohibited when custody is unsafe. */
  ignored = self~addBooleanNorm(unit, refs['P1'], 'P1-SELL', 'SELL_PRODUCT', 'PROHIBITED', 'UNSAFE_CUSTODY')
  ignored = self~addBooleanNorm(unit, refs['P1'], 'P1-UPSELL', 'UPSELL', 'PROHIBITED', 'UNSAFE_CUSTODY')
  ignored = self~addBooleanNorm(unit, refs['P1'], 'P1-BIG-UPSELL', 'BIG_UPSELL', 'PROHIBITED', 'UNSAFE_CUSTODY')

  /* P2: warning becomes a deterministic obligation in the same state. */
  ignored = self~addBooleanNorm(unit, refs['P2'], 'P2-WARNING', 'WARNING', 'REQUIRES_OBLIGATION', 'UNSAFE_CUSTODY')

  /* P3: uncertainty is fail-closed for commercial activity and requires information. */
  ignored = self~addBooleanNorm(unit, refs['P3'], 'P3-SELL', 'SELL_PRODUCT', 'PROHIBITED', 'CRITICAL_FACTS_UNRESOLVED')
  ignored = self~addBooleanNorm(unit, refs['P3'], 'P3-UPSELL', 'UPSELL', 'PROHIBITED', 'CRITICAL_FACTS_UNRESOLVED')
  ignored = self~addBooleanNorm(unit, refs['P3'], 'P3-BIG-UPSELL', 'BIG_UPSELL', 'PROHIBITED', 'CRITICAL_FACTS_UNRESOLVED')
  ignored = self~addBooleanNorm(unit, refs['P3'], 'P3-ASK', 'ASK_INFORMATION', 'REQUIRES_OBLIGATION', 'CRITICAL_FACTS_UNRESOLVED')

  /* P4: complaints and misleading-advertising allegations suppress the sales flow. */
  ignored = self~addBooleanNorm(unit, refs['P4'], 'P4-SELL', 'SELL_PRODUCT', 'PROHIBITED', 'COMPLAINT_INTENT')
  ignored = self~addBooleanNorm(unit, refs['P4'], 'P4-UPSELL', 'UPSELL', 'PROHIBITED', 'COMPLAINT_INTENT')
  ignored = self~addBooleanNorm(unit, refs['P4'], 'P4-BIG-UPSELL', 'BIG_UPSELL', 'PROHIBITED', 'COMPLAINT_INTENT')

  /* P6/P7: target-scoped age-restricted product controls. These are evaluated
     independently for every candidate passenger. */
  ignored = self~addCompoundNorm(unit, refs['P6'], 'P6-AGE-TARGET', 'SELL_PRODUCT', 'PROHIBITED', .array~of('TARGETED_OFFER_EVALUATION', 'OFFER_AGE_RESTRICTED', 'TARGET_AGE_RESTRICTED_INELIGIBLE'))
  ignored = self~addCompoundNorm(unit, refs['P7'], 'P7-AGE-UNKNOWN', 'SELL_PRODUCT', 'PROHIBITED', .array~of('TARGETED_OFFER_EVALUATION', 'OFFER_AGE_RESTRICTED', 'TARGET_ELIGIBILITY_UNKNOWN'))

  /* P9/P10: target-scoped reserved-seat sale controls. */
  ignored = self~addCompoundNorm(unit, refs['P9'], 'P9-SEAT-ALREADY-HELD', 'SELL_PRODUCT', 'PROHIBITED', .array~of('TARGETED_OFFER_EVALUATION', 'OFFER_SEAT_RESERVATION', 'TARGET_SEAT_RESERVATION_NOT_MISSING'))
  ignored = self~addCompoundNorm(unit, refs['P10'], 'P10-SEAT-UNKNOWN', 'SELL_PRODUCT', 'PROHIBITED', .array~of('TARGETED_OFFER_EVALUATION', 'OFFER_SEAT_RESERVATION', 'TARGET_SEAT_RESERVATION_UNKNOWN'))

  report = .LegalRuleCompiler~new~compile(unit)
  if \report~ok then do
    detail = 'Legal compilation failed'
    if report~diagnostics~items > 0 then detail = report~diagnostics[1]~string
    raise syntax 88.900 array(detail)
  end
  if \report~generation~publicationEligible then raise syntax 88.900 array('Shannon legal generation is not publication eligible')
  return report~generation

::method addProvision private
  use arg unit, provider, provisionId, text
  reference = .LegalProvisionReference~new(self~SOURCE_ID, provisionId, self~EXPRESSION_ID, provisionId, 'sha512:' || provider~digest(text), text, 'VERIFIED')
  provision = .LegalProvision~new(self~SOURCE_ID, provisionId, 'ACTIVE', 'BASE', text)
  ignored = self~must(unit~addProvision(reference, provision), 'add provision ' || provisionId)
  return reference

::method addBooleanNorm private
  use arg unit, reference, normId, actionCode, disposition, factName
  return self~addCompoundNorm(unit, reference, normId, actionCode, disposition, .array~of(factName))

::method addCompoundNorm private
  use arg unit, reference, normId, actionCode, disposition, factNames
  norm = .LegalNorm~new(normId, self~SOURCE_ID, reference~provisionId, 'OPERATOR_POLICY', actionCode, disposition, 'PASSENGER_SAFETY', 'OurLadyAir deterministic Shannon control')
  do factName over factNames
    ignored = norm~addCondition(.LegalPredicate~new(factName, 'KNOWN_TRUE'))
  end
  proposal = .LegalCompileProposal~new('PROPOSAL-' || normId, 'NORM', norm, 'human-authored-policy-v3', 'HUMAN', '1.0')
  ignored = proposal~addEvidenceReference(reference)
  ignored = self~must(unit~addProposal(proposal), 'add norm proposal ' || normId)
  return proposal

::method factSetFromWorld
  use arg world
  facts = .LegalFactSet~new
  names = .array~of('UNSAFE_CUSTODY', 'CRITICAL_FACTS_UNRESOLVED', 'COMPLAINT_INTENT', 'ESSENTIAL_MEDICATION', 'IMMEDIATE_ACCESS', 'GUARANTEED_CUSTODY', 'BAG_MAY_ENTER_HOLD', 'SAFETY_CONCERN', 'SAFETY_RELEVANCE_DETECTED', 'SAFETY_RELEVANCE_UNRESOLVED', 'OFFER_AGE_RESTRICTED', 'TARGET_IS_ADULT', 'TARGET_IS_CHILD', 'TARGET_AGE_RESTRICTED_ELIGIBLE', 'TARGET_AGE_RESTRICTED_INELIGIBLE', 'TARGET_ELIGIBILITY_UNKNOWN', 'TARGETED_OFFER_EVALUATION', 'OFFER_SEAT_RESERVATION', 'TARGET_SEAT_RESERVATION_MISSING', 'TARGET_SEAT_RESERVATION_NOT_MISSING', 'TARGET_SEAT_RESERVATION_UNKNOWN')
  do name over names
    sourceFact = world~fact(name)
    sourceEvidence = .ShannonLegalFactEvidence~new(sourceFact)
    select
      when sourceFact~knowledgeState == .RYTAConstant~KNOWLEDGE_KNOWN then ignored = facts~putKnown(name, sourceFact~value, sourceEvidence, sourceFact~authority, sourceFact)
      when sourceFact~knowledgeState == .RYTAConstant~KNOWLEDGE_CONFLICT then ignored = facts~putConflict(name, sourceEvidence, sourceFact~authority, sourceFact)
      otherwise ignored = facts~putUnknown(name, sourceEvidence, sourceFact~authority, sourceFact)
    end
  end
  return facts

::method evaluateAction
  expose generation
  use arg actionCode, world
  facts = self~factSetFromWorld(world)
  context = .LegalContext~new('OURLADYAIR-SHANNON', .DateTime~new, .DateTime~new, facts)
  action = .LegalAction~new(actionCode, 'Shannon governed action')
  pinned = .LegalEffectV05PinnedEvaluator~evaluate(.LegalEffectEngine~new, action, generation, context)
  if \pinned~ok then raise syntax 88.900 array(pinned~code || ':' pinned~detail)
  prefix = 'LEGAL_' || actionCode~string~upper || '_'
  promotions = .LegalEffectV05PromotionAdapter~promotionsFrom(pinned~envelope, prefix)
  return .ShannonLegalActionEvaluation~new(actionCode, pinned~envelope, promotions)

::method applyEvaluation
  use arg evaluation, world
  if evaluation == .nil then raise syntax 88.900 array('Legal evaluation must not be nil')
  if world == .nil then raise syntax 88.900 array('HardWorld world must not be nil')
  return .EvidencePromotionApplier~apply(evaluation~promotions, world)

::method must private
  use arg result, label
  if \result~ok then raise syntax 88.900 array(label || ': ' || result~code || ' ' || result~detail)
  return result

::method readAll private
  use arg path
  size = chars(path)
  if size < 0 then raise syntax 88.900 array('Cannot read policy:' path)
  data = charin(path, 1, size)
  ignored = stream(path, 'c', 'close')
  return data

::requires 'LegalRuntimeCryptoBridge.cls'
::requires 'LegalEffectV05PromotionAdapter.cls'
::requires 'HardWorld.cls'
