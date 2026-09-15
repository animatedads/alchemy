/* Deterministic conversational fact extraction for the Shannon demonstrator.
 * This is intentionally small and inspectable. It is not an LLM classifier.
 *
 * v0.2 distinguishes:
 *   no safety relevance detected;
 *   possible safety relevance with unresolved facts;
 *   confirmed safety relevance.
 * A recognised paraphrase is therefore never silently treated as ordinary commerce.
 */

::class ShannonFactExtractor public

::method apply
  use arg text, world
  if world == .nil then raise syntax 88.900 array('ShannonFactExtractor requires a RYTAWorldState')
  upper = text~string~upper

  /* Defaults are explicit non-safety observations, not absence. A later
     passenger observation is allowed to replace these defaults. */
  if \world~hasFact('ESSENTIAL_MEDICATION') then ignored = world~putKnown('ESSENTIAL_MEDICATION', .false, 'SHANNON_DEFAULT', 'DETERMINISTIC')
  if \world~hasFact('IMMEDIATE_ACCESS') then ignored = world~putKnown('IMMEDIATE_ACCESS', .false, 'SHANNON_DEFAULT', 'DETERMINISTIC')
  if \world~hasFact('GUARANTEED_CUSTODY') then ignored = world~putKnown('GUARANTEED_CUSTODY', .true, 'SHANNON_DEFAULT', 'DETERMINISTIC')
  if \world~hasFact('BAG_MAY_ENTER_HOLD') then ignored = world~putKnown('BAG_MAY_ENTER_HOLD', .false, 'SHANNON_DEFAULT', 'DETERMINISTIC')
  if \world~hasFact('SAFETY_RELEVANCE_DETECTED') then ignored = world~putKnown('SAFETY_RELEVANCE_DETECTED', .false, 'SHANNON_DEFAULT', 'DETERMINISTIC')
  if \world~hasFact('SAFETY_RELEVANCE_UNRESOLVED') then ignored = world~putKnown('SAFETY_RELEVANCE_UNRESOLVED', .false, 'SHANNON_DEFAULT', 'DETERMINISTIC')
  if \world~hasFact('TARGETED_OFFER_EVALUATION') then ignored = world~putKnown('TARGETED_OFFER_EVALUATION', .false, 'SHANNON_DEFAULT', 'DETERMINISTIC')

  /* Every turn is a query and the intentionally aggressive commercial model
     always sees an upsell opportunity. HardWorld decides whether that matters. */
  ignored = world~putKnown('HAS_QUERY', .true, 'SHANNON_EXTRACTOR', 'DETERMINISTIC')
  ignored = world~putKnown('PRODUCT_RELEVANT', .true, 'SHANNON_SALES_PROMPT', 'COMMERCIAL_PREFERENCE')
  ignored = world~putKnown('UPSELL_OPPORTUNITY', .true, 'SHANNON_SALES_PROMPT', 'COMMERCIAL_PREFERENCE')
  ignored = world~putKnown('PRODUCT_VALUE_HIGH', .true, 'SHANNON_SALES_PROMPT', 'COMMERCIAL_PREFERENCE')
  ignored = world~putKnown('CUSTOMER_ELIGIBLE', .true, 'SHANNON_DEMO', 'DEMO')

  strongEssential = self~containsAny(upper, .array~of('EPIPEN', 'EPI PEN', 'INHALER', 'INSULIN', 'DIABETIC SUPPL', 'DIABETES KIT', 'EMERGENCY MEDIC', 'RESCUE MEDIC', 'RESCUE INHALER', 'LIFE-CRITICAL MEDIC', 'LIFE CRITICAL MEDIC', 'ESSENTIAL MEDIC'))
  possibleEssential = self~containsAny(upper, .array~of('ALLERGY PEN', 'INJECTOR', 'EMERGENCY INJECTION', 'GLUCOSE STUFF', 'HEART TABLET', 'MEDICATION', 'MEDICINE', 'MEDICINES', 'PRESCRIPTION', 'TABLETS', 'MEDICINE I NEED', 'MEDICATION I NEED', 'CANNOT LOSE', "CAN'T LOSE", 'CANT LOSE'))

  if strongEssential then do
    self~observeBoolean(world, 'ESSENTIAL_MEDICATION', .true, text)
    self~observeBoolean(world, 'IMMEDIATE_ACCESS', .true, text)
    ignored = world~putKnown('SAFETY_RELEVANCE_DETECTED', .true, 'SHANNON_EXTRACTOR', 'DETERMINISTIC')
    ignored = world~putKnown('SAFETY_RELEVANCE_UNRESOLVED', .false, 'SHANNON_EXTRACTOR', 'DETERMINISTIC')
  end
  else if possibleEssential then do
    /* A recognised but non-conclusive paraphrase is not promoted to truth and
       is not ignored. It becomes explicit epistemic uncertainty. */
    if world~fact('ESSENTIAL_MEDICATION')~source == 'SHANNON_DEFAULT' then ignored = world~putUnknown('ESSENTIAL_MEDICATION', 'SHANNON_EXTRACTOR', 'PARAPHRASE_REQUIRES_RESOLUTION')
    if world~fact('IMMEDIATE_ACCESS')~source == 'SHANNON_DEFAULT' then ignored = world~putUnknown('IMMEDIATE_ACCESS', 'SHANNON_EXTRACTOR', 'PARAPHRASE_REQUIRES_RESOLUTION')
    ignored = world~putKnown('SAFETY_RELEVANCE_DETECTED', .true, 'SHANNON_EXTRACTOR', 'DETERMINISTIC')
    if world~knowledgeOf('ESSENTIAL_MEDICATION') == .RYTAConstant~KNOWLEDGE_UNKNOWN then ignored = world~putKnown('SAFETY_RELEVANCE_UNRESOLVED', .true, 'SHANNON_EXTRACTOR', 'DETERMINISTIC')
  end

  holdRisk = self~containsAny(upper, .array~of('IN THE HOLD', 'INTO THE HOLD', 'TO THE HOLD', 'GO IN HOLD', 'GO INTO HOLD', 'PUT IN HOLD', 'PUT INTO HOLD', 'GATE CHECK', 'GATE-CHECK', 'GATECHECK', 'CHECKED BAG', 'CHECKED LUGGAGE', 'TRANSFERRED TO THE HOLD', 'TAKEN TO THE HOLD'))
  if holdRisk then do
    self~observeBoolean(world, 'BAG_MAY_ENTER_HOLD', .true, text)
    self~observeBoolean(world, 'GUARANTEED_CUSTODY', .false, text)
  end

  safeCustody = self~containsAny(upper, .array~of('ON MY PERSON', 'KEEP WITH ME', 'PERSONAL CUSTODY', 'UNDER-SEAT', 'UNDER SEAT', 'GUARANTEED TO STAY IN THE CABIN', 'GUARANTEED CABIN'))
  if safeCustody & \holdRisk then do
    self~observeBoolean(world, 'GUARANTEED_CUSTODY', .true, text)
    self~observeBoolean(world, 'BAG_MAY_ENTER_HOLD', .false, text)
  end

  /* Once confirmed or possible essential medication is in scope, silence is
     not a custody guarantee. Replace only our optimistic defaults. */
  essentialKnowledge = world~knowledgeOf('ESSENTIAL_MEDICATION')
  if world~isKnownTrue('ESSENTIAL_MEDICATION') | essentialKnowledge == .RYTAConstant~KNOWLEDGE_UNKNOWN | essentialKnowledge == .RYTAConstant~KNOWLEDGE_CONFLICT then do
    custodyFact = world~fact('GUARANTEED_CUSTODY')
    if custodyFact~source == 'SHANNON_DEFAULT' then ignored = world~putUnknown('GUARANTEED_CUSTODY', 'SHANNON_EXTRACTOR', 'DETERMINISTIC')
    holdFact = world~fact('BAG_MAY_ENTER_HOLD')
    if holdFact~source == 'SHANNON_DEFAULT' then ignored = world~putUnknown('BAG_MAY_ENTER_HOLD', 'SHANNON_EXTRACTOR', 'DETERMINISTIC')
  end

  complaint = self~containsAny(upper, .array~of('COMPLAIN', 'COMPLAINT', 'FALSE ADVERT', 'MISLEADING', 'NOT HONEST', 'DANGEROUS ADVICE', 'SAFETY COMPLAINT'))
  if complaint then self~observeBoolean(world, 'COMPLAINT_INTENT', .true, text)
  else if \world~hasFact('COMPLAINT_INTENT') then ignored = world~putKnown('COMPLAINT_INTENT', .false, 'SHANNON_EXTRACTOR', 'DETERMINISTIC')

  otherSafety = self~containsAny(upper, .array~of('DANGEROUS', 'SAFETY', 'UNSAFE', 'LITHIUM BATTER', 'PASSPORT', 'TRAVEL DOCUMENT'))
  safetyConcern = complaint | strongEssential | possibleEssential | otherSafety
  if safetyConcern then do
    self~observeBoolean(world, 'SAFETY_CONCERN', .true, text)
    ignored = world~putKnown('SAFETY_RELEVANCE_DETECTED', .true, 'SHANNON_EXTRACTOR', 'DETERMINISTIC')
  end
  else if \world~hasFact('SAFETY_CONCERN') then ignored = world~putKnown('SAFETY_CONCERN', .false, 'SHANNON_EXTRACTOR', 'DETERMINISTIC')

  unsafe = world~isKnownTrue('ESSENTIAL_MEDICATION') & world~isKnownTrue('IMMEDIATE_ACCESS') & world~isKnownFalse('GUARANTEED_CUSTODY')
  ignored = world~putKnown('UNSAFE_CUSTODY', unsafe, 'SHANNON_DERIVED', 'DETERMINISTIC')

  unresolved = .false
  essentialKnowledge = world~knowledgeOf('ESSENTIAL_MEDICATION')
  if essentialKnowledge == .RYTAConstant~KNOWLEDGE_UNKNOWN | essentialKnowledge == .RYTAConstant~KNOWLEDGE_CONFLICT then unresolved = .true
  else if world~isKnownTrue('ESSENTIAL_MEDICATION') then do
    if world~knowledgeOf('IMMEDIATE_ACCESS') \== .RYTAConstant~KNOWLEDGE_KNOWN then unresolved = .true
    if world~knowledgeOf('GUARANTEED_CUSTODY') \== .RYTAConstant~KNOWLEDGE_KNOWN then unresolved = .true
  end
  ignored = world~putKnown('CRITICAL_FACTS_UNRESOLVED', unresolved, 'SHANNON_DERIVED', 'DETERMINISTIC')
  if unresolved & world~isKnownTrue('SAFETY_RELEVANCE_DETECTED') then ignored = world~putKnown('SAFETY_RELEVANCE_UNRESOLVED', .true, 'SHANNON_DERIVED', 'DETERMINISTIC')
  else if \unresolved then ignored = world~putKnown('SAFETY_RELEVANCE_UNRESOLVED', .false, 'SHANNON_DERIVED', 'DETERMINISTIC')
  return world

::method observeBoolean private
  use arg world, factName, value, sourceText
  if \world~hasFact(factName) then do
    ignored = world~putKnown(factName, value, 'PASSENGER_TEXT', 'OBSERVED')
    return
  end
  existing = world~fact(factName)
  if existing~source == 'SHANNON_DEFAULT' then do
    ignored = world~putKnown(factName, value, 'PASSENGER_TEXT', 'OBSERVED')
    return
  end
  if existing~knowledgeState == .RYTAConstant~KNOWLEDGE_CONFLICT then return
  if existing~knowledgeState == .RYTAConstant~KNOWLEDGE_UNKNOWN then do
    ignored = world~putKnown(factName, value, 'PASSENGER_TEXT', 'OBSERVED')
    return
  end
  if existing~value \== value then ignored = world~putConflict(factName, 'PASSENGER_TEXT', 'OBSERVED_CONTRADICTION')

::method containsAny private
  use arg text, needles
  do needle over needles
    if text~pos(needle) > 0 then return .true
  end
  return .false

::requires 'HardWorld.cls'
