/*
 * LegalEffectPromotionAdapter.cls
 *
 * Duck-typed bridge from Legal Effect v0.1 assessments to the domain-neutral
 * EvidencePromotion contract.  Legal Effect remains the owner of legal
 * applicability and normative semantics; HardWorld sees only explicit,
 * auditable fact promotions.
 */

::class LegalEffectGenerationSnapshot public
::attribute nativeObject get
::attribute canonicalIdentity get

::method init
  expose nativeObject canonicalTextValue canonicalIdentity
  use arg generation
  if generation == .nil then raise syntax 93.900 additional('Legal generation must not be .nil')
  if \generation~hasMethod('SEALED') then raise syntax 93.900 additional('Legal generation has no SEALED method')
  if \generation~sealed then raise syntax 93.900 additional('Legal generation must be sealed before promotion')
  nativeObject = generation
  canonicalTextValue = self~buildGenerationText(generation)
  canonicalIdentity = .AlgorithmDigest~sha256Text(canonicalTextValue)

::method algorithmCanonicalText
  expose canonicalTextValue
  return canonicalTextValue

::method buildGenerationText private
  use arg generation
  text = 'LEGAL_EFFECT_GENERATION_SNAPSHOT_V1' || '0a'x
  text = text || self~field('GENERATION_ID', generation~generationId)
  text = text || self~field('VERSION', generation~version)
  text = text || self~field('SEALED', generation~sealed)

  sourceTexts = .array~new
  sourceTable = generation~sources
  sourceIds = sourceTable~allIndexes
  sourceIds~sort
  do sourceId over sourceIds
    sourceTexts~append(self~canonicalSource(sourceTable[sourceId]))
  end
  text = text || 'SOURCE_COUNT=' || sourceTexts~items || '0a'x
  do sourceText over sourceTexts
    text = text || sourceText~length || ':' || sourceText || '0a'x
  end

  normTexts = .array~new
  do norm over generation~norms
    normTexts~append(self~canonicalNorm(norm))
  end
  /* Preserve generation norm order conservatively: the v0.1 engine observes
     these objects before reducing matches through a Table. */
  text = text || 'NORM_COUNT=' || normTexts~items || '0a'x
  do normText over normTexts
    text = text || normText~length || ':' || normText || '0a'x
  end
  return text

::method canonicalSource private
  use arg sourceObject
  text = 'LEGAL_SOURCE_V1' || '0a'x
  text = text || self~field('SOURCE_ID', sourceObject~sourceId)
  text = text || self~field('KIND', sourceObject~sourceKind)
  text = text || self~field('TITLE', sourceObject~title)
  text = text || self~field('AUTHORITY', sourceObject~authority)
  text = text || self~field('JURISDICTION', sourceObject~jurisdictionId)
  text = text || self~field('GOVERNING_LAW', sourceObject~governingLaw)
  text = text || self~field('APPLICABILITY_MODE', sourceObject~applicabilityMode)
  text = text || self~field('SEALED', sourceObject~sealed)

  evidenceTexts = .array~new
  do anchor over sourceObject~evidenceCopy
    evidenceTexts~append(self~canonicalAnchor(anchor))
  end
  evidenceTexts~sort
  text = text || 'EVIDENCE_COUNT=' || evidenceTexts~items || '0a'x
  do anchorText over evidenceTexts
    text = text || anchorText~length || ':' || anchorText || '0a'x
  end
  return text

::method canonicalNorm private
  use arg norm
  text = 'LEGAL_NORM_V1' || '0a'x
  text = text || self~field('NORM_ID', norm~normId)
  text = text || self~field('SOURCE_ID', norm~sourceId)
  text = text || self~field('PROVISION_ID', norm~provisionId)
  text = text || self~field('NORM_TYPE', norm~normType)
  text = text || self~field('ACTION_CODE', norm~actionCode)
  text = text || self~field('DISPOSITION', norm~disposition)
  text = text || self~field('SUBJECT_MATTER', norm~subjectMatter)
  text = text || self~field('RATIONALE', norm~rationale)
  text = text || self~canonicalTemporal(norm~temporalScope)

  ordinal = 0
  text = text || 'CONDITION_COUNT=' || norm~conditions~items || '0a'x
  do predicate over norm~conditions
    ordinal = ordinal + 1
    predicateText = self~canonicalPredicate(predicate)
    text = text || 'CONDITION[' || ordinal || ']=' || predicateText~length || ':' || predicateText || '0a'x
  end

  ordinal = 0
  text = text || 'EXCEPTION_COUNT=' || norm~exceptions~items || '0a'x
  do predicate over norm~exceptions
    ordinal = ordinal + 1
    predicateText = self~canonicalPredicate(predicate)
    text = text || 'EXCEPTION[' || ordinal || ']=' || predicateText~length || ':' || predicateText || '0a'x
  end

  claimTexts = .array~new
  do claim over norm~jurisdictionClaims
    claimTexts~append(self~canonicalClaim(claim))
  end
  /* Preserve claim order: LegalNorm~evaluate returns on the first unmet claim. */
  text = text || 'JURISDICTION_COUNT=' || claimTexts~items || '0a'x
  do claimText over claimTexts
    text = text || claimText~length || ':' || claimText || '0a'x
  end

  evidenceTexts = .array~new
  do anchor over norm~evidence
    evidenceTexts~append(self~canonicalAnchor(anchor))
  end
  evidenceTexts~sort
  text = text || 'EVIDENCE_COUNT=' || evidenceTexts~items || '0a'x
  do anchorText over evidenceTexts
    text = text || anchorText~length || ':' || anchorText || '0a'x
  end
  return text

::method canonicalTemporal private
  use arg temporal
  text = 'TEMPORAL|' || self~inlineField('ENTRY', temporal~entryIntoForce)
  text = text || self~inlineField('EFFICACY_FROM', temporal~efficacyFrom)
  text = text || self~inlineField('EFFICACY_TO', temporal~efficacyTo)
  text = text || self~inlineField('APPLICABILITY_FROM', temporal~applicabilityFrom)
  text = text || self~inlineField('APPLICABILITY_TO', temporal~applicabilityTo)
  return text || '0a'x

::method canonicalPredicate private
  use arg predicate
  text = 'PREDICATE|' || self~inlineField('FACT', predicate~factName)
  text = text || self~inlineField('OP', predicate~operator)
  text = text || self~inlineField('EXPECTED', self~canonicalValue(predicate~expectedValue))
  return text

::method canonicalClaim private
  use arg claim
  text = 'CLAIM|' || self~inlineField('AUTHORITY', claim~authorityId)
  text = text || self~inlineField('TERRITORY', claim~territoryId)
  text = text || self~inlineField('SUBJECT', claim~subjectMatter)
  text = text || self~inlineField('BASIS', claim~basis)
  return text

::method canonicalAnchor private
  use arg anchor
  text = 'ANCHOR|' || self~inlineField('SOURCE_ID', anchor~sourceId)
  text = text || self~inlineField('SOURCE_KIND', anchor~sourceKind)
  text = text || self~inlineField('CITATION', anchor~citation)
  text = text || self~inlineField('AUTHORITY', anchor~authority)
  sourceObject = anchor~sourceObject
  if sourceObject == .nil then text = text || 'OBJECT=NULL|'
  else do
    if sourceObject~hasMethod('ALGORITHMCANONICALTEXT') then objectText = sourceObject~algorithmCanonicalText
    else if sourceObject~hasMethod('EVIDENCEIDENTITY') then objectText = 'EVIDENCE_ID:' || sourceObject~evidenceIdentity
    else raise syntax 93.900 additional('Legal evidence source object lacks explicit canonical contract:' anchor~sourceId)
    text = text || self~inlineField('OBJECT', objectText)
  end
  metadataText = self~canonicalMap(anchor~metadata, 'ANCHOR_METADATA')
  text = text || self~inlineField('METADATA', metadataText)
  return text

::method canonicalMap private
  use arg mapObject, kind
  if mapObject == .nil then return kind || ':NULL'
  keys = mapObject~allIndexes
  keys~sort
  text = kind || '|COUNT=' || keys~items || '|'
  do key over keys
    renderedKey = key~string
    valueText = self~canonicalValue(mapObject[key])
    text = text || renderedKey~length || ':' || renderedKey || '=' || valueText~length || ':' || valueText || '|'
  end
  return text

::method canonicalValue private
  use arg value
  if value == .nil then return 'NULL'
  if value == .true then return 'BOOLEAN:TRUE'
  if value == .false then return 'BOOLEAN:FALSE'
  if value~class == .String then return 'TEXT:' || value~length || ':' || value
  if datatype(value, 'N') == 1 then return 'NUMBER:' || value
  if value~hasMethod('ALGORITHMCANONICALTEXT') then do
    objectText = value~algorithmCanonicalText
    return 'OBJECT:' || objectText~length || ':' || objectText
  end
  raise syntax 93.900 additional('Legal generation value lacks explicit canonical contract')

::method field private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x

::method inlineField private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '|'


::class LegalEffectEvaluationInputSnapshot public
::attribute generationSnapshot get
::attribute actionObject get
::attribute contextObject get
::attribute actionIdentity get
::attribute contextIdentity get
::attribute canonicalIdentity get

::method init
  expose generationSnapshot actionObject contextObject actionTextValue contextTextValue actionIdentity contextIdentity canonicalTextValue canonicalIdentity
  use arg generationSnapshotArg, actionArg, contextArg
  if generationSnapshotArg == .nil then raise syntax 93.900 additional('Legal generation snapshot must not be .nil')
  if actionArg == .nil then raise syntax 93.900 additional('Legal action must not be .nil')
  if contextArg == .nil then raise syntax 93.900 additional('Legal context must not be .nil')
  generationSnapshot = generationSnapshotArg
  actionObject = actionArg
  contextObject = contextArg
  actionTextValue = self~canonicalAction(actionArg)
  contextTextValue = self~canonicalContext(contextArg)
  actionIdentity = .AlgorithmDigest~sha256Text(actionTextValue)
  contextIdentity = .AlgorithmDigest~sha256Text(contextTextValue)
  canonicalTextValue = 'LEGAL_EFFECT_EVALUATION_INPUT_V1' || '0a'x
  canonicalTextValue = canonicalTextValue || self~field('GENERATION_HASH', generationSnapshot~canonicalIdentity)
  canonicalTextValue = canonicalTextValue || self~field('ACTION_HASH', actionIdentity)
  canonicalTextValue = canonicalTextValue || self~field('CONTEXT_HASH', contextIdentity)
  canonicalIdentity = .AlgorithmDigest~sha256Text(canonicalTextValue)

::method algorithmCanonicalText
  expose canonicalTextValue
  return canonicalTextValue

::method canonicalAction private
  use arg action
  text = 'LEGAL_ACTION_INPUT_V1' || '0a'x
  text = text || self~field('ACTION_CODE', action~actionCode)
  text = text || self~field('DESCRIPTION', action~description)
  text = text || 'MUTATION_COUNT=' || action~mutations~items || '0a'x
  ordinal = 0
  do mutation over action~mutations
    ordinal = ordinal + 1
    item = 'MUTATION|' || self~inlineField('FACT', mutation~factName)
    item = item || self~inlineField('STATE', mutation~state)
    item = item || self~inlineField('VALUE', self~canonicalValue(mutation~value))
    item = item || self~inlineField('AUTHORITY', mutation~authority)
    item = item || self~inlineField('SOURCE', self~canonicalSourceEvidence(mutation~source, 'action mutation ' || mutation~factName))
    text = text || 'MUTATION[' || ordinal || ']=' || item~length || ':' || item || '0a'x
  end
  return text

::method canonicalContext private
  use arg context
  text = 'LEGAL_CONTEXT_INPUT_V1' || '0a'x
  text = text || self~field('EVENT_ID', context~eventId)
  text = text || self~field('EVENT_TIME', context~eventTime)
  text = text || self~field('EVALUATION_TIME', context~evaluationTime)

  claimTexts = .array~new
  do claim over context~jurisdictionClaims
    item = 'CLAIM|' || self~inlineField('AUTHORITY', claim~authorityId)
    item = item || self~inlineField('TERRITORY', claim~territoryId)
    item = item || self~inlineField('SUBJECT', claim~subjectMatter)
    item = item || self~inlineField('BASIS', claim~basis)
    claimTexts~append(item)
  end
  claimTexts~sort
  text = text || 'CLAIM_COUNT=' || claimTexts~items || '0a'x
  do item over claimTexts
    text = text || item~length || ':' || item || '0a'x
  end

  bindingKeys = context~sourceBindings~allIndexes
  bindingKeys~sort
  text = text || 'BINDING_COUNT=' || bindingKeys~items || '0a'x
  do sourceId over bindingKeys
    item = sourceId~string || '|' || context~sourceBindings[sourceId]~string
    text = text || item~length || ':' || item || '0a'x
  end

  metadataText = self~canonicalMap(context~metadata, 'CONTEXT_METADATA')
  text = text || 'METADATA=' || metadataText~length || ':' || metadataText || '0a'x

  factNames = context~facts~facts~allIndexes
  factNames~sort
  text = text || 'FACT_COUNT=' || factNames~items || '0a'x
  do factName over factNames
    factObject = context~facts~facts[factName]
    item = 'FACT|' || self~inlineField('NAME', factObject~name)
    item = item || self~inlineField('STATE', factObject~state)
    item = item || self~inlineField('VALUE', self~canonicalValue(factObject~value))
    item = item || self~inlineField('AUTHORITY', factObject~authority)
    item = item || self~inlineField('SOURCE', self~canonicalSourceEvidence(factObject~source, 'context fact ' || factObject~name))
    text = text || item~length || ':' || item || '0a'x
  end
  return text

::method canonicalSourceEvidence private
  use arg sourceObject, label
  if sourceObject == .nil then return 'NULL'
  if sourceObject == .true then return 'BOOLEAN:TRUE'
  if sourceObject == .false then return 'BOOLEAN:FALSE'
  if sourceObject~class == .String then return 'TEXT:' || sourceObject~length || ':' || sourceObject
  if datatype(sourceObject, 'N') == 1 then return 'NUMBER:' || sourceObject
  if sourceObject~hasMethod('ALGORITHMCANONICALTEXT') then do
    sourceText = sourceObject~algorithmCanonicalText
    return 'OBJECT:' || sourceText~length || ':' || sourceText
  end
  if sourceObject~hasMethod('EVIDENCEIDENTITY') then do
    sourceText = sourceObject~evidenceIdentity
    return 'EVIDENCE_ID:' || sourceText~length || ':' || sourceText
  end
  raise syntax 93.900 additional('Legal authoritative input source lacks explicit canonical contract:' label)

::method canonicalMap private
  use arg mapObject, kind
  if mapObject == .nil then return kind || ':NULL'
  keys = mapObject~allIndexes
  keys~sort
  text = kind || '|COUNT=' || keys~items || '|'
  do key over keys
    renderedKey = key~string
    valueText = self~canonicalValue(mapObject[key])
    text = text || renderedKey~length || ':' || renderedKey || '=' || valueText~length || ':' || valueText || '|'
  end
  return text

::method canonicalValue private
  use arg value
  if value == .nil then return 'NULL'
  if value == .true then return 'BOOLEAN:TRUE'
  if value == .false then return 'BOOLEAN:FALSE'
  if value~class == .String then return 'TEXT:' || value~length || ':' || value
  if datatype(value, 'N') == 1 then return 'NUMBER:' || value
  if value~hasMethod('ALGORITHMCANONICALTEXT') then do
    objectText = value~algorithmCanonicalText
    return 'OBJECT:' || objectText~length || ':' || objectText
  end
  raise syntax 93.900 additional('Legal authoritative input value lacks explicit canonical contract')

::method field private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x

::method inlineField private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '|'


::class LegalEffectAssessmentEvidence public
::attribute nativeObject get
::attribute generationSnapshot get
::attribute inputSnapshot get
::attribute canonicalIdentity get

::method init
  expose nativeObject generationSnapshot inputSnapshot canonicalTextValue canonicalIdentity
  use arg assessment, pinnedGenerationSnapshot = .nil, pinnedInputSnapshot = .nil
  if assessment == .nil then raise syntax 93.900 additional('Legal assessment must not be .nil')
  nativeObject = assessment
  if pinnedGenerationSnapshot == .nil then generationSnapshot = .LegalEffectGenerationSnapshot~new(assessment~generation)
  else generationSnapshot = pinnedGenerationSnapshot
  inputSnapshot = pinnedInputSnapshot
  canonicalTextValue = self~buildAssessmentText(assessment)
  canonicalIdentity = .AlgorithmDigest~sha256Text(canonicalTextValue)

::method algorithmCanonicalText
  expose canonicalTextValue
  return canonicalTextValue

::method buildAssessmentText private
  expose generationSnapshot inputSnapshot
  use arg assessment
  text = 'LEGAL_EFFECT_ASSESSMENT_EVIDENCE_V1' || '0a'x
  text = text || self~field('GENERATION_HASH', generationSnapshot~canonicalIdentity)
  if inputSnapshot == .nil then text = text || self~field('INPUT_HASH', 'UNPINNED')
  else text = text || self~field('INPUT_HASH', inputSnapshot~canonicalIdentity)
  text = text || self~field('ACTION', assessment~action~actionCode)
  text = text || self~field('ACTION_DESCRIPTION', assessment~action~description)
  text = text || self~field('STATUS', assessment~status)
  text = text || self~canonicalAction(assessment~action)
  text = text || self~canonicalContext('CURRENT', assessment~currentContext)
  text = text || self~canonicalContext('PROSPECTIVE', assessment~prospectiveContext)
  text = text || self~canonicalMatches('BEFORE', assessment~beforeMatches)
  text = text || self~canonicalMatches('AFTER', assessment~afterMatches)
  text = text || self~canonicalMatches('NEW', assessment~newlyApplicable)
  text = text || self~canonicalMatches('CEASED', assessment~ceasedApplicable)
  text = text || self~canonicalMatches('UNRESOLVED', assessment~unresolved)

  dispositions = .array~new
  do disposition over assessment~dispositions
    dispositions~append(disposition~string~upper)
  end
  dispositions~sort
  text = text || 'DISPOSITION_COUNT=' || dispositions~items || '0a'x
  do disposition over dispositions
    text = text || self~field('DISPOSITION', disposition)
  end
  return text

::method canonicalAction private
  use arg action
  text = 'ACTION_MUTATION_COUNT=' || action~mutations~items || '0a'x
  ordinal = 0
  do mutation over action~mutations
    ordinal = ordinal + 1
    item = 'MUTATION|' || self~inlineField('FACT', mutation~factName)
    item = item || self~inlineField('STATE', mutation~state)
    item = item || self~inlineField('VALUE', self~canonicalValue(mutation~value))
    item = item || self~inlineField('AUTHORITY', mutation~authority)
    item = item || self~inlineField('SOURCE_EVIDENCE', self~canonicalSourceEvidence(mutation~source, 'assessment action mutation ' || mutation~factName))
    text = text || 'MUTATION[' || ordinal || ']=' || item~length || ':' || item || '0a'x
  end
  return text

::method canonicalContext private
  use arg label, context
  text = label || '_CONTEXT|' || self~inlineField('EVENT_ID', context~eventId)
  text = text || self~inlineField('EVENT_TIME', context~eventTime)
  text = text || self~inlineField('EVALUATION_TIME', context~evaluationTime) || '0a'x

  claimTexts = .array~new
  do claim over context~jurisdictionClaims
    claimText = 'CLAIM|' || self~inlineField('AUTHORITY', claim~authorityId)
    claimText = claimText || self~inlineField('TERRITORY', claim~territoryId)
    claimText = claimText || self~inlineField('SUBJECT', claim~subjectMatter)
    claimText = claimText || self~inlineField('BASIS', claim~basis)
    claimTexts~append(claimText)
  end
  claimTexts~sort
  text = text || label || '_CLAIM_COUNT=' || claimTexts~items || '0a'x
  do claimText over claimTexts
    text = text || claimText~length || ':' || claimText || '0a'x
  end

  bindingKeys = context~sourceBindings~allIndexes
  bindingKeys~sort
  text = text || label || '_BINDING_COUNT=' || bindingKeys~items || '0a'x
  do sourceId over bindingKeys
    bindingText = sourceId~string || '|' || context~sourceBindings[sourceId]~string
    text = text || bindingText~length || ':' || bindingText || '0a'x
  end

  metadataText = self~canonicalMap(context~metadata, label || '_CONTEXT_METADATA')
  text = text || label || '_METADATA=' || metadataText~length || ':' || metadataText || '0a'x

  factNames = context~facts~facts~allIndexes
  factNames~sort
  text = text || label || '_FACT_COUNT=' || factNames~items || '0a'x
  do factName over factNames
    factObject = context~facts~facts[factName]
    factText = 'FACT|' || self~inlineField('NAME', factObject~name)
    factText = factText || self~inlineField('STATE', factObject~state)
    factText = factText || self~inlineField('VALUE', self~canonicalValue(factObject~value))
    factText = factText || self~inlineField('AUTHORITY', factObject~authority)
    factSource = factObject~source
    factSourceText = self~canonicalSourceEvidence(factSource, 'assessment context fact ' || factObject~name)
    factText = factText || self~inlineField('SOURCE_EVIDENCE', factSourceText)
    text = text || factText~length || ':' || factText || '0a'x
  end
  return text

::method canonicalSourceEvidence private
  use arg sourceObject, label
  if sourceObject == .nil then return 'NULL'
  if sourceObject == .true then return 'BOOLEAN:TRUE'
  if sourceObject == .false then return 'BOOLEAN:FALSE'
  if sourceObject~class == .String then return 'TEXT:' || sourceObject~length || ':' || sourceObject
  if datatype(sourceObject, 'N') == 1 then return 'NUMBER:' || sourceObject
  if sourceObject~hasMethod('ALGORITHMCANONICALTEXT') then do
    sourceText = sourceObject~algorithmCanonicalText
    return 'OBJECT:' || sourceText~length || ':' || sourceText
  end
  if sourceObject~hasMethod('EVIDENCEIDENTITY') then do
    sourceText = sourceObject~evidenceIdentity
    return 'EVIDENCE_ID:' || sourceText~length || ':' || sourceText
  end
  raise syntax 93.900 additional('Legal assessment source lacks explicit canonical contract:' label)

::method canonicalMatches private
  use arg label, matches
  items = .array~new
  do matchObject over matches
    item = 'MATCH|' || self~inlineField('NORM_ID', matchObject~norm~normId)
    item = item || self~inlineField('STATUS', matchObject~status)
    ordinal = 0
    do reason over matchObject~reasons
      ordinal = ordinal + 1
      item = item || 'REASON[' || ordinal || ']=' || reason~length || ':' || reason || '|'
    end
    items~append(item)
  end
  items~sort
  text = label || '_MATCH_COUNT=' || items~items || '0a'x
  do item over items
    text = text || item~length || ':' || item || '0a'x
  end
  return text

::method canonicalMap private
  use arg mapObject, kind
  if mapObject == .nil then return kind || ':NULL'
  keys = mapObject~allIndexes
  keys~sort
  text = kind || '|COUNT=' || keys~items || '|'
  do key over keys
    renderedKey = key~string
    valueText = self~canonicalValue(mapObject[key])
    text = text || renderedKey~length || ':' || renderedKey || '=' || valueText~length || ':' || valueText || '|'
  end
  return text

::method canonicalValue private
  use arg value
  if value == .nil then return 'NULL'
  if value == .true then return 'BOOLEAN:TRUE'
  if value == .false then return 'BOOLEAN:FALSE'
  if value~class == .String then return 'TEXT:' || value~length || ':' || value
  if datatype(value, 'N') == 1 then return 'NUMBER:' || value
  if value~hasMethod('ALGORITHMCANONICALTEXT') then do
    objectText = value~algorithmCanonicalText
    return 'OBJECT:' || objectText~length || ':' || objectText
  end
  raise syntax 93.900 additional('Legal assessment value lacks explicit canonical contract')

::method field private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x

::method inlineField private
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '|'


::class LegalEffectEvaluationEnvelope public
::attribute assessment get
::attribute generationSnapshot get
::attribute inputSnapshot get
::attribute assessmentEvidence get
::attribute integrityStatus get
::attribute detail get

::method init
  expose assessment generationSnapshot inputSnapshot assessmentEvidence integrityStatus detail canonicalTextValue
  use arg assessmentArg, generationSnapshotArg, inputSnapshotArg, assessmentEvidenceArg, integrityStatusArg = 'PINNED', detailArg = ''
  assessment = assessmentArg
  generationSnapshot = generationSnapshotArg
  inputSnapshot = inputSnapshotArg
  assessmentEvidence = assessmentEvidenceArg
  integrityStatus = integrityStatusArg~string~upper
  detail = detailArg~string
  canonicalTextValue = 'LEGAL_EFFECT_EVALUATION_ENVELOPE_V1' || '0a'x
  canonicalTextValue = canonicalTextValue || 'STATUS=' || integrityStatus || '0a'x
  canonicalTextValue = canonicalTextValue || 'GENERATION=' || generationSnapshot~canonicalIdentity || '0a'x
  canonicalTextValue = canonicalTextValue || 'INPUT=' || inputSnapshot~canonicalIdentity || '0a'x
  evidenceText = assessmentEvidence~algorithmCanonicalText
  canonicalTextValue = canonicalTextValue || 'ASSESSMENT=' || evidenceText~length || ':' || evidenceText || '0a'x

::method algorithmCanonicalText
  expose canonicalTextValue
  return canonicalTextValue


::class LegalEffectPinnedEvaluationResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute envelope get

::method init
  expose ok code detail envelope
  use arg okArg, codeArg, detailArg = '', envelopeArg = .nil
  ok = okArg
  code = codeArg~string
  detail = detailArg~string
  envelope = envelopeArg


::class LegalEffectPinnedEvaluator public

::method evaluate class
  use arg legalEngine, action, generation, context
  if legalEngine == .nil then return .LegalEffectPinnedEvaluationResult~new(.false, 'INVALID_ENGINE', 'Legal engine must not be .nil')
  if action == .nil then return .LegalEffectPinnedEvaluationResult~new(.false, 'INVALID_ACTION', 'Legal action must not be .nil')
  if context == .nil then return .LegalEffectPinnedEvaluationResult~new(.false, 'INVALID_CONTEXT', 'Legal context must not be .nil')
  if generation == .nil then return .LegalEffectPinnedEvaluationResult~new(.false, 'INVALID_GENERATION', 'Legal generation must not be .nil')
  if \generation~sealed then return .LegalEffectPinnedEvaluationResult~new(.false, 'GENERATION_NOT_SEALED', 'Legal generation must be sealed')

  signal on syntax name pinInputFailed
  beforeGeneration = .LegalEffectGenerationSnapshot~new(generation)
  beforeInput = .LegalEffectEvaluationInputSnapshot~new(beforeGeneration, action, context)
  signal off syntax

  evaluation = legalEngine~evaluate(action, generation, context)
  if \evaluation~ok then return .LegalEffectPinnedEvaluationResult~new(.false, evaluation~code, evaluation~detail)

  signal on syntax name pinInputFailed
  afterGeneration = .LegalEffectGenerationSnapshot~new(generation)
  afterInput = .LegalEffectEvaluationInputSnapshot~new(afterGeneration, action, context)
  signal off syntax

  if beforeGeneration~canonicalIdentity \== afterGeneration~canonicalIdentity then do
    return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_GENERATION_CHANGED_DURING_EVALUATION', beforeGeneration~canonicalIdentity || ' -> ' || afterGeneration~canonicalIdentity)
  end
  if beforeInput~actionIdentity \== afterInput~actionIdentity then do
    return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_ACTION_CHANGED_DURING_EVALUATION', beforeInput~actionIdentity || ' -> ' || afterInput~actionIdentity)
  end
  if beforeInput~contextIdentity \== afterInput~contextIdentity then do
    return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_CONTEXT_CHANGED_DURING_EVALUATION', beforeInput~contextIdentity || ' -> ' || afterInput~contextIdentity)
  end

  assessment = evaluation~value
  reductionCheck = self~validateAssessmentReduction(assessment)
  if reductionCheck \== '' then return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_STATUS_REDUCTION_AMBIGUOUS', reductionCheck)
  evidence = .LegalEffectAssessmentEvidence~new(assessment, beforeGeneration, beforeInput)
  envelope = .LegalEffectEvaluationEnvelope~new(assessment, beforeGeneration, beforeInput, evidence, 'PINNED', 'generation + action + current context closure stable across evaluation')
  return .LegalEffectPinnedEvaluationResult~new(.true, 'OK', 'legal evaluation input pinned', envelope)

pinInputFailed:
  signal off syntax
  conditionObject = condition('O')
  detailText = 'legal evaluation input lacks deterministic canonical closure'
  if conditionObject \== .nil then do
    messageText = conditionObject['MESSAGE']
    if messageText \== .nil then detailText = messageText~string
  end
  return .LegalEffectPinnedEvaluationResult~new(.false, 'LEGAL_EVALUATION_INPUT_UNPINNABLE', detailText)

::method validateAssessmentReduction private class
  use arg assessment
  if assessment == .nil then return 'assessment is .nil'
  hasBlocking = .false
  hasReview = .false
  hasConditional = .false
  do disposition over assessment~dispositions
    select
      when disposition == 'PROHIBITED' then hasBlocking = .true
      when disposition == 'CONTRACT_BREACH' then hasBlocking = .true
      when disposition == 'TREATY_BREACH' then hasBlocking = .true
      when disposition == 'STATUS_EFFECT' then hasReview = .true
      when disposition == 'REVIEW' then hasReview = .true
      when disposition == 'REQUIRES_OBLIGATION' then hasConditional = .true
      otherwise nop
    end
  end
  /* BLOCKED is order-stable because blocking dispositions assign it
     unconditionally. Unresolved matches pre-establish REVIEW_REQUIRED and
     likewise make the conditional/review mixture stable. Without either,
     v0.1's sequential status reducer makes REVIEW + REQUIRES_OBLIGATION
     depend on disposition iteration order. Refuse authority rather than
     invent a precedence that belongs in Legal Effect itself. */
  if \hasBlocking then do
    if assessment~unresolved~items = 0 then do
      if hasReview & hasConditional then return 'Legal Effect v0.1 has REVIEW/STATUS_EFFECT and REQUIRES_OBLIGATION dispositions without an explicit precedence rule'
    end
  end
  return ''


::class LegalEffectPromotionAdapter public

::method promotionsFrom class
  use arg sourceObject, prefix = 'LEGAL_'
  if sourceObject == .nil then raise syntax 93.900 additional('Legal promotion source must not be .nil')

  if sourceObject~hasMethod('INTEGRITYSTATUS') then do
    if \sourceObject~hasMethod('ASSESSMENT') then raise syntax 93.900 additional('Pinned legal envelope has no ASSESSMENT method')
    assessment = sourceObject~assessment
    evidence = sourceObject~assessmentEvidence
    if sourceObject~integrityStatus == 'PINNED' then do
      promotionStatus = .EvidencePromotionConstant~STATUS_AUTHORIZED
      promotionReason = 'sealed legal assessment from stable generation closure'
    end
    else do
      promotionStatus = .EvidencePromotionConstant~STATUS_UNRESOLVED
      promotionReason = 'legal evaluation envelope is not pinned:' sourceObject~integrityStatus
    end
  end
  else do
    assessment = sourceObject
    evidence = .LegalEffectAssessmentEvidence~new(assessment)
    promotionStatus = .EvidencePromotionConstant~STATUS_UNRESOLVED
    promotionReason = 'LEGAL_EFFECT_V0.1 assessment was not captured by pinned evaluator; authority promotion refused'
  end

  if assessment~generation == .nil then raise syntax 93.900 additional('Legal assessment has no generation')
  if \assessment~generation~sealed then raise syntax 93.900 additional('Only assessments from sealed legal generations may enter promotion')

  sourceIdentity = evidence~canonicalIdentity
  generationIdentity = evidence~generationSnapshot~canonicalIdentity
  authority = 'LEGAL_EFFECT/' || assessment~generation~generationId || '@' || generationIdentity
  policyId = 'LEGAL_EFFECT_STATUS_PROJECTION_V1'

  promotionSet = .EvidencePromotionSet~new
  blocked = assessment~status == 'BLOCKED'
  review = assessment~status == 'REVIEW_REQUIRED'
  conditional = assessment~status == 'CONDITIONAL'

  blockedBasis = self~basisFor(assessment, 'BLOCKED')
  reviewBasis = self~basisFor(assessment, 'REVIEW_REQUIRED')
  conditionalBasis = self~basisFor(assessment, 'CONDITIONAL')

  p = .EvidencePromotion~new(sourceIdentity || ':BLOCKED', 'LEGAL_EFFECT', sourceIdentity, prefix || 'ACTION_BLOCKED', 'KNOWN', blocked, authority, policyId, 'ASSESSMENT_STATUS', 'LEGAL_EFFECT', promotionStatus, promotionReason, evidence, assessment, 'FROZEN_OBSERVATION', 'FROZEN_OBSERVATION', blockedBasis)
  ignored = promotionSet~add(p)
  p = .EvidencePromotion~new(sourceIdentity || ':REVIEW', 'LEGAL_EFFECT', sourceIdentity, prefix || 'ACTION_REVIEW_REQUIRED', 'KNOWN', review, authority, policyId, 'ASSESSMENT_STATUS', 'LEGAL_EFFECT', promotionStatus, promotionReason, evidence, assessment, 'FROZEN_OBSERVATION', 'FROZEN_OBSERVATION', reviewBasis)
  ignored = promotionSet~add(p)
  p = .EvidencePromotion~new(sourceIdentity || ':CONDITIONAL', 'LEGAL_EFFECT', sourceIdentity, prefix || 'ACTION_CONDITIONAL', 'KNOWN', conditional, authority, policyId, 'ASSESSMENT_STATUS', 'LEGAL_EFFECT', promotionStatus, promotionReason, evidence, assessment, 'FROZEN_OBSERVATION', 'FROZEN_OBSERVATION', conditionalBasis)
  ignored = promotionSet~add(p)
  ignored = promotionSet~seal
  return promotionSet

::method basisFor private class
  use arg assessment, targetStatus
  basis = .array~new
  generationDetail = assessment~generation~generationId || '/' || assessment~generation~version
  basis~append(.EvidencePromotionBasis~new('LEGAL_GENERATION', assessment~generation~generationId, generationDetail, assessment~generation))
  basis~append(.EvidencePromotionBasis~new('LEGAL_ACTION', assessment~action~actionCode, assessment~action~description, assessment~action))
  basis~append(.EvidencePromotionBasis~new('ASSESSMENT_STATUS', targetStatus, 'actual=' || assessment~status, assessment))

  do matchObject over assessment~afterMatches
    if matchObject~status \== 'APPLIES' then iterate
    include = .false
    select
      when targetStatus == 'BLOCKED' then do
        if matchObject~norm~disposition == 'PROHIBITED' then include = .true
        else if matchObject~norm~disposition == 'CONTRACT_BREACH' then include = .true
        else if matchObject~norm~disposition == 'TREATY_BREACH' then include = .true
      end
      when targetStatus == 'REVIEW_REQUIRED' then do
        if matchObject~norm~disposition == 'STATUS_EFFECT' then include = .true
        else if matchObject~norm~disposition == 'REVIEW' then include = .true
      end
      when targetStatus == 'CONDITIONAL' then do
        if matchObject~norm~disposition == 'REQUIRES_OBLIGATION' then include = .true
      end
      otherwise nop
    end
    if include then basis~append(.EvidencePromotionBasis~new('LEGAL_NORM', matchObject~norm~normId, matchObject~norm~sourceId || '/' || matchObject~norm~provisionId || '/' || matchObject~norm~disposition, matchObject~norm))
  end

  if targetStatus == 'REVIEW_REQUIRED' then do matchObject over assessment~unresolved
    basis~append(.EvidencePromotionBasis~new('LEGAL_NORM_UNRESOLVED', matchObject~norm~normId, matchObject~status, matchObject~norm))
  end
  return basis

::requires '../algorithm/EvidencePromotion.cls'
::requires '../algorithm/AlgorithmIntegrity.cls'
