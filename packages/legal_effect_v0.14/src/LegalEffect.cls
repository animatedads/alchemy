/*
 * Legal Effect v0.14
 *
 * Deterministic, evidence-bearing legal/contract/treaty effect model.
 * LLMs may propose these objects; executable authority begins only after a
 * LegalRuleGeneration is sealed and, for live use, published through the
 * Runtime Registry.
 */

::class LegalEffectBuild public
::constant VERSION "0.14"
::constant API_VERSION "legal.effect/0.10"


/* -------------------------------------------------------------------------
 * Alchemy operational-object base (v0.11)
 *
 * Legal semantic objects deliberately remain plain, deterministic value/graph
 * objects.  Stateful operational services inherit AlchemyObject so identity,
 * lifecycle evidence, telemetry, bounded introspection, requirements and the
 * ooRexx Security Manager surface come from one project-wide base.  None of
 * this operational metadata participates in LegalRuleGeneration semantic
 * identity.
 * ------------------------------------------------------------------------- */
::class LegalAlchemyObject subclass AlchemyObject public

::method init public
  use arg sealer = .nil, capabilityAuthority = .nil
  self~initLegalAlchemy(self~class~id, sealer, capabilityAuthority)

::method initLegalAlchemy protected
  use arg roleArg, sealer = .nil, capabilityAuthority = .nil
  role = roleArg~string~translate
  metadata = .directory~new
  metadata["purpose"] = "Legal Effect operational service"
  metadata["component"] = "LEGAL_EFFECT"
  metadata["package_version"] = .LegalEffectBuild~VERSION
  metadata["component_api"] = .LegalEffectBuild~API_VERSION
  metadata["role"] = role
  self~initAlchemy(metadata, sealer, capabilityAuthority)
  self~registerExternalRequirement("library", "alchemy_objects", "0.4.3", .true)
  self~registerExternalRequirement("library", "oorexx_crypto", "0.1", .true)
  self~registerMethodContract("LEGALCOMPONENTIDENTITY", "Detached operational identity; not legal semantic authority", .array~new, "DIRECTORY", .false)
  self~describeMethodPolicy("LEGALCOMPONENTIDENTITY", "FALSE", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerLegalAlchemyContracts(role)
  return self

::method registerLegalAlchemyContracts private
  use arg role
  select
    when role = "LEGALFRAMEWORKRESOLVER" then do
      self~registerMethodContract("RESOLVE", "Resolve a time/jurisdiction-specific legal framework snapshot", .array~of("GENERATION", "CONTEXT"), "LEGALRESULT", .false)
      self~describeMethodPolicy("RESOLVE", "AUTO", "PUBLIC", "AUTHORITY", "READ", "USE")
    end
    when role = "LEGALEFFECTENGINE" then do
      self~registerMethodContract("EVALUATE", "Evaluate one proposed action against a sealed legal generation", .array~of("ACTION", "GENERATION", "CONTEXT"), "LEGALRESULT", .false)
      self~describeMethodPolicy("EVALUATE", "AUTO", "PUBLIC", "AUTHORITY", "READ", "USE")
    end
    when role = "LEGALDECISIONTRACEBUILDER" then do
      self~registerMethodContract("BUILD", "Build a deterministic structured causal trace from one completed legal assessment", .array~of("ASSESSMENT"), "LEGALRESULT", .false)
      self~describeMethodPolicy("BUILD", "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
    end
    when role = "LEGALDECISIONTRACEQUERY" then do
      self~registerMethodContract("WHYFINALSTATUS", "Return the causal graph slice that produced the final status", .array~of("TRACE"), "LEGALRESULT", .false)
      self~registerMethodContract("CONTROLLINGNORMS", "Return effective norms that produced final dispositions", .array~of("TRACE"), "LEGALRESULT", .false)
      self~registerMethodContract("SUPPRESSEDNORMS", "Return norms suppressed by authority/conflict resolution", .array~of("TRACE"), "LEGALRESULT", .false)
      self~registerMethodContract("AUTHORITYRULES", "Return authority rules in the causal path to the final status", .array~of("TRACE"), "LEGALRESULT", .false)
      self~registerMethodContract("WHATCHANGED", "Return proposed fact mutations and applicability-change relations", .array~of("TRACE"), "LEGALRESULT", .false)
      self~registerMethodContract("REVIEWINPUTS", "Return unresolved causal inputs that require review without predicting a counterfactual outcome", .array~of("TRACE"), "LEGALRESULT", .false)
      self~registerMethodContract("SOURCEANCHORS", "Return source/provision-bearing nodes in the final causal closure", .array~of("TRACE"), "LEGALRESULT", .false)
      do n over .array~of("WHYFINALSTATUS", "CONTROLLINGNORMS", "SUPPRESSEDNORMS", "AUTHORITYRULES", "WHATCHANGED", "REVIEWINPUTS", "SOURCEANCHORS")
        self~describeMethodPolicy(n, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
      end
    end
    when role = "LEGALCOUNTERFACTUALEVALUATOR" then do
      self~registerMethodContract("EVALUATEFACT", "Evaluate one explicit hypothetical fact assumption against the same sealed legal world", .array~of("ASSESSMENT", "FACT_NAME", "VALUE", "STATE", "SCOPE"), "LEGALRESULT", .false)
      self~registerMethodContract("EVALUATEBOOLEAN", "Evaluate both TRUE and FALSE branches for one explicit hypothetical fact", .array~of("ASSESSMENT", "FACT_NAME", "SCOPE"), "LEGALRESULT", .false)
      self~describeMethodPolicy("EVALUATEFACT", "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
      self~describeMethodPolicy("EVALUATEBOOLEAN", "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
    end
    when role = "LEGALSOURCEVERIFIER" then do
      self~registerMethodContract("VERIFYSOURCE", "Verify exact source representation against its declared digest", .array~of("IDENTITY", "MATERIAL"), "LEGALSOURCEVERIFICATIONEVIDENCE", .false)
      self~registerMethodContract("VERIFYPROVISION", "Verify exact provision representation against its declared digest", .array~of("REFERENCE", "MATERIAL", "PARENT_EVIDENCE"), "LEGALSOURCEVERIFICATIONEVIDENCE", .false)
      self~registerMethodContract("BINDSOURCE", "Bind verifier-issued evidence to a source identity", .array~of("IDENTITY", "MATERIAL"), "LEGALSOURCEVERIFICATIONEVIDENCE", .false)
      self~registerMethodContract("BINDPROVISION", "Bind verifier-issued evidence to a provision identity", .array~of("REFERENCE", "MATERIAL", "PARENT_EVIDENCE"), "LEGALSOURCEVERIFICATIONEVIDENCE", .false)
      do n over .array~of("VERIFYSOURCE", "VERIFYPROVISION", "BINDSOURCE", "BINDPROVISION")
        self~describeMethodPolicy(n, "AUTO", "PUBLIC", "SECURITY_BOUNDARY", "READ", "USE")
      end
    end
    when role = "LEGALSOURCEAUTHORITYTRUSTPROFILE" then do
      self~registerMethodContract("ADDSIGNER", "Add a host-trusted source-authority signer", .array~of("SIGNER"), "LEGALRESULT", .false)
      self~registerMethodContract("ADDPOLICY", "Add a host-owned source-authority threshold policy", .array~of("POLICY"), "LEGALRESULT", .false)
      self~describeMethodPolicy("ADDSIGNER", "AUTO", "INTERNAL", "SECURITY_BOUNDARY", "MUTATE", "GRANT")
      self~describeMethodPolicy("ADDPOLICY", "AUTO", "INTERNAL", "SECURITY_BOUNDARY", "MUTATE", "GRANT")
    end
    when role = "LEGALSOURCEAUTHORITYVERIFIER" then do
      self~registerMethodContract("VERIFY", "Revalidate signed source-authority claims against host-owned trust", .array~of("IDENTITY", "ATTESTATION", "TRUST_PROFILE"), "LEGALSOURCEAUTHORITYVERIFICATIONEVIDENCE", .false)
      self~describeMethodPolicy("VERIFY", "AUTO", "PUBLIC", "SECURITY_BOUNDARY", "READ", "USE")
    end
    when role = "LEGALRULECOMPILER" then do
      self~registerMethodContract("COMPILE", "Freeze, validate and certify one exact legal compilation input", .array~of("UNIT"), "LEGALCOMPILATIONREPORT", .false)
      self~describeMethodPolicy("COMPILE", "AUTO", "PUBLIC", "AUTHORITY", "MUTATE", "GRANT")
    end
    when role = "LEGALRUNTIMERULERESOLVER" then do
      self~registerMethodContract("ACQUIRE", "Acquire a runtime-pinned legal generation after host source-authority verification", .array~of("RUNTIME_KERNEL", "ENVIRONMENT", "MODULE_ID", "TRUST_PROFILE", "AUTHORITY_VERIFIER"), "LEGALRESULT", .false)
      self~describeMethodPolicy("ACQUIRE", "AUTO", "PUBLIC", "SECURITY_BOUNDARY", "EXTERNAL", "USE")
    end
    otherwise nop
  end
  return self

::method legalComponentIdentity public
  expose alchemyObjectId
  d = .directory~new
  d["schema"] = "legal.effect.operational-object/0.1"
  d["package_version"] = .LegalEffectBuild~VERSION
  d["legal_api"] = .LegalEffectBuild~API_VERSION
  d["alchemy_base_version"] = .AlchemyObject~VERSION
  d["class"] = self~class~id
  d["alchemy_object_id"] = alchemyObjectId
  return d


::class LegalResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get

::method init
  expose ok code detail value
  use arg okArg, codeArg, detailArg = "", valueArg = .nil
  ok = okArg
  code = codeArg~string
  detail = detailArg~string
  value = valueArg

::method success class
  use arg value = .nil, detail = ""
  return self~new(.true, "OK", detail, value)

::method failure class
  use arg code, detail = "", value = .nil
  return self~new(.false, code, detail, value)




::class LegalCanonical public

::method field class
  use arg tag, value = ""
  if value == .nil then valueText = "<NIL>"
  else valueText = value~string
  return tag~string || ":" || valueText~length || ":" || valueText

::method scalar class
  use arg value
  if value == .nil then return "N"
  if value == .true then return "B1"
  if value == .false then return "B0"
  return "S" || self~field("V", value~string)

::method objectIdentity class
  use arg object
  if object == .nil then return "NONE"
  if object~hasMethod("EVIDENCEIDENTITY") then return "EVIDENCE:" || object~evidenceIdentity~string
  if object~hasMethod("SEMANTICIDENTITY") then return "SEMANTIC:" || object~semanticIdentity~string
  if object~hasMethod("ALGORITHMCANONICALTEXT") then return "ALGORITHM:" || object~algorithmCanonicalText~string
  return "OPAQUE:" || object~class~id~string

::method sortedStrings class
  use arg source
  out = .array~new
  if source == .nil then return out
  do item over source
    out~append(item~string)
  end
  i = 2
  do while i <= out~items
    current = out[i]
    j = i - 1
    do while j >= 1
      if out[j] <= current then leave
      out[j + 1] = out[j]
      j = j - 1
    end
    out[j + 1] = current
    i = i + 1
  end
  return out

::method joinCanonical class
  use arg tag, values
  sorted = self~sortedStrings(values)
  text = self~field(tag || "_COUNT", sorted~items)
  do item over sorted
    text ||= self~field(tag, item)
  end
  return text


::class LegalEvidenceAnchor public
::attribute sourceId get
::attribute sourceKind get
::attribute citation get
::attribute sourceObject get
::attribute authority get
::attribute observedAt get

::method init
  expose sourceId sourceKind citation sourceObject authority observedAt metadata
  use arg sourceIdArg, sourceKindArg, citationArg = "", sourceObjectArg = .nil, authorityArg = "", metadataArg = .nil
  sourceId = sourceIdArg~string
  sourceKind = sourceKindArg~string~upper
  citation = citationArg~string
  sourceObject = sourceObjectArg
  authority = authorityArg~string
  if metadataArg == .nil then metadata = .table~new
  else metadata = metadataArg
  observedAt = .DateTime~new~utcIsoDate

::method isEvidenceBearing
  expose sourceObject citation
  if sourceObject \== .nil then return .true
  return citation <> ""

::method metadata
  expose metadata
  copy = .table~new
  do key over metadata
    copy[key] = metadata[key]
  end
  return copy

::method provenance
  expose sourceId sourceKind citation sourceObject authority observedAt metadata
  p = .table~new
  p["sourceId"] = sourceId
  p["sourceKind"] = sourceKind
  p["citation"] = citation
  p["sourceObject"] = sourceObject
  p["authority"] = authority
  p["observedAt"] = observedAt
  p["metadata"] = self~metadata
  return p


::method canonicalText
  expose sourceId sourceKind citation sourceObject authority metadata
  text = .LegalCanonical~field("SOURCE_ID", sourceId)
  text ||= .LegalCanonical~field("SOURCE_KIND", sourceKind)
  text ||= .LegalCanonical~field("CITATION", citation)
  text ||= .LegalCanonical~field("AUTHORITY", authority)
  text ||= .LegalCanonical~field("SOURCE_OBJECT_IDENTITY", .LegalCanonical~objectIdentity(sourceObject))
  entries = .array~new
  do key over metadata
    entries~append(.LegalCanonical~field("K", key~string) || .LegalCanonical~field("V", metadata[key]~string))
  end
  text ||= .LegalCanonical~joinCanonical("META", entries)
  return text


::class NormativeSource public
::attribute sourceId get
::attribute sourceKind get
::attribute title get
::attribute authority get
::attribute jurisdictionId get
::attribute governingLaw get
::attribute applicabilityMode get
::attribute sealed get
::attribute sourceIdentity get

::method init
  expose sourceId sourceKind title authority jurisdictionId governingLaw applicabilityMode evidence sealed sourceIdentity
  use arg sourceIdArg, sourceKindArg, titleArg, authorityArg = "", jurisdictionArg = "*", governingLawArg = "", applicabilityModeArg = "AUTO"
  sourceId = sourceIdArg~string
  sourceKind = sourceKindArg~string~upper
  title = titleArg~string
  authority = authorityArg~string
  jurisdictionId = jurisdictionArg~string~upper
  governingLaw = governingLawArg~string
  applicabilityMode = applicabilityModeArg~string~upper
  if applicabilityMode = "AUTO" then do
    select
      when sourceKind = "CONTRACT" then applicabilityMode = "EXPLICIT"
      when sourceKind = "TREATY" then applicabilityMode = "EXPLICIT"
      when sourceKind = "LICENCE" then applicabilityMode = "EXPLICIT"
      when sourceKind = "ADMINISTRATIVE_ORDER" then applicabilityMode = "EXPLICIT"
      when sourceKind = "COLLECTIVE_AGREEMENT" then applicabilityMode = "EXPLICIT"
      otherwise applicabilityMode = "JURISDICTIONAL"
    end
  end
  evidence = .array~new
  sealed = .false
  sourceIdentity = .nil

::method bindSourceIdentity
  expose sourceId sourceKind sealed sourceIdentity
  use arg identity
  if sealed then return .LegalResult~failure("SOURCE_SEALED", "Normative source is sealed")
  if identity == .nil then return .LegalResult~failure("SOURCE_IDENTITY_REQUIRED", sourceId)
  if identity~sourceId <> sourceId then return .LegalResult~failure("SOURCE_IDENTITY_MISMATCH", identity~sourceId || " != " || sourceId)
  if identity~sourceKind <> sourceKind then return .LegalResult~failure("SOURCE_KIND_MISMATCH", identity~sourceKind || " != " || sourceKind)
  sourceIdentity = identity
  return .LegalResult~success(identity)

::method addEvidence
  expose evidence sealed
  use arg anchor
  if sealed then return .LegalResult~failure("SOURCE_SEALED", "Normative source is sealed")
  evidence~append(anchor)
  return .LegalResult~success(anchor)

::method seal
  expose sealed
  sealed = .true
  return self

::method evidence
  expose evidence
  copy = .array~new
  do item over evidence
    copy~append(item)
  end
  return copy

::method evidenceCopy
  return self~evidence


::method canonicalText
  expose sourceId sourceKind title authority jurisdictionId governingLaw applicabilityMode evidence sourceIdentity
  text = .LegalCanonical~field("SOURCE_ID", sourceId)
  text ||= .LegalCanonical~field("SOURCE_KIND", sourceKind)
  text ||= .LegalCanonical~field("TITLE", title)
  text ||= .LegalCanonical~field("AUTHORITY", authority)
  text ||= .LegalCanonical~field("JURISDICTION", jurisdictionId)
  text ||= .LegalCanonical~field("GOVERNING_LAW", governingLaw)
  text ||= .LegalCanonical~field("APPLICABILITY_MODE", applicabilityMode)
  if sourceIdentity == .nil then identityText = "NONE"
  else identityText = sourceIdentity~canonicalText
  text ||= .LegalCanonical~field("SOURCE_IDENTITY", identityText)
  evidenceText = .array~new
  do anchor over evidence
    evidenceText~append(anchor~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("EVIDENCE", evidenceText)
  return text


::class LegalJurisdictionClaim public
::attribute authorityId get
::attribute territoryId get
::attribute subjectMatter get
::attribute basis get
::attribute source get

::method init
  expose authorityId territoryId subjectMatter basis source
  use arg authorityArg, territoryArg, subjectMatterArg = "*", basisArg = "", sourceArg = .nil
  authorityId = authorityArg~string~upper
  territoryId = territoryArg~string~upper
  subjectMatter = subjectMatterArg~string~upper
  basis = basisArg~string
  source = sourceArg

::method matches
  expose authorityId territoryId subjectMatter
  use arg wantedAuthority, wantedTerritory, wantedSubject = "*"
  wantedAuthority = wantedAuthority~string~upper
  wantedTerritory = wantedTerritory~string~upper
  wantedSubject = wantedSubject~string~upper
  if authorityId <> "*" then do
    if authorityId <> wantedAuthority then return .false
  end
  if territoryId <> "*" then do
    if territoryId <> wantedTerritory then return .false
  end
  if subjectMatter <> "*" then do
    if wantedSubject <> "*" then do
      if subjectMatter <> wantedSubject then return .false
    end
  end
  return .true

::method string
  expose authorityId territoryId subjectMatter
  return authorityId || "/" || territoryId || "/" || subjectMatter


::method canonicalText
  expose authorityId territoryId subjectMatter basis source
  text = .LegalCanonical~field("AUTHORITY", authorityId)
  text ||= .LegalCanonical~field("TERRITORY", territoryId)
  text ||= .LegalCanonical~field("SUBJECT", subjectMatter)
  text ||= .LegalCanonical~field("BASIS", basis)
  text ||= .LegalCanonical~field("SOURCE", .LegalCanonical~objectIdentity(source))
  return text


::class LegalTemporalScope public
::attribute entryIntoForce get
::attribute efficacyFrom get
::attribute efficacyTo get
::attribute applicabilityFrom get
::attribute applicabilityTo get

::method init
  expose entryIntoForce efficacyFrom efficacyTo applicabilityFrom applicabilityTo
  use arg entryArg = "", efficacyFromArg = "", efficacyToArg = "", applicabilityFromArg = "", applicabilityToArg = ""
  entryIntoForce = self~normalDate(entryArg)
  efficacyFrom = self~normalDate(efficacyFromArg)
  efficacyTo = self~normalDate(efficacyToArg)
  applicabilityFrom = self~normalDate(applicabilityFromArg)
  applicabilityTo = self~normalDate(applicabilityToArg)

::method isApplicable
  expose entryIntoForce efficacyFrom efficacyTo applicabilityFrom applicabilityTo
  use arg eventDate, evaluationDate = ""
  eventDate = self~normalDate(eventDate)
  evaluationDate = self~normalDate(evaluationDate)
  if evaluationDate = "" then evaluationDate = eventDate
  if eventDate = "" then return .false
  if entryIntoForce <> "" then if evaluationDate < entryIntoForce then return .false
  if efficacyFrom <> "" then if eventDate < efficacyFrom then return .false
  if efficacyTo <> "" then if eventDate > efficacyTo then return .false
  if applicabilityFrom <> "" then if eventDate < applicabilityFrom then return .false
  if applicabilityTo <> "" then if eventDate > applicabilityTo then return .false
  return .true

::method effectiveDate
  expose applicabilityFrom efficacyFrom entryIntoForce
  if applicabilityFrom <> "" then return applicabilityFrom
  if efficacyFrom <> "" then return efficacyFrom
  if entryIntoForce <> "" then return entryIntoForce
  return "0000-00-00"

::method normalDate private
  use arg value
  if value == .nil then return ""
  text = value~string~strip
  if text = "" then return ""
  if text~length >= 10 then return text~left(10)
  return text


::method canonicalText
  expose entryIntoForce efficacyFrom efficacyTo applicabilityFrom applicabilityTo
  text = .LegalCanonical~field("ENTRY", entryIntoForce)
  text ||= .LegalCanonical~field("EFFICACY_FROM", efficacyFrom)
  text ||= .LegalCanonical~field("EFFICACY_TO", efficacyTo)
  text ||= .LegalCanonical~field("APPLICABILITY_FROM", applicabilityFrom)
  text ||= .LegalCanonical~field("APPLICABILITY_TO", applicabilityTo)
  return text


::class LegalFact public
::attribute name get
::attribute value get
::attribute state get
::attribute source get
::attribute authority get
::attribute evidence get

::method init
  expose name value state source authority evidence
  use arg nameArg, valueArg = .nil, stateArg = "KNOWN", sourceArg = .nil, authorityArg = "DECLARED", evidenceArg = .nil
  name = nameArg~string~upper
  value = valueArg
  state = stateArg~string~upper
  source = sourceArg
  authority = authorityArg~string
  evidence = evidenceArg

::method richEvidence
  expose evidence
  if evidence == .nil then return .nil
  if evidence~hasMethod("RUNTIMEEVIDENCE") then do
    if evidence~hasMethod("VALUE") then return evidence~value
  end
  return evidence

::method runtimeEvidence
  expose evidence
  if evidence == .nil then return .nil
  if evidence~hasMethod("RUNTIMEEVIDENCE") then return evidence~runtimeEvidence
  return .nil

::method sourceProvenance
  expose source
  if source == .nil then return .nil
  if source~hasMethod("PROVENANCE") then return source~provenance
  return .nil

::method evidenceProvenance
  expose evidence
  if evidence == .nil then return .nil
  if evidence~hasMethod("PROVENANCE") then return evidence~provenance
  return .nil


::class LegalFactSet public
::attribute facts get

::method init
  expose facts
  facts = .directory~new

::method putKnown
  expose facts
  use arg name, value, source = .nil, authority = "DECLARED", evidence = .nil
  key = name~string~upper
  facts[key] = .LegalFact~new(key, value, "KNOWN", source, authority, evidence)
  return facts[key]

::method putUnknown
  expose facts
  use arg name, source = .nil, authority = "DECLARED", evidence = .nil
  key = name~string~upper
  facts[key] = .LegalFact~new(key, .nil, "UNKNOWN", source, authority, evidence)
  return facts[key]

::method putConflict
  expose facts
  use arg name, source = .nil, authority = "DECLARED", evidence = .nil
  key = name~string~upper
  facts[key] = .LegalFact~new(key, .nil, "CONFLICT", source, authority, evidence)
  return facts[key]

::method putRichFact
  use arg richFactArg
  if richFactArg == .nil then return .LegalResult~failure("INVALID_FACT", "Fact must not be .nil")

  richFact = richFactArg
  retainedEvidence = richFactArg
  authority = "STRUCTURED_RELATION"

  if richFactArg~hasMethod("RUNTIMEEVIDENCE") then do
    if \richFactArg~hasMethod("VALUE") then return .LegalResult~failure("INVALID_RUNTIME_EVIDENCE", "Runtime evidence envelope has no VALUE method")
    richFact = richFactArg~value
    if richFact == .nil then return .LegalResult~failure("INVALID_RUNTIME_EVIDENCE", "Runtime evidence envelope contains no fact")
    authority = "STRUCTURED_RELATION_RUNTIME_EVIDENCE"
  end

  if \richFact~hasMethod("NAME") then return .LegalResult~failure("INVALID_FACT", "Fact has no NAME method")
  if \richFact~hasMethod("STATE") then return .LegalResult~failure("INVALID_FACT", "Fact has no STATE method")
  state = richFact~state~string~upper
  source = .nil
  if richFact~hasMethod("SOURCE") then source = richFact~source
  value = .nil
  if richFact~hasMethod("VALUE") then value = richFact~value
  select
    when state = "KNOWN" then added = self~putKnown(richFact~name, value, source, authority, retainedEvidence)
    when state = "PRESENT" then added = self~putKnown(richFact~name, value, source, authority, retainedEvidence)
    when state = "PRESENT_EMPTY" then added = self~putKnown(richFact~name, value, source, authority, retainedEvidence)
    when state = "UNKNOWN" then added = self~putUnknown(richFact~name, source, authority, retainedEvidence)
    when state = "CONFLICT" then added = self~putConflict(richFact~name, source, authority, retainedEvidence)
    otherwise return .LegalResult~failure("UNSUPPORTED_FACT_STATE", state)
  end
  return .LegalResult~success(added)

::method fact
  expose facts
  use arg name
  key = name~string~upper
  if facts~hasIndex(key) then return facts[key]
  return .LegalFact~new(key, .nil, "UNKNOWN", .nil, "ABSENT")

::method allFacts
  expose facts
  copy = .array~new
  do key over facts
    copy~append(facts[key])
  end
  return copy

::method clone
  expose facts
  copy = .LegalFactSet~new
  do key over facts
    factObject = facts[key]
    select
      when factObject~state = "KNOWN" then ignored = copy~putKnown(key, factObject~value, factObject~source, factObject~authority, factObject~evidence)
      when factObject~state = "CONFLICT" then ignored = copy~putConflict(key, factObject~source, factObject~authority, factObject~evidence)
      otherwise ignored = copy~putUnknown(key, factObject~source, factObject~authority, factObject~evidence)
    end
  end
  return copy


::class LegalPredicate public
::attribute factName get
::attribute operator get
::attribute expectedValue get

::method init
  expose factName operator expectedValue
  use arg factNameArg, operatorArg, expectedValueArg = .nil
  factName = factNameArg~string~upper
  operator = operatorArg~string~upper
  expectedValue = expectedValueArg

::method evaluate
  expose factName operator expectedValue
  use arg factSet
  factObject = factSet~fact(factName)
  if operator = "UNKNOWN" then do
    if factObject~state = "UNKNOWN" then return "TRUE"
    return "FALSE"
  end
  if operator = "CONFLICT" then do
    if factObject~state = "CONFLICT" then return "TRUE"
    return "FALSE"
  end
  if factObject~state = "CONFLICT" then return "CONFLICT"
  if factObject~state <> "KNOWN" then return "UNKNOWN"
  select
    when operator = "KNOWN_TRUE" then do
      if factObject~value == .true then return "TRUE"
      return "FALSE"
    end
    when operator = "KNOWN_FALSE" then do
      if factObject~value == .false then return "TRUE"
      return "FALSE"
    end
    when operator = "EQUALS" then do
      if factObject~value == expectedValue then return "TRUE"
      return "FALSE"
    end
    when operator = "NOT_EQUALS" then do
      if factObject~value \== expectedValue then return "TRUE"
      return "FALSE"
    end
    when operator = "PRESENT" then return "TRUE"
    otherwise return "UNKNOWN"
  end

::method render
  expose factName operator expectedValue
  if expectedValue == .nil then return factName || " " || operator
  return factName || " " || operator || " " || expectedValue~string


::method canonicalText
  expose factName operator expectedValue
  text = .LegalCanonical~field("FACT", factName)
  text ||= .LegalCanonical~field("OP", operator)
  text ||= .LegalCanonical~field("EXPECTED", .LegalCanonical~scalar(expectedValue))
  return text


::class LegalPredicateEvaluation public
::attribute predicate get
::attribute role get
::attribute result get
::attribute fact get

::method init
  expose predicate role result fact
  use arg predicateArg, roleArg, resultArg, factArg = .nil
  predicate = predicateArg
  role = roleArg~string~upper
  result = resultArg~string~upper
  fact = factArg

::method factName
  expose predicate
  if predicate == .nil then return ""
  return predicate~factName

::method factState
  expose fact
  if fact == .nil then return "ABSENT"
  return fact~state

::method factValue
  expose fact
  if fact == .nil then return .nil
  return fact~value

::method factAuthority
  expose fact
  if fact == .nil then return "ABSENT"
  return fact~authority

::method factEvidence
  expose fact
  if fact == .nil then return .nil
  return fact~evidence

::method canonicalText
  expose predicate role result fact
  text = .LegalCanonical~field("ROLE", role)
  text ||= .LegalCanonical~field("RESULT", result)
  if predicate == .nil then predicateText = "NONE"
  else predicateText = predicate~canonicalText
  text ||= .LegalCanonical~field("PREDICATE", predicateText)
  if fact == .nil then do
    text ||= .LegalCanonical~field("FACT_NAME", "")
    text ||= .LegalCanonical~field("FACT_STATE", "ABSENT")
    text ||= .LegalCanonical~field("FACT_VALUE", .LegalCanonical~scalar(.nil))
    text ||= .LegalCanonical~field("FACT_AUTHORITY", "ABSENT")
    text ||= .LegalCanonical~field("FACT_EVIDENCE", "NONE")
  end
  else do
    text ||= .LegalCanonical~field("FACT_NAME", fact~name)
    text ||= .LegalCanonical~field("FACT_STATE", fact~state)
    text ||= .LegalCanonical~field("FACT_VALUE", .LegalCanonical~scalar(fact~value))
    text ||= .LegalCanonical~field("FACT_AUTHORITY", fact~authority)
    text ||= .LegalCanonical~field("FACT_EVIDENCE", .LegalCanonical~objectIdentity(fact~evidence))
  end
  return text


::class LegalNormMatch public
::attribute norm get
::attribute status get
::attribute reasons get

::method init
  expose norm status reasons predicateEvaluations
  use arg normArg, statusArg, reasonsArg = .nil, predicateEvaluationsArg = .nil
  norm = normArg
  status = statusArg~string~upper
  if reasonsArg == .nil then reasons = .array~new
  else reasons = reasonsArg
  predicateEvaluations = .array~new
  if predicateEvaluationsArg \== .nil then do item over predicateEvaluationsArg
    predicateEvaluations~append(item)
  end

::method predicateEvaluations
  expose predicateEvaluations
  copy = .array~new
  do item over predicateEvaluations
    copy~append(item)
  end
  return copy


::class LegalNorm public
::attribute normId get
::attribute sourceId get
::attribute provisionId get
::attribute normType get
::attribute actionCode get
::attribute disposition get
::attribute subjectMatter get
::attribute rationale get
::attribute temporalScope get
::attribute sealed get
::attribute materialVersion get
::attribute conflictKey get

::method init
  expose normId sourceId provisionId normType actionCode disposition subjectMatter rationale temporalScope conditions exceptions jurisdictionClaims evidence sealed materialVersion conflictKey
  use arg normIdArg, sourceIdArg, provisionIdArg, normTypeArg, actionCodeArg, dispositionArg, subjectMatterArg = "*", rationaleArg = "", temporalArg = .nil, materialVersionArg = "*", conflictKeyArg = ""
  normId = normIdArg~string~upper
  sourceId = sourceIdArg~string
  provisionId = provisionIdArg~string
  normType = normTypeArg~string~upper
  actionCode = actionCodeArg~string~upper
  disposition = dispositionArg~string~upper
  subjectMatter = subjectMatterArg~string~upper
  rationale = rationaleArg~string
  materialVersion = materialVersionArg~string~upper
  conflictKey = conflictKeyArg~string~upper
  if temporalArg == .nil then temporalScope = .LegalTemporalScope~new
  else temporalScope = temporalArg
  conditions = .array~new
  exceptions = .array~new
  jurisdictionClaims = .array~new
  evidence = .array~new
  sealed = .false

::method addCondition
  expose conditions sealed
  use arg predicate
  if sealed then return .LegalResult~failure("NORM_SEALED", "Norm is sealed")
  conditions~append(predicate)
  return .LegalResult~success(predicate)

::method addException
  expose exceptions sealed
  use arg predicate
  if sealed then return .LegalResult~failure("NORM_SEALED", "Norm is sealed")
  exceptions~append(predicate)
  return .LegalResult~success(predicate)

::method addJurisdiction
  expose jurisdictionClaims sealed
  use arg claim
  if sealed then return .LegalResult~failure("NORM_SEALED", "Norm is sealed")
  jurisdictionClaims~append(claim)
  return .LegalResult~success(claim)

::method addEvidence
  expose evidence sealed
  use arg anchor
  if sealed then return .LegalResult~failure("NORM_SEALED", "Norm is sealed")
  evidence~append(anchor)
  return .LegalResult~success(anchor)

::method conditions
  expose conditions
  copy = .array~new
  do item over conditions
    copy~append(item)
  end
  return copy

::method exceptions
  expose exceptions
  copy = .array~new
  do item over exceptions
    copy~append(item)
  end
  return copy

::method jurisdictionClaims
  expose jurisdictionClaims
  copy = .array~new
  do item over jurisdictionClaims
    copy~append(item)
  end
  return copy

::method evidence
  expose evidence
  copy = .array~new
  do item over evidence
    copy~append(item)
  end
  return copy

::method seal
  expose sealed
  sealed = .true
  return self

::method matchesAction
  expose actionCode
  use arg candidateAction
  candidateAction = candidateAction~string~upper
  if actionCode = "*" then return .true
  return actionCode = candidateAction

::method evaluate
  expose temporalScope conditions exceptions jurisdictionClaims subjectMatter
  use arg context, factSet
  reasons = .array~new
  predicateEvaluations = .array~new
  if \temporalScope~isApplicable(context~eventTime, context~evaluationTime) then do
    reasons~append("temporal scope does not apply")
    return .LegalNormMatch~new(self, "NOT_APPLICABLE", reasons, predicateEvaluations)
  end

  do requiredClaim over jurisdictionClaims
    if \context~satisfiesJurisdiction(requiredClaim) then do
      reasons~append("jurisdiction not established: " || requiredClaim~string)
      return .LegalNormMatch~new(self, "NOT_APPLICABLE", reasons, predicateEvaluations)
    end
  end

  unresolved = .false
  do predicate over conditions
    predicateResult = predicate~evaluate(factSet)
    predicateEvaluations~append(.LegalPredicateEvaluation~new(predicate, "CONDITION", predicateResult, factSet~fact(predicate~factName)))
    if predicateResult = "FALSE" then do
      reasons~append("condition false: " || predicate~render)
      return .LegalNormMatch~new(self, "NOT_APPLICABLE", reasons, predicateEvaluations)
    end
    if predicateResult = "UNKNOWN" then do
      unresolved = .true
      reasons~append("condition unresolved: " || predicate~render || " => " || predicateResult)
    end
    else if predicateResult = "CONFLICT" then do
      unresolved = .true
      reasons~append("condition unresolved: " || predicate~render || " => " || predicateResult)
    end
  end

  do predicate over exceptions
    predicateResult = predicate~evaluate(factSet)
    predicateEvaluations~append(.LegalPredicateEvaluation~new(predicate, "EXCEPTION", predicateResult, factSet~fact(predicate~factName)))
    if predicateResult = "TRUE" then do
      reasons~append("exception applies: " || predicate~render)
      return .LegalNormMatch~new(self, "EXCEPTED", reasons, predicateEvaluations)
    end
    if predicateResult = "UNKNOWN" then do
      unresolved = .true
      reasons~append("exception unresolved: " || predicate~render || " => " || predicateResult)
    end
    else if predicateResult = "CONFLICT" then do
      unresolved = .true
      reasons~append("exception unresolved: " || predicate~render || " => " || predicateResult)
    end
  end

  if unresolved then return .LegalNormMatch~new(self, "UNRESOLVED", reasons, predicateEvaluations)
  reasons~append("all applicability predicates satisfied")
  return .LegalNormMatch~new(self, "APPLIES", reasons, predicateEvaluations)

::method canonicalText
  expose normId sourceId provisionId normType actionCode disposition subjectMatter rationale temporalScope conditions exceptions jurisdictionClaims evidence materialVersion conflictKey
  text = .LegalCanonical~field("NORM_ID", normId)
  text ||= .LegalCanonical~field("SOURCE_ID", sourceId)
  text ||= .LegalCanonical~field("PROVISION_ID", provisionId)
  text ||= .LegalCanonical~field("NORM_TYPE", normType)
  text ||= .LegalCanonical~field("ACTION", actionCode)
  text ||= .LegalCanonical~field("DISPOSITION", disposition)
  text ||= .LegalCanonical~field("SUBJECT", subjectMatter)
  text ||= .LegalCanonical~field("RATIONALE", rationale)
  text ||= .LegalCanonical~field("MATERIAL_VERSION", materialVersion)
  text ||= .LegalCanonical~field("CONFLICT_KEY", conflictKey)
  text ||= .LegalCanonical~field("TEMPORAL", temporalScope~canonicalText)
  conditionText = .array~new
  do predicate over conditions
    conditionText~append(predicate~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("CONDITION", conditionText)
  exceptionText = .array~new
  do predicate over exceptions
    exceptionText~append(predicate~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("EXCEPTION", exceptionText)
  jurisdictionText = .array~new
  do claim over jurisdictionClaims
    jurisdictionText~append(claim~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("JURISDICTION", jurisdictionText)
  evidenceText = .array~new
  do anchor over evidence
    evidenceText~append(anchor~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("EVIDENCE", evidenceText)
  return text


::class LegalAuthorityMatch public
::attribute rule get
::attribute status get
::attribute winnerNorm get
::attribute loserNorm get
::attribute reasons get

::method init
  expose rule status winnerNorm loserNorm reasons predicateEvaluations
  use arg ruleArg, statusArg, winnerArg = .nil, loserArg = .nil, reasonsArg = .nil, predicateEvaluationsArg = .nil
  rule = ruleArg
  status = statusArg~string~upper
  winnerNorm = winnerArg
  loserNorm = loserArg
  if reasonsArg == .nil then reasons = .array~new
  else reasons = reasonsArg
  predicateEvaluations = .array~new
  if predicateEvaluationsArg \== .nil then do item over predicateEvaluationsArg
    predicateEvaluations~append(item)
  end

::method predicateEvaluations
  expose predicateEvaluations
  copy = .array~new
  do item over predicateEvaluations
    copy~append(item)
  end
  return copy


::class LegalAuthorityRule public
::attribute ruleId get
::attribute authoritySourceId get
::attribute authorityProvisionId get
::attribute winnerSourceId get
::attribute loserSourceId get
::attribute winnerNormId get
::attribute loserNormId get
::attribute relationType get
::attribute subjectMatter get
::attribute actionCode get
::attribute temporalScope get
::attribute rationale get
::attribute sealed get

::method init
  expose ruleId authoritySourceId authorityProvisionId winnerSourceId loserSourceId winnerNormId loserNormId relationType subjectMatter actionCode temporalScope rationale conditions exceptions jurisdictionClaims evidence sealed
  use arg ruleIdArg, authoritySourceIdArg, authorityProvisionIdArg, winnerSourceIdArg, loserSourceIdArg, relationTypeArg = "PREVAILS_OVER", subjectMatterArg = "*", actionCodeArg = "*", temporalArg = .nil, winnerNormIdArg = "*", loserNormIdArg = "*", rationaleArg = ""
  ruleId = ruleIdArg~string~upper
  authoritySourceId = authoritySourceIdArg~string
  authorityProvisionId = authorityProvisionIdArg~string
  winnerSourceId = winnerSourceIdArg~string
  loserSourceId = loserSourceIdArg~string
  winnerNormId = winnerNormIdArg~string~upper
  loserNormId = loserNormIdArg~string~upper
  relationType = relationTypeArg~string~upper
  subjectMatter = subjectMatterArg~string~upper
  actionCode = actionCodeArg~string~upper
  rationale = rationaleArg~string
  if temporalArg == .nil then temporalScope = .LegalTemporalScope~new
  else temporalScope = temporalArg
  conditions = .array~new
  exceptions = .array~new
  jurisdictionClaims = .array~new
  evidence = .array~new
  sealed = .false

::method addCondition
  expose conditions sealed
  use arg predicate
  if sealed then return .LegalResult~failure("AUTHORITY_RULE_SEALED", "Authority rule is sealed")
  conditions~append(predicate)
  return .LegalResult~success(predicate)

::method addException
  expose exceptions sealed
  use arg predicate
  if sealed then return .LegalResult~failure("AUTHORITY_RULE_SEALED", "Authority rule is sealed")
  exceptions~append(predicate)
  return .LegalResult~success(predicate)

::method addJurisdiction
  expose jurisdictionClaims sealed
  use arg claim
  if sealed then return .LegalResult~failure("AUTHORITY_RULE_SEALED", "Authority rule is sealed")
  jurisdictionClaims~append(claim)
  return .LegalResult~success(claim)

::method addEvidence
  expose evidence sealed
  use arg anchor
  if sealed then return .LegalResult~failure("AUTHORITY_RULE_SEALED", "Authority rule is sealed")
  evidence~append(anchor)
  return .LegalResult~success(anchor)

::method conditions
  expose conditions
  copy = .array~new
  do item over conditions
    copy~append(item)
  end
  return copy

::method exceptions
  expose exceptions
  copy = .array~new
  do item over exceptions
    copy~append(item)
  end
  return copy

::method jurisdictionClaims
  expose jurisdictionClaims
  copy = .array~new
  do item over jurisdictionClaims
    copy~append(item)
  end
  return copy

::method evidence
  expose evidence
  copy = .array~new
  do item over evidence
    copy~append(item)
  end
  return copy

::method seal
  expose sealed
  sealed = .true
  return self

::method selectorMatches private
  use arg norm, sourceId, normId
  if norm~sourceId <> sourceId then return .false
  if normId = "*" then return .true
  return norm~normId = normId

::method pairDirection
  expose winnerSourceId loserSourceId winnerNormId loserNormId subjectMatter actionCode
  use arg leftNorm, rightNorm
  if leftNorm == .nil then return "NO_MATCH"
  if rightNorm == .nil then return "NO_MATCH"
  if actionCode <> "*" then do
    if leftNorm~actionCode <> actionCode then return "NO_MATCH"
    if rightNorm~actionCode <> actionCode then return "NO_MATCH"
  end
  if subjectMatter <> "*" then do
    if leftNorm~subjectMatter <> subjectMatter then return "NO_MATCH"
    if rightNorm~subjectMatter <> subjectMatter then return "NO_MATCH"
  end
  if self~selectorMatches(leftNorm, winnerSourceId, winnerNormId) then do
    if self~selectorMatches(rightNorm, loserSourceId, loserNormId) then return "LEFT_WINS"
  end
  if self~selectorMatches(rightNorm, winnerSourceId, winnerNormId) then do
    if self~selectorMatches(leftNorm, loserSourceId, loserNormId) then return "RIGHT_WINS"
  end
  return "NO_MATCH"

::method evaluate
  expose temporalScope conditions exceptions jurisdictionClaims
  use arg context, factSet, leftNorm, rightNorm
  reasons = .array~new
  predicateEvaluations = .array~new
  direction = self~pairDirection(leftNorm, rightNorm)
  if direction = "NO_MATCH" then return .LegalAuthorityMatch~new(self, "NOT_APPLICABLE", .nil, .nil, reasons, predicateEvaluations)
  if \temporalScope~isApplicable(context~eventTime, context~evaluationTime) then do
    reasons~append("authority temporal scope does not apply")
    return .LegalAuthorityMatch~new(self, "NOT_APPLICABLE", .nil, .nil, reasons, predicateEvaluations)
  end
  do requiredClaim over jurisdictionClaims
    if \context~satisfiesJurisdiction(requiredClaim) then do
      reasons~append("authority jurisdiction not established: " || requiredClaim~string)
      return .LegalAuthorityMatch~new(self, "NOT_APPLICABLE", .nil, .nil, reasons, predicateEvaluations)
    end
  end
  unresolved = .false
  do predicate over conditions
    predicateState = predicate~evaluate(factSet)
    predicateEvaluations~append(.LegalPredicateEvaluation~new(predicate, "CONDITION", predicateState, factSet~fact(predicate~factName)))
    if predicateState = "FALSE" then return .LegalAuthorityMatch~new(self, "NOT_APPLICABLE", .nil, .nil, reasons, predicateEvaluations)
    if predicateState = "UNKNOWN" then do
      unresolved = .true
      reasons~append("authority condition unresolved: " || predicate~render || " => " || predicateState)
    end
    else if predicateState = "CONFLICT" then do
      unresolved = .true
      reasons~append("authority condition unresolved: " || predicate~render || " => " || predicateState)
    end
  end
  do predicate over exceptions
    predicateState = predicate~evaluate(factSet)
    predicateEvaluations~append(.LegalPredicateEvaluation~new(predicate, "EXCEPTION", predicateState, factSet~fact(predicate~factName)))
    if predicateState = "TRUE" then return .LegalAuthorityMatch~new(self, "NOT_APPLICABLE", .nil, .nil, reasons, predicateEvaluations)
    if predicateState = "UNKNOWN" then do
      unresolved = .true
      reasons~append("authority exception unresolved: " || predicate~render || " => " || predicateState)
    end
    else if predicateState = "CONFLICT" then do
      unresolved = .true
      reasons~append("authority exception unresolved: " || predicate~render || " => " || predicateState)
    end
  end
  if unresolved then return .LegalAuthorityMatch~new(self, "UNRESOLVED", .nil, .nil, reasons, predicateEvaluations)
  if direction = "LEFT_WINS" then return .LegalAuthorityMatch~new(self, "APPLIES", leftNorm, rightNorm, reasons, predicateEvaluations)
  return .LegalAuthorityMatch~new(self, "APPLIES", rightNorm, leftNorm, reasons, predicateEvaluations)

::method canonicalText
  expose ruleId authoritySourceId authorityProvisionId winnerSourceId loserSourceId winnerNormId loserNormId relationType subjectMatter actionCode temporalScope rationale conditions exceptions jurisdictionClaims evidence
  text = .LegalCanonical~field("RULE_ID", ruleId)
  text ||= .LegalCanonical~field("AUTHORITY_SOURCE", authoritySourceId)
  text ||= .LegalCanonical~field("AUTHORITY_PROVISION", authorityProvisionId)
  text ||= .LegalCanonical~field("WINNER_SOURCE", winnerSourceId)
  text ||= .LegalCanonical~field("LOSER_SOURCE", loserSourceId)
  text ||= .LegalCanonical~field("WINNER_NORM", winnerNormId)
  text ||= .LegalCanonical~field("LOSER_NORM", loserNormId)
  text ||= .LegalCanonical~field("RELATION_TYPE", relationType)
  text ||= .LegalCanonical~field("SUBJECT", subjectMatter)
  text ||= .LegalCanonical~field("ACTION", actionCode)
  text ||= .LegalCanonical~field("RATIONALE", rationale)
  text ||= .LegalCanonical~field("TEMPORAL", temporalScope~canonicalText)
  conditionText = .array~new
  do predicate over conditions
    conditionText~append(predicate~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("CONDITION", conditionText)
  exceptionText = .array~new
  do predicate over exceptions
    exceptionText~append(predicate~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("EXCEPTION", exceptionText)
  jurisdictionText = .array~new
  do claim over jurisdictionClaims
    jurisdictionText~append(claim~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("JURISDICTION", jurisdictionText)
  evidenceText = .array~new
  do anchor over evidence
    evidenceText~append(anchor~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("EVIDENCE", evidenceText)
  return text


::class LegalNormConflictResult public
::attribute conflictKey get
::attribute leftMatch get
::attribute rightMatch get
::attribute status get
::attribute winnerMatch get
::attribute loserMatch get
::attribute authorityMatch get
::attribute reasons get

::method init
  expose conflictKey leftMatch rightMatch status winnerMatch loserMatch authorityMatch reasons
  use arg conflictKeyArg, leftArg, rightArg, statusArg, winnerArg = .nil, loserArg = .nil, authorityArg = .nil, reasonsArg = .nil
  conflictKey = conflictKeyArg~string~upper
  leftMatch = leftArg
  rightMatch = rightArg
  status = statusArg~string~upper
  winnerMatch = winnerArg
  loserMatch = loserArg
  authorityMatch = authorityArg
  if reasonsArg == .nil then reasons = .array~new
  else reasons = reasonsArg


::class LegalRuleGeneration public
::attribute generationId get
::attribute version get
::attribute createdAt get
::attribute sealed get
::attribute compilationCertificate get

::method init
  expose generationId version createdAt sealed sources provisions modifications norms authorityRules compilationCertificate
  use arg generationIdArg, versionArg
  generationId = generationIdArg~string
  version = versionArg~string
  createdAt = .DateTime~new~utcIsoDate
  sealed = .false
  sources = .table~new
  provisions = .table~new
  modifications = .array~new
  norms = .array~new
  authorityRules = .array~new
  compilationCertificate = .nil

::method certifyCompilation
  expose sealed compilationCertificate
  use arg certificate, authorityToken = .nil
  if sealed then return .LegalResult~failure("GENERATION_SEALED", "Generation is already sealed")
  if authorityToken \== .LegalCompilationAuthority then return .LegalResult~failure("COMPILATION_AUTHORITY_REQUIRED", "Only LegalRuleCompiler may certify a generation")
  if certificate == .nil then return .LegalResult~failure("COMPILATION_CERTIFICATE_REQUIRED", "Certificate must not be .nil")
  compilationCertificate = certificate
  return .LegalResult~success(certificate)

::method publicationEligible
  expose sealed compilationCertificate
  if \sealed then return .false
  return compilationCertificate \== .nil

::method sourceAuthorityAttestationsPresent
  expose sealed compilationCertificate sources
  if \sealed then return .false
  if compilationCertificate == .nil then return .false
  if sources~items = 0 then return .false
  do sourceId over sources
    identity = sources[sourceId]~sourceIdentity
    if identity == .nil then return .false
    if identity~authorityAttestationCount < 1 then return .false
  end
  return .true

::method addSource
  expose sealed sources
  use arg source
  if sealed then return .LegalResult~failure("GENERATION_SEALED", "Generation is sealed")
  if source == .nil then return .LegalResult~failure("INVALID_SOURCE", "Source must not be .nil")
  if sources~hasIndex(source~sourceId) then return .LegalResult~failure("DUPLICATE_SOURCE", source~sourceId)
  sources[source~sourceId] = source
  return .LegalResult~success(source)

::method addProvision
  expose sealed sources provisions
  use arg provision
  if sealed then return .LegalResult~failure("GENERATION_SEALED", "Generation is sealed")
  if provision == .nil then return .LegalResult~failure("INVALID_PROVISION", "Provision must not be .nil")
  if \sources~hasIndex(provision~sourceId) then return .LegalResult~failure("PROVISION_SOURCE_MISSING", provision~sourceId)
  key = self~provisionKey(provision~sourceId, provision~provisionId)
  if provisions~hasIndex(key) then return .LegalResult~failure("DUPLICATE_PROVISION", key)
  provisions[key] = provision
  return .LegalResult~success(provision)

::method addModification
  expose sealed sources provisions modifications
  use arg effect
  if sealed then return .LegalResult~failure("GENERATION_SEALED", "Generation is sealed")
  if effect == .nil then return .LegalResult~failure("INVALID_MODIFICATION", "Modification must not be .nil")
  if \sources~hasIndex(effect~sourceId) then return .LegalResult~failure("MODIFICATION_SOURCE_MISSING", effect~sourceId)
  targetKey = self~provisionKey(effect~targetSourceId, effect~targetProvisionId)
  if \provisions~hasIndex(targetKey) then return .LegalResult~failure("MODIFICATION_TARGET_MISSING", targetKey)
  do existing over modifications
    if existing~effectId = effect~effectId then return .LegalResult~failure("DUPLICATE_MODIFICATION", effect~effectId)
  end
  modifications~append(effect)
  return .LegalResult~success(effect)

::method addNorm
  expose sealed norms sources
  use arg norm
  if sealed then return .LegalResult~failure("GENERATION_SEALED", "Generation is sealed")
  if norm == .nil then return .LegalResult~failure("INVALID_NORM", "Norm must not be .nil")
  if \sources~hasIndex(norm~sourceId) then return .LegalResult~failure("NORM_SOURCE_MISSING", norm~sourceId)
  norms~append(norm)
  return .LegalResult~success(norm)

::method addAuthorityRule
  expose sealed sources authorityRules
  use arg rule
  if sealed then return .LegalResult~failure("GENERATION_SEALED", "Generation is sealed")
  if rule == .nil then return .LegalResult~failure("INVALID_AUTHORITY_RULE", "Authority rule must not be .nil")
  if \sources~hasIndex(rule~authoritySourceId) then return .LegalResult~failure("AUTHORITY_SOURCE_MISSING", rule~authoritySourceId)
  if \sources~hasIndex(rule~winnerSourceId) then return .LegalResult~failure("AUTHORITY_WINNER_SOURCE_MISSING", rule~winnerSourceId)
  if \sources~hasIndex(rule~loserSourceId) then return .LegalResult~failure("AUTHORITY_LOSER_SOURCE_MISSING", rule~loserSourceId)
  do existing over authorityRules
    if existing~ruleId = rule~ruleId then return .LegalResult~failure("DUPLICATE_AUTHORITY_RULE", rule~ruleId)
  end
  authorityRules~append(rule)
  return .LegalResult~success(rule)

::method authorityRules
  expose authorityRules
  copy = .array~new
  do rule over authorityRules
    copy~append(rule)
  end
  return copy

::method source
  expose sources
  use arg sourceId
  return sources[sourceId~string]

::method provision
  expose provisions
  use arg sourceId, provisionId
  key = self~provisionKey(sourceId, provisionId)
  return provisions[key]

::method sources
  expose sources
  copy = .table~new
  do key over sources
    copy[key] = sources[key]
  end
  return copy

::method provisions
  expose provisions
  copy = .array~new
  do key over provisions
    copy~append(provisions[key])
  end
  return copy

::method modifications
  expose modifications
  copy = .array~new
  do effect over modifications
    copy~append(effect)
  end
  return copy

::method norms
  expose norms
  copy = .array~new
  do norm over norms
    copy~append(norm)
  end
  return copy

::method seal
  expose sealed sources provisions modifications norms authorityRules
  if sealed then return self
  do key over sources
    sourceObject = sources[key]
    if sourceObject~hasMethod("SEAL") then ignored = sourceObject~seal
  end
  do key over provisions
    ignored = provisions[key]~seal
  end
  do effect over modifications
    ignored = effect~seal
  end
  do norm over norms
    ignored = norm~seal
  end
  do rule over authorityRules
    ignored = rule~seal
  end
  sealed = .true
  return self


::method canonicalText
  expose generationId version sealed sources provisions modifications norms authorityRules
  if \sealed then raise syntax 88.900 array("LegalRuleGeneration canonicalText requires a sealed generation")
  text = "LEGAL-EFFECT-SEMANTIC/1"
  text ||= .LegalCanonical~field("GENERATION_ID", generationId)
  text ||= .LegalCanonical~field("VERSION", version)
  sourceText = .array~new
  do key over sources
    sourceText~append(sources[key]~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("SOURCE", sourceText)
  provisionText = .array~new
  do key over provisions
    provisionText~append(provisions[key]~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("PROVISION", provisionText)
  modificationText = .array~new
  do effect over modifications
    modificationText~append(effect~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("MODIFICATION", modificationText)
  normText = .array~new
  do norm over norms
    normText~append(norm~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("NORM", normText)
  authorityText = .array~new
  do rule over authorityRules
    authorityText~append(rule~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("AUTHORITY_RULE", authorityText)
  return text

::method semanticIdentity
  return self~canonicalText


::method normCount
  expose norms
  return norms~items

::method sourceCount
  expose sources
  return sources~items

::method provisionCount
  expose provisions
  return provisions~items

::method modificationCount
  expose modifications
  return modifications~items

::method authorityRuleCount
  expose authorityRules
  return authorityRules~items

::method provisionKey private
  use arg sourceId, provisionId
  return sourceId~string || "::" || provisionId~string


::class LegalJurisdictionNode public
::attribute jurisdictionId get
::attribute authorityId get
::attribute territoryId get
::attribute parentId get

::method init
  expose jurisdictionId authorityId territoryId parentId
  use arg jurisdictionArg, authorityArg, territoryArg, parentArg = ""
  jurisdictionId = jurisdictionArg~string~upper
  authorityId = authorityArg~string~upper
  territoryId = territoryArg~string~upper
  parentId = parentArg~string~upper


::class LegalJurisdictionGraph public
::method init
  expose nodes
  nodes = .table~new

::method addNode
  expose nodes
  use arg jurisdictionId, authorityId, territoryId, parentId = ""
  node = .LegalJurisdictionNode~new(jurisdictionId, authorityId, territoryId, parentId)
  nodes[node~jurisdictionId] = node
  return node

::method node
  expose nodes
  use arg jurisdictionId
  return nodes[jurisdictionId~string~upper]

::method satisfies
  expose nodes
  use arg placeJurisdictionId, requiredClaim
  currentId = placeJurisdictionId~string~upper
  visited = .table~new
  do while currentId <> ""
    if visited~hasIndex(currentId) then return .false
    visited[currentId] = .true
    if \nodes~hasIndex(currentId) then return .false
    nodeObject = nodes[currentId]
    if requiredClaim~matches(nodeObject~authorityId, nodeObject~territoryId, requiredClaim~subjectMatter) then return .true
    currentId = nodeObject~parentId
  end
  return .false

::method ancestry
  expose nodes
  use arg placeJurisdictionId
  ancestryItems = .array~new
  currentId = placeJurisdictionId~string~upper
  visited = .table~new
  do while currentId <> ""
    if visited~hasIndex(currentId) then leave
    visited[currentId] = .true
    if \nodes~hasIndex(currentId) then leave
    nodeObject = nodes[currentId]
    ancestryItems~append(nodeObject)
    currentId = nodeObject~parentId
  end
  return ancestryItems


::class LegalContext public
::attribute eventId get
::attribute eventTime get
::attribute evaluationTime get
::attribute facts get
::attribute jurisdictionClaims get
::attribute metadata get
::attribute sourceBindings get
::attribute jurisdictionGraph get
::attribute placeJurisdictionId get

::method init
  expose eventId eventTime evaluationTime facts jurisdictionClaims metadata sourceBindings jurisdictionGraph placeJurisdictionId
  use arg eventIdArg, eventTimeArg, evaluationTimeArg = "", factsArg = .nil
  eventId = eventIdArg~string
  eventTime = eventTimeArg~string
  if evaluationTimeArg~string = "" then evaluationTime = eventTime
  else evaluationTime = evaluationTimeArg~string
  if factsArg == .nil then facts = .LegalFactSet~new
  else facts = factsArg
  jurisdictionClaims = .array~new
  metadata = .table~new
  sourceBindings = .table~new
  jurisdictionGraph = .nil
  placeJurisdictionId = ""

::method addJurisdiction
  expose jurisdictionClaims
  use arg claim
  jurisdictionClaims~append(claim)
  return claim

::method useJurisdictionGraph
  expose jurisdictionGraph placeJurisdictionId
  use arg graph, placeId
  jurisdictionGraph = graph
  placeJurisdictionId = placeId~string~upper
  return self

::method bindSource
  expose sourceBindings
  use arg sourceId, basis = "explicit legal-context binding"
  sourceBindings[sourceId~string] = basis~string
  return self

::method isSourceBound
  expose sourceBindings
  use arg sourceId
  return sourceBindings~hasIndex(sourceId~string)

::method sourceBindingBasis
  expose sourceBindings
  use arg sourceId
  return sourceBindings[sourceId~string]

::method satisfiesJurisdiction
  expose jurisdictionClaims jurisdictionGraph placeJurisdictionId
  use arg requiredClaim
  do actualClaim over jurisdictionClaims
    if actualClaim~matches(requiredClaim~authorityId, requiredClaim~territoryId, requiredClaim~subjectMatter) then return .true
  end
  if jurisdictionGraph \== .nil then do
    if placeJurisdictionId <> "" then do
      if jurisdictionGraph~satisfies(placeJurisdictionId, requiredClaim) then return .true
    end
  end
  return .false

::method clone
  expose eventId eventTime evaluationTime facts jurisdictionClaims metadata sourceBindings jurisdictionGraph placeJurisdictionId
  copy = .LegalContext~new(eventId, eventTime, evaluationTime, facts~clone)
  do claim over jurisdictionClaims
    ignored = copy~addJurisdiction(claim)
  end
  do key over metadata
    copy~metadata[key] = metadata[key]
  end
  do sourceId over sourceBindings
    ignored = copy~bindSource(sourceId, sourceBindings[sourceId])
  end
  if jurisdictionGraph \== .nil then ignored = copy~useJurisdictionGraph(jurisdictionGraph, placeJurisdictionId)
  return copy


::class LegalProvision public
::attribute sourceId get
::attribute provisionId get
::attribute initialStatus get
::attribute materialVersion get
::attribute lexicalText get
::attribute sealed get
::attribute provisionReference get

::method init
  expose sourceId provisionId initialStatus materialVersion lexicalText evidence sealed provisionReference
  use arg sourceIdArg, provisionIdArg, initialStatusArg = "ACTIVE", materialVersionArg = "BASE", lexicalTextArg = ""
  sourceId = sourceIdArg~string
  provisionId = provisionIdArg~string
  initialStatus = initialStatusArg~string~upper
  materialVersion = materialVersionArg~string~upper
  lexicalText = lexicalTextArg~string
  evidence = .array~new
  sealed = .false
  provisionReference = .nil

::method bindProvisionReference
  expose sourceId provisionId sealed provisionReference
  use arg reference
  if sealed then return .LegalResult~failure("PROVISION_SEALED", "Provision is sealed")
  if reference == .nil then return .LegalResult~failure("PROVISION_REFERENCE_REQUIRED", provisionId)
  if reference~sourceId <> sourceId then return .LegalResult~failure("PROVISION_SOURCE_MISMATCH", reference~sourceId || " != " || sourceId)
  if reference~provisionId <> provisionId then return .LegalResult~failure("PROVISION_ID_MISMATCH", reference~provisionId || " != " || provisionId)
  provisionReference = reference
  return .LegalResult~success(reference)

::method addEvidence
  expose evidence sealed
  use arg anchor
  if sealed then return .LegalResult~failure("PROVISION_SEALED", "Provision is sealed")
  evidence~append(anchor)
  return .LegalResult~success(anchor)

::method evidence
  expose evidence
  copy = .array~new
  do item over evidence
    copy~append(item)
  end
  return copy

::method seal
  expose sealed
  sealed = .true
  return self


::method canonicalText
  expose sourceId provisionId initialStatus materialVersion lexicalText evidence provisionReference
  text = .LegalCanonical~field("SOURCE_ID", sourceId)
  text ||= .LegalCanonical~field("PROVISION_ID", provisionId)
  text ||= .LegalCanonical~field("INITIAL_STATUS", initialStatus)
  text ||= .LegalCanonical~field("MATERIAL_VERSION", materialVersion)
  text ||= .LegalCanonical~field("LEXICAL_TEXT", lexicalText)
  if provisionReference == .nil then referenceText = "NONE"
  else referenceText = provisionReference~canonicalText
  text ||= .LegalCanonical~field("PROVISION_REFERENCE", referenceText)
  evidenceText = .array~new
  do anchor over evidence
    evidenceText~append(anchor~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("EVIDENCE", evidenceText)
  return text


::class LegalModificationMatch public
::attribute effect get
::attribute status get
::attribute reasons get

::method init
  expose effect status reasons predicateEvaluations
  use arg effectArg, statusArg, reasonsArg = .nil, predicateEvaluationsArg = .nil
  effect = effectArg
  status = statusArg~string~upper
  if reasonsArg == .nil then reasons = .array~new
  else reasons = reasonsArg
  predicateEvaluations = .array~new
  if predicateEvaluationsArg \== .nil then do item over predicateEvaluationsArg
    predicateEvaluations~append(item)
  end

::method predicateEvaluations
  expose predicateEvaluations
  copy = .array~new
  do item over predicateEvaluations
    copy~append(item)
  end
  return copy


::class LegalModificationEffect public
::attribute effectId get
::attribute sourceId get
::attribute sourceProvisionId get
::attribute effectType get
::attribute targetSourceId get
::attribute targetProvisionId get
::attribute temporalScope get
::attribute applicationOrder get
::attribute resultingVersion get
::attribute replacementText get
::attribute sealed get

::method init
  expose effectId sourceId sourceProvisionId effectType targetSourceId targetProvisionId temporalScope applicationOrder resultingVersion replacementText conditions exceptions jurisdictionClaims evidence sealed
  use arg effectIdArg, sourceIdArg, sourceProvisionIdArg, effectTypeArg, targetSourceArg, targetProvisionArg, temporalArg = .nil, orderArg = 1000, resultingVersionArg = "", replacementTextArg = ""
  effectId = effectIdArg~string~upper
  sourceId = sourceIdArg~string
  sourceProvisionId = sourceProvisionIdArg~string
  effectType = effectTypeArg~string~upper
  targetSourceId = targetSourceArg~string
  targetProvisionId = targetProvisionArg~string
  if temporalArg == .nil then temporalScope = .LegalTemporalScope~new
  else temporalScope = temporalArg
  applicationOrder = orderArg
  resultingVersion = resultingVersionArg~string~upper
  replacementText = replacementTextArg~string
  conditions = .array~new
  exceptions = .array~new
  jurisdictionClaims = .array~new
  evidence = .array~new
  sealed = .false

::method addCondition
  expose conditions sealed
  use arg predicate
  if sealed then return .LegalResult~failure("MODIFICATION_SEALED", "Modification is sealed")
  conditions~append(predicate)
  return .LegalResult~success(predicate)

::method addException
  expose exceptions sealed
  use arg predicate
  if sealed then return .LegalResult~failure("MODIFICATION_SEALED", "Modification is sealed")
  exceptions~append(predicate)
  return .LegalResult~success(predicate)

::method addJurisdiction
  expose jurisdictionClaims sealed
  use arg claim
  if sealed then return .LegalResult~failure("MODIFICATION_SEALED", "Modification is sealed")
  jurisdictionClaims~append(claim)
  return .LegalResult~success(claim)

::method addEvidence
  expose evidence sealed
  use arg anchor
  if sealed then return .LegalResult~failure("MODIFICATION_SEALED", "Modification is sealed")
  evidence~append(anchor)
  return .LegalResult~success(anchor)

::method conditions
  expose conditions
  copy = .array~new
  do item over conditions
    copy~append(item)
  end
  return copy

::method exceptions
  expose exceptions
  copy = .array~new
  do item over exceptions
    copy~append(item)
  end
  return copy

::method jurisdictionClaims
  expose jurisdictionClaims
  copy = .array~new
  do item over jurisdictionClaims
    copy~append(item)
  end
  return copy

::method evidence
  expose evidence
  copy = .array~new
  do item over evidence
    copy~append(item)
  end
  return copy

::method seal
  expose sealed
  sealed = .true
  return self

::method evaluate
  expose temporalScope conditions exceptions jurisdictionClaims
  use arg context
  reasons = .array~new
  predicateEvaluations = .array~new
  if \temporalScope~isApplicable(context~eventTime, context~evaluationTime) then do
    reasons~append("modification temporal scope does not apply")
    return .LegalModificationMatch~new(self, "NOT_APPLICABLE", reasons, predicateEvaluations)
  end
  do requiredClaim over jurisdictionClaims
    if \context~satisfiesJurisdiction(requiredClaim) then do
      reasons~append("modification jurisdiction not established: " || requiredClaim~string)
      return .LegalModificationMatch~new(self, "NOT_APPLICABLE", reasons, predicateEvaluations)
    end
  end
  unresolved = .false
  do predicate over conditions
    predicateResult = predicate~evaluate(context~facts)
    predicateEvaluations~append(.LegalPredicateEvaluation~new(predicate, "CONDITION", predicateResult, context~facts~fact(predicate~factName)))
    if predicateResult = "FALSE" then do
      reasons~append("modification condition false: " || predicate~render)
      return .LegalModificationMatch~new(self, "NOT_APPLICABLE", reasons, predicateEvaluations)
    end
    if predicateResult = "UNKNOWN" then do
      unresolved = .true
      reasons~append("modification condition unresolved: " || predicate~render || " => " || predicateResult)
    end
    else if predicateResult = "CONFLICT" then do
      unresolved = .true
      reasons~append("modification condition unresolved: " || predicate~render || " => " || predicateResult)
    end
  end
  do predicate over exceptions
    predicateResult = predicate~evaluate(context~facts)
    predicateEvaluations~append(.LegalPredicateEvaluation~new(predicate, "EXCEPTION", predicateResult, context~facts~fact(predicate~factName)))
    if predicateResult = "TRUE" then do
      reasons~append("modification exception applies: " || predicate~render)
      return .LegalModificationMatch~new(self, "NOT_APPLICABLE", reasons, predicateEvaluations)
    end
    if predicateResult = "UNKNOWN" then do
      unresolved = .true
      reasons~append("modification exception unresolved: " || predicate~render || " => " || predicateResult)
    end
    else if predicateResult = "CONFLICT" then do
      unresolved = .true
      reasons~append("modification exception unresolved: " || predicate~render || " => " || predicateResult)
    end
  end
  if unresolved then return .LegalModificationMatch~new(self, "UNRESOLVED", reasons, predicateEvaluations)
  reasons~append("modification applies")
  return .LegalModificationMatch~new(self, "APPLIES", reasons, predicateEvaluations)

::method canonicalText
  expose effectId sourceId sourceProvisionId effectType targetSourceId targetProvisionId temporalScope applicationOrder resultingVersion replacementText conditions exceptions jurisdictionClaims evidence
  text = .LegalCanonical~field("EFFECT_ID", effectId)
  text ||= .LegalCanonical~field("SOURCE_ID", sourceId)
  text ||= .LegalCanonical~field("SOURCE_PROVISION", sourceProvisionId)
  text ||= .LegalCanonical~field("EFFECT_TYPE", effectType)
  text ||= .LegalCanonical~field("TARGET_SOURCE", targetSourceId)
  text ||= .LegalCanonical~field("TARGET_PROVISION", targetProvisionId)
  text ||= .LegalCanonical~field("TEMPORAL", temporalScope~canonicalText)
  text ||= .LegalCanonical~field("APPLICATION_ORDER", applicationOrder)
  text ||= .LegalCanonical~field("RESULTING_VERSION", resultingVersion)
  text ||= .LegalCanonical~field("REPLACEMENT_TEXT", replacementText)
  conditionText = .array~new
  do predicate over conditions
    conditionText~append(predicate~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("CONDITION", conditionText)
  exceptionText = .array~new
  do predicate over exceptions
    exceptionText~append(predicate~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("EXCEPTION", exceptionText)
  jurisdictionText = .array~new
  do claim over jurisdictionClaims
    jurisdictionText~append(claim~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("JURISDICTION", jurisdictionText)
  evidenceText = .array~new
  do anchor over evidence
    evidenceText~append(anchor~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("EVIDENCE", evidenceText)
  return text


::class LegalProvisionSnapshot public
::attribute provision get
::attribute status get
::attribute materialVersion get
::attribute lexicalText get

::method init
  expose provision status materialVersion lexicalText lineage
  use arg provisionArg
  provision = provisionArg
  status = provisionArg~initialStatus
  materialVersion = provisionArg~materialVersion
  lexicalText = provisionArg~lexicalText
  lineage = .array~new

::method applyModification
  expose status materialVersion lexicalText lineage
  use arg effect
  effectType = effect~effectType
  select
    when effectType = "COMMENCE" then status = "ACTIVE"
    when effectType = "INSERT" then do
      status = "ACTIVE"
      if effect~resultingVersion <> "" then materialVersion = effect~resultingVersion
      if effect~replacementText <> "" then lexicalText = effect~replacementText
    end
    when effectType = "SUBSTITUTE" then do
      status = "ACTIVE"
      if effect~resultingVersion <> "" then materialVersion = effect~resultingVersion
      if effect~replacementText <> "" then lexicalText = effect~replacementText
    end
    when effectType = "MODIFY" then do
      status = "ACTIVE"
      if effect~resultingVersion <> "" then materialVersion = effect~resultingVersion
      if effect~replacementText <> "" then lexicalText = effect~replacementText
    end
    when effectType = "OMIT" then status = "OMITTED"
    when effectType = "REPEAL" then status = "REPEALED"
    when effectType = "REVOKE" then status = "REVOKED"
    when effectType = "EXPIRE" then status = "EXPIRED"
    when effectType = "SAVE" then status = "SAVED_ACTIVE"
    when effectType = "TRANSITION" then do
      status = "TRANSITIONAL_ACTIVE"
      if effect~resultingVersion <> "" then materialVersion = effect~resultingVersion
      if effect~replacementText <> "" then lexicalText = effect~replacementText
    end
    otherwise return .LegalResult~failure("UNSUPPORTED_MODIFICATION_TYPE", effectType)
  end
  lineage~append(effect)
  return .LegalResult~success(self)

::method isEffective
  expose status
  if status = "ACTIVE" then return .true
  if status = "SAVED_ACTIVE" then return .true
  if status = "TRANSITIONAL_ACTIVE" then return .true
  return .false

::method lineage
  expose lineage
  copy = .array~new
  do item over lineage
    copy~append(item)
  end
  return copy


::class LegalFrameworkSnapshot public
::attribute generation get
::attribute context get
::attribute appliedModifications get
::attribute unresolvedModifications get
::attribute trace get

::method init
  expose generation context provisionStates appliedModifications unresolvedModifications trace
  use arg generationArg, contextArg
  generation = generationArg
  context = contextArg
  provisionStates = .table~new
  appliedModifications = .array~new
  unresolvedModifications = .array~new
  trace = .array~new

::method putProvisionState
  expose provisionStates
  use arg state
  provisionStates[self~key(state~provision~sourceId, state~provision~provisionId)] = state
  return state

::method provisionState
  expose provisionStates
  use arg sourceId, provisionId
  return provisionStates[self~key(sourceId, provisionId)]

::method markApplied
  expose appliedModifications
  use arg match
  appliedModifications~append(match)
  return self

::method markUnresolved
  expose unresolvedModifications
  use arg match
  unresolvedModifications~append(match)
  return self

::method addTrace
  expose trace
  use arg line
  trace~append(line~string)
  return self

::method normEligibility
  use arg norm
  state = self~provisionState(norm~sourceId, norm~provisionId)
  if state == .nil then return "ENABLED"
  if \state~isEffective then return "DISABLED"
  if norm~materialVersion = "*" then return "ENABLED"
  if state~materialVersion = norm~materialVersion then return "ENABLED"
  return "DISABLED"

::method hasUnresolvedForNorm
  expose unresolvedModifications
  use arg norm
  do match over unresolvedModifications
    effect = match~effect
    if effect~targetSourceId = norm~sourceId then do
      if effect~targetProvisionId = norm~provisionId then return .true
    end
  end
  return .false

::method key private
  use arg sourceId, provisionId
  return sourceId~string || "::" || provisionId~string


::class LegalFrameworkResolver subclass LegalAlchemyObject public

::method resolve
  use arg generation, context
  self~alchemyTouch("RESOLVE")
  if generation == .nil then return .LegalResult~failure("INVALID_GENERATION", "Generation must not be .nil")
  if \generation~sealed then return .LegalResult~failure("GENERATION_NOT_SEALED", "Only sealed legal rule generations may resolve")
  if context == .nil then return .LegalResult~failure("INVALID_CONTEXT", "Context must not be .nil")

  snapshot = .LegalFrameworkSnapshot~new(generation, context)
  do provision over generation~provisions
    ignored = snapshot~putProvisionState(.LegalProvisionSnapshot~new(provision))
  end

  effects = self~sortedEffects(generation~modifications)
  orderResult = self~validateEffectOrder(effects)
  if \orderResult~ok then return orderResult
  do effect over effects
    sourceObject = generation~source(effect~sourceId)
    if sourceObject == .nil then return .LegalResult~failure("MODIFICATION_SOURCE_MISSING", effect~sourceId)
    if sourceObject~applicabilityMode = "EXPLICIT" then do
      if \context~isSourceBound(sourceObject~sourceId) then do
        snapshot~addTrace("skipped unbound explicit modification source=" || sourceObject~sourceId || " effect=" || effect~effectId)
        iterate
      end
    end
    match = effect~evaluate(context)
    if match~status = "UNRESOLVED" then do
      snapshot~markUnresolved(match)
      snapshot~addTrace("unresolved modification=" || effect~effectId)
      iterate
    end
    if match~status <> "APPLIES" then iterate
    targetState = snapshot~provisionState(effect~targetSourceId, effect~targetProvisionId)
    if targetState == .nil then return .LegalResult~failure("MODIFICATION_TARGET_MISSING", effect~targetSourceId || "::" || effect~targetProvisionId)
    applyResult = targetState~applyModification(effect)
    if \applyResult~ok then return applyResult
    snapshot~markApplied(match)
    snapshot~addTrace("applied modification=" || effect~effectId || " type=" || effect~effectType)
  end
  return .LegalResult~success(snapshot)

::method validateEffectOrder private
  use arg effects
  seen = .table~new
  do effect over effects
    key = effect~targetSourceId || "::" || effect~targetProvisionId || "::" || effect~temporalScope~effectiveDate || "::" || effect~applicationOrder~string
    if seen~hasIndex(key) then do
      return .LegalResult~failure("AMBIGUOUS_MODIFICATION_ORDER", seen[key]~effectId || " and " || effect~effectId || " share target/date/order")
    end
    seen[key] = effect
  end
  return .LegalResult~success

::method sortedEffects private
  use arg sourceEffects
  sortedItems = .array~new
  do effect over sourceEffects
    placed = .false
    nextItems = .array~new
    do existing over sortedItems
      if \placed then do
        if self~comesBefore(effect, existing) then do
          nextItems~append(effect)
          placed = .true
        end
      end
      nextItems~append(existing)
    end
    if \placed then nextItems~append(effect)
    sortedItems = nextItems
  end
  return sortedItems

::method comesBefore private
  use arg left, right
  leftDate = left~temporalScope~effectiveDate
  rightDate = right~temporalScope~effectiveDate
  if leftDate < rightDate then return .true
  if leftDate > rightDate then return .false
  if left~applicationOrder < right~applicationOrder then return .true
  if left~applicationOrder > right~applicationOrder then return .false
  return left~effectId < right~effectId


::class LegalFactMutation public
::attribute factName get
::attribute state get
::attribute value get
::attribute source get
::attribute authority get

::method init
  expose factName state value source authority
  use arg factNameArg, valueArg = .nil, stateArg = "KNOWN", sourceArg = .nil, authorityArg = "PROPOSED_ACTION"
  factName = factNameArg~string~upper
  state = stateArg~string~upper
  value = valueArg
  source = sourceArg
  authority = authorityArg~string

::method apply
  expose factName state value source authority
  use arg factSet
  select
    when state = "KNOWN" then return factSet~putKnown(factName, value, source, authority)
    when state = "CONFLICT" then return factSet~putConflict(factName, source, authority)
    otherwise return factSet~putUnknown(factName, source, authority)
  end


::class LegalAction public
::attribute actionCode get
::attribute description get
::attribute mutations get

::method init
  expose actionCode description mutations
  use arg actionCodeArg, descriptionArg = ""
  actionCode = actionCodeArg~string~upper
  description = descriptionArg~string
  mutations = .array~new

::method addMutation
  expose mutations
  use arg mutation
  mutations~append(mutation)
  return self

::method setFact
  use arg name, value, source = .nil
  return self~addMutation(.LegalFactMutation~new(name, value, "KNOWN", source, "PROPOSED_ACTION"))

::method simulate
  expose mutations
  use arg context
  prospective = context~clone
  do mutation over mutations
    ignored = mutation~apply(prospective~facts)
  end
  return prospective


::class LegalDecisionTraceNode public
::attribute nodeId get
::attribute nodeType get
::attribute phase get
::attribute status get
::attribute subjectId get
::attribute sourceId get
::attribute provisionId get
::attribute detail get

::method init
  expose nodeId nodeType phase status subjectId sourceId provisionId detail attributes evidence reasons
  use arg nodeIdArg, nodeTypeArg, phaseArg = "", statusArg = "", subjectIdArg = "", sourceIdArg = "", provisionIdArg = "", detailArg = "", attributesArg = .nil, evidenceArg = .nil, reasonsArg = .nil
  nodeId = nodeIdArg~string~upper
  nodeType = nodeTypeArg~string~upper
  phase = phaseArg~string~upper
  status = statusArg~string~upper
  subjectId = subjectIdArg~string
  sourceId = sourceIdArg~string
  provisionId = provisionIdArg~string
  detail = detailArg~string
  attributes = .table~new
  if attributesArg \== .nil then do key over attributesArg
    attributes[key~string~upper] = attributesArg[key]
  end
  evidence = .array~new
  if evidenceArg \== .nil then do item over evidenceArg
    evidence~append(item)
  end
  reasons = .array~new
  if reasonsArg \== .nil then do item over reasonsArg
    reasons~append(item~string)
  end

::method attributes
  expose attributes
  copy = .table~new
  do key over attributes
    copy[key] = attributes[key]
  end
  return copy

::method evidence
  expose evidence
  copy = .array~new
  do item over evidence
    copy~append(item)
  end
  return copy

::method reasons
  expose reasons
  copy = .array~new
  do item over reasons
    copy~append(item)
  end
  return copy

::method canonicalText
  expose nodeId nodeType phase status subjectId sourceId provisionId detail attributes evidence reasons
  text = .LegalCanonical~field("NODE_ID", nodeId)
  text ||= .LegalCanonical~field("NODE_TYPE", nodeType)
  text ||= .LegalCanonical~field("PHASE", phase)
  text ||= .LegalCanonical~field("STATUS", status)
  text ||= .LegalCanonical~field("SUBJECT_ID", subjectId)
  text ||= .LegalCanonical~field("SOURCE_ID", sourceId)
  text ||= .LegalCanonical~field("PROVISION_ID", provisionId)
  text ||= .LegalCanonical~field("DETAIL", detail)
  attributeText = .array~new
  do key over attributes
    attributeText~append(.LegalCanonical~field("K", key) || .LegalCanonical~field("V", .LegalCanonical~scalar(attributes[key])))
  end
  text ||= .LegalCanonical~joinCanonical("ATTRIBUTE", attributeText)
  evidenceText = .array~new
  do item over evidence
    if item == .nil then itemText = "NONE"
    else if item~hasMethod("CANONICALTEXT") then itemText = item~canonicalText
    else itemText = .LegalCanonical~objectIdentity(item)
    evidenceText~append(itemText)
  end
  text ||= .LegalCanonical~joinCanonical("EVIDENCE", evidenceText)
  text ||= .LegalCanonical~joinCanonical("REASON", reasons)
  return text


::class LegalDecisionTraceEdge public
::attribute fromId get
::attribute relationType get
::attribute toId get
::attribute detail get

::method init
  expose fromId relationType toId detail
  use arg fromArg, relationArg, toArg, detailArg = ""
  fromId = fromArg~string~upper
  relationType = relationArg~string~upper
  toId = toArg~string~upper
  detail = detailArg~string

::method canonicalText
  expose fromId relationType toId detail
  text = .LegalCanonical~field("FROM", fromId)
  text ||= .LegalCanonical~field("RELATION", relationType)
  text ||= .LegalCanonical~field("TO", toId)
  text ||= .LegalCanonical~field("DETAIL", detail)
  return text


::class LegalDecisionTrace public
::attribute actionCode get
::attribute generationId get
::attribute generationSemanticIdentity get
::attribute eventId get
::attribute eventTime get
::attribute evaluationTime get
::attribute status get
::attribute sealed get

::method init
  expose actionCode generationId generationSemanticIdentity eventId eventTime evaluationTime status dispositions nodes nodeIndex edges edgeIndex sealed
  use arg actionCodeArg, generationIdArg, generationSemanticIdentityArg, eventIdArg, eventTimeArg, evaluationTimeArg, statusArg, dispositionsArg = .nil
  actionCode = actionCodeArg~string~upper
  generationId = generationIdArg~string
  generationSemanticIdentity = generationSemanticIdentityArg~string
  eventId = eventIdArg~string
  eventTime = eventTimeArg~string
  evaluationTime = evaluationTimeArg~string
  status = statusArg~string~upper
  dispositions = .array~new
  if dispositionsArg \== .nil then do item over dispositionsArg
    dispositions~append(item~string~upper)
  end
  nodes = .array~new
  nodeIndex = .table~new
  edges = .array~new
  edgeIndex = .table~new
  sealed = .false

::method addNode
  expose nodes nodeIndex sealed
  use arg node
  if sealed then return .LegalResult~failure("DECISION_TRACE_SEALED", "Decision trace is sealed")
  if node == .nil then return .LegalResult~failure("DECISION_TRACE_NODE_REQUIRED", "Node must not be .nil")
  id = node~nodeId
  if nodeIndex~hasIndex(id) then do
    existing = nodeIndex[id]
    if existing~canonicalText = node~canonicalText then return .LegalResult~success(existing, "duplicate identical node ignored")
    return .LegalResult~failure("DECISION_TRACE_NODE_COLLISION", id)
  end
  nodes~append(node)
  nodeIndex[id] = node
  return .LegalResult~success(node)

::method addEdge
  expose nodeIndex edges edgeIndex sealed
  use arg edge
  if sealed then return .LegalResult~failure("DECISION_TRACE_SEALED", "Decision trace is sealed")
  if edge == .nil then return .LegalResult~failure("DECISION_TRACE_EDGE_REQUIRED", "Edge must not be .nil")
  if \nodeIndex~hasIndex(edge~fromId) then return .LegalResult~failure("DECISION_TRACE_EDGE_SOURCE_MISSING", edge~fromId)
  if \nodeIndex~hasIndex(edge~toId) then return .LegalResult~failure("DECISION_TRACE_EDGE_TARGET_MISSING", edge~toId)
  key = edge~canonicalText
  if edgeIndex~hasIndex(key) then return .LegalResult~success(edgeIndex[key], "duplicate identical edge ignored")
  edges~append(edge)
  edgeIndex[key] = edge
  return .LegalResult~success(edge)

::method seal
  expose sealed
  sealed = .true
  return self

::method node
  expose nodeIndex
  use arg nodeIdArg
  return nodeIndex[nodeIdArg~string~upper]

::method nodes
  expose nodes
  copy = .array~new
  do item over nodes
    copy~append(item)
  end
  return copy

::method edges
  expose edges
  copy = .array~new
  do item over edges
    copy~append(item)
  end
  return copy

::method dispositions
  expose dispositions
  copy = .array~new
  do item over dispositions
    copy~append(item)
  end
  return copy

::method nodesByType
  expose nodes
  use arg wantedType
  wanted = wantedType~string~upper
  out = .array~new
  do node over nodes
    if node~nodeType = wanted then out~append(node)
  end
  return out

::method edgesFrom
  expose edges
  use arg nodeIdArg
  wanted = nodeIdArg~string~upper
  out = .array~new
  do edge over edges
    if edge~fromId = wanted then out~append(edge)
  end
  return out

::method edgesTo
  expose edges
  use arg nodeIdArg
  wanted = nodeIdArg~string~upper
  out = .array~new
  do edge over edges
    if edge~toId = wanted then out~append(edge)
  end
  return out

::method finalStatusNodeId
  expose status
  return "STATUS::" || status

::method whyFinalStatus
  return self~causalNodes(self~finalStatusNodeId)

::method causalNodes
  expose nodeIndex
  use arg targetNodeId
  target = targetNodeId~string~upper
  if \nodeIndex~hasIndex(target) then return .array~new
  visited = .table~new
  self~collectCauses(target, visited)
  ids = .array~new
  do id over visited
    ids~append(id)
  end
  sortedIds = .LegalCanonical~sortedStrings(ids)
  out = .array~new
  do id over sortedIds
    out~append(nodeIndex[id])
  end
  return out

::method collectCauses private
  expose edges
  use arg nodeIdArg, visited
  nodeId = nodeIdArg~string~upper
  if visited~hasIndex(nodeId) then return
  visited[nodeId] = .true
  do edge over edges
    if edge~toId = nodeId then self~collectCauses(edge~fromId, visited)
  end

::method canonicalText
  expose actionCode generationId generationSemanticIdentity eventId eventTime evaluationTime status dispositions nodes edges sealed
  if \sealed then raise syntax 88.900 array("LegalDecisionTrace canonicalText requires a sealed trace")
  text = .LegalCanonical~field("ACTION", actionCode)
  text ||= .LegalCanonical~field("GENERATION_ID", generationId)
  text ||= .LegalCanonical~field("GENERATION_SEMANTIC_IDENTITY", generationSemanticIdentity)
  text ||= .LegalCanonical~field("EVENT_ID", eventId)
  text ||= .LegalCanonical~field("EVENT_TIME", eventTime)
  text ||= .LegalCanonical~field("EVALUATION_TIME", evaluationTime)
  text ||= .LegalCanonical~field("STATUS", status)
  text ||= .LegalCanonical~joinCanonical("DISPOSITION", dispositions)
  nodeText = .array~new
  do node over nodes
    nodeText~append(node~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("NODE", nodeText)
  edgeText = .array~new
  do edge over edges
    edgeText~append(edge~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("EDGE", edgeText)
  return text

::method traceIdentity
  return self~canonicalText




::class LegalDecisionTraceQueryResult public
::attribute queryType get
::attribute traceIdentity get

::method init
  expose queryType traceIdentity nodes edges metadata
  use arg queryTypeArg, traceIdentityArg, nodesArg = .nil, edgesArg = .nil, metadataArg = .nil
  queryType = queryTypeArg~string~upper
  traceIdentity = traceIdentityArg~string
  nodes = .array~new
  if nodesArg \== .nil then do item over nodesArg
    nodes~append(item)
  end
  edges = .array~new
  if edgesArg \== .nil then do item over edgesArg
    edges~append(item)
  end
  metadata = .table~new
  if metadataArg \== .nil then do key over metadataArg
    metadata[key~string~upper] = metadataArg[key]
  end

::method nodes
  expose nodes
  copy = .array~new
  do item over nodes
    copy~append(item)
  end
  return copy

::method edges
  expose edges
  copy = .array~new
  do item over edges
    copy~append(item)
  end
  return copy

::method metadata
  expose metadata
  copy = .table~new
  do key over metadata
    copy[key] = metadata[key]
  end
  return copy

::method canonicalText
  expose queryType traceIdentity nodes edges metadata
  text = .LegalCanonical~field("QUERY_TYPE", queryType)
  text ||= .LegalCanonical~field("TRACE_IDENTITY", traceIdentity)
  nodeText = .array~new
  do node over nodes
    nodeText~append(node~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("NODE", nodeText)
  edgeText = .array~new
  do edge over edges
    edgeText~append(edge~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("EDGE", edgeText)
  metadataText = .array~new
  do key over metadata
    metadataText~append(.LegalCanonical~field("K", key) || .LegalCanonical~field("V", .LegalCanonical~scalar(metadata[key])))
  end
  text ||= .LegalCanonical~joinCanonical("METADATA", metadataText)
  return text

::method queryIdentity
  return self~canonicalText


::class LegalDecisionTraceQuery subclass LegalAlchemyObject public

::method whyFinalStatus
  use arg trace
  self~alchemyTouch("WHYFINALSTATUS")
  checked = self~checkTrace(trace)
  if \checked~ok then return checked
  nodes = trace~whyFinalStatus
  edges = self~edgesWithin(trace, nodes)
  return self~result("WHY_FINAL_STATUS", trace, nodes, edges)

::method controllingNorms
  use arg trace
  self~alchemyTouch("CONTROLLINGNORMS")
  checked = self~checkTrace(trace)
  if \checked~ok then return checked
  causeIndex = self~nodeIndex(trace~whyFinalStatus)
  found = .table~new
  do edge over trace~edges
    if edge~relationType <> "PRODUCES_DISPOSITION" then iterate
    if \causeIndex~hasIndex(edge~fromId) then iterate
    if \causeIndex~hasIndex(edge~toId) then iterate
    node = trace~node(edge~fromId)
    if node == .nil then iterate
    if node~nodeType <> "NORM" then iterate
    found[node~nodeId] = node
  end
  nodes = self~nodesFromIndex(found)
  return self~result("CONTROLLING_NORMS", trace, nodes, self~edgesWithin(trace, nodes))

::method suppressedNorms
  use arg trace
  self~alchemyTouch("SUPPRESSEDNORMS")
  checked = self~checkTrace(trace)
  if \checked~ok then return checked
  found = .table~new
  relevantEdges = .array~new
  do edge over trace~edges
    if edge~relationType <> "SUPPRESSES" then iterate
    node = trace~node(edge~toId)
    if node == .nil then iterate
    if node~nodeType <> "NORM" then iterate
    found[node~nodeId] = node
    relevantEdges~append(edge)
  end
  return self~result("SUPPRESSED_NORMS", trace, self~nodesFromIndex(found), self~sortEdges(relevantEdges))

::method authorityRules
  use arg trace
  self~alchemyTouch("AUTHORITYRULES")
  checked = self~checkTrace(trace)
  if \checked~ok then return checked
  nodes = .array~new
  do node over trace~whyFinalStatus
    if node~nodeType = "AUTHORITY_RULE" then nodes~append(node)
  end
  nodes = self~sortNodes(nodes)
  return self~result("AUTHORITY_RULES", trace, nodes, self~edgesWithin(trace, nodes))

::method whatChanged
  use arg trace
  self~alchemyTouch("WHATCHANGED")
  checked = self~checkTrace(trace)
  if \checked~ok then return checked
  nodeIndex = .table~new
  do node over trace~nodesByType("FACT_MUTATION")
    nodeIndex[node~nodeId] = node
  end
  changes = .array~new
  do edge over trace~edges
    if edge~relationType <> "BECOMES_APPLICABLE" then do
      if edge~relationType <> "CEASES_APPLICABLE" then do
        if edge~relationType <> "MAKES_APPLICABLE" then iterate
      end
    end
    changes~append(edge)
    fromNode = trace~node(edge~fromId)
    toNode = trace~node(edge~toId)
    if fromNode \== .nil then nodeIndex[fromNode~nodeId] = fromNode
    if toNode \== .nil then nodeIndex[toNode~nodeId] = toNode
  end
  metadata = .table~new
  metadata["FACT_MUTATIONS"] = trace~nodesByType("FACT_MUTATION")~items
  metadata["APPLICABILITY_CHANGES"] = changes~items
  return self~result("WHAT_CHANGED", trace, self~nodesFromIndex(nodeIndex), self~sortEdges(changes), metadata)

::method reviewInputs
  use arg trace
  self~alchemyTouch("REVIEWINPUTS")
  checked = self~checkTrace(trace)
  if \checked~ok then return checked
  found = .table~new
  metadata = .table~new
  metadata["COUNTERFACTUAL_PREDICTION"] = "NONE"
  metadata["GUARANTEED_OUTCOME_FLIP"] = .false
  metadata["MEANING"] = "Inputs causally responsible for review that require resolution; no alternate outcome is inferred"
  if trace~status <> "REVIEW_REQUIRED" then return self~result("REVIEW_INPUTS", trace, .array~new, .array~new, metadata)

  reviewRoots = .table~new
  statusId = trace~finalStatusNodeId
  do edge over trace~edges
    if edge~toId <> statusId then iterate
    if edge~relationType <> "REQUIRES_REVIEW" then iterate
    reviewRoots[edge~fromId] = .true
  end
  do rootId over reviewRoots
    causes = trace~causalNodes(rootId)
    do node over causes
      include = .false
      if node~nodeType = "PREDICATE_EVALUATION" then do
        attrs = node~attributes
        if attrs["RESULT"] = "UNKNOWN" then include = .true
      end
      if node~status = "UNRESOLVED" then include = .true
      if include then found[node~nodeId] = node
    end
  end
  nodes = self~nodesFromIndex(found)
  return self~result("REVIEW_INPUTS", trace, nodes, self~edgesWithin(trace, nodes), metadata)

::method sourceAnchors
  use arg trace
  self~alchemyTouch("SOURCEANCHORS")
  checked = self~checkTrace(trace)
  if \checked~ok then return checked
  found = .table~new
  do node over trace~whyFinalStatus
    if node~sourceId = "" then do
      if node~provisionId = "" then iterate
    end
    found[node~nodeId] = node
  end
  nodes = self~nodesFromIndex(found)
  return self~result("SOURCE_ANCHORS", trace, nodes, self~edgesWithin(trace, nodes))

::method checkTrace private
  use arg trace
  if trace == .nil then return .LegalResult~failure("DECISION_TRACE_REQUIRED", "Decision trace must not be .nil")
  if \trace~hasMethod("TRACEIDENTITY") then return .LegalResult~failure("DECISION_TRACE_CLASS_REQUIRED", "Object does not expose Legal Decision Trace identity")
  if \trace~sealed then return .LegalResult~failure("DECISION_TRACE_NOT_SEALED", "Queries require a sealed decision trace")
  return .LegalResult~success(trace)

::method result private
  use arg queryType, trace, nodesArg = .nil, edgesArg = .nil, metadataArg = .nil
  nodes = self~sortNodes(nodesArg)
  edges = self~sortEdges(edgesArg)
  value = .LegalDecisionTraceQueryResult~new(queryType, trace~traceIdentity, nodes, edges, metadataArg)
  return .LegalResult~success(value)

::method nodeIndex private
  use arg nodes
  out = .table~new
  if nodes == .nil then return out
  do node over nodes
    out[node~nodeId] = node
  end
  return out

::method nodesFromIndex private
  use arg index
  nodes = .array~new
  do id over index
    nodes~append(index[id])
  end
  return self~sortNodes(nodes)

::method edgesWithin private
  use arg trace, nodesArg
  index = self~nodeIndex(nodesArg)
  out = .array~new
  do edge over trace~edges
    if \index~hasIndex(edge~fromId) then iterate
    if \index~hasIndex(edge~toId) then iterate
    out~append(edge)
  end
  return self~sortEdges(out)

::method sortNodes private
  use arg nodesArg
  out = .array~new
  if nodesArg == .nil then return out
  do node over nodesArg
    placed = .false
    nextItems = .array~new
    do existing over out
      if \placed then do
        if node~nodeId < existing~nodeId then do
          nextItems~append(node)
          placed = .true
        end
      end
      nextItems~append(existing)
    end
    if \placed then nextItems~append(node)
    out = nextItems
  end
  return out

::method sortEdges private
  use arg edgesArg
  out = .array~new
  if edgesArg == .nil then return out
  do edge over edgesArg
    key = edge~canonicalText
    placed = .false
    nextItems = .array~new
    do existing over out
      if \placed then do
        if key < existing~canonicalText then do
          nextItems~append(edge)
          placed = .true
        end
      end
      nextItems~append(existing)
    end
    if \placed then nextItems~append(edge)
    out = nextItems
  end
  return out



/* -------------------------------------------------------------------------
 * Deterministic counterfactual / sensitivity analysis (v0.14)
 *
 * These objects are explicitly hypothetical.  They reuse the ordinary
 * LegalEffectEngine with one fact assumption layered after the original
 * proposed action.  They do not amend the source context, do not publish a
 * new rule generation, and are never legal execution authority.
 * ------------------------------------------------------------------------- */
::class LegalCounterfactualAssumption public
::attribute factName get
::attribute state get
::attribute value get
::attribute authority get
::attribute scope get

::method init
  expose factName state value authority scope
  use arg factNameArg, valueArg = .nil, stateArg = "KNOWN", scopeArg = "CONTEXT"
  factName = factNameArg~string~upper
  state = stateArg~string~upper
  if state <> "KNOWN" then do
    if state <> "UNKNOWN" then do
      if state <> "CONFLICT" then raise syntax 88.900 array("Counterfactual fact state must be KNOWN, UNKNOWN or CONFLICT")
    end
  end
  if state = "KNOWN" then value = valueArg
  else value = .nil
  authority = "COUNTERFACTUAL_ASSUMPTION"
  scope = scopeArg~string~upper
  if scope <> "CONTEXT" then do
    if scope <> "ACTION_OVERRIDE" then raise syntax 88.900 array("Counterfactual scope must be CONTEXT or ACTION_OVERRIDE")
  end

::method mutation
  expose factName state value authority
  return .LegalFactMutation~new(factName, value, state, .nil, authority)

::method canonicalText
  expose factName state value authority scope
  text = .LegalCanonical~field("FACT_NAME", factName)
  text ||= .LegalCanonical~field("STATE", state)
  text ||= .LegalCanonical~field("VALUE", .LegalCanonical~scalar(value))
  text ||= .LegalCanonical~field("AUTHORITY", authority)
  text ||= .LegalCanonical~field("SCOPE", scope)
  return text


::class LegalCounterfactualComparison public
::attribute baseTraceIdentity get
::attribute counterfactualTraceIdentity get
::attribute baseStatus get
::attribute counterfactualStatus get
::attribute assumption get
::attribute hypothetical get
::attribute authoritative get
::attribute statusChanged get
::attribute legallyMaterial get
::attribute counterfactualTrace get

::method init
  expose baseTraceIdentity counterfactualTraceIdentity baseStatus counterfactualStatus assumption hypothetical authoritative statusChanged legallyMaterial counterfactualTrace baseDispositions counterfactualDispositions addedDispositions removedDispositions baseControllingNorms counterfactualControllingNorms addedControllingNorms removedControllingNorms baseConflicts counterfactualConflicts addedConflicts removedConflicts baseSourceAnchors counterfactualSourceAnchors addedSourceAnchors removedSourceAnchors
  use arg baseTraceArg, counterfactualTraceArg, assumptionArg, baseDispositionsArg, counterfactualDispositionsArg, baseControllingNormsArg, counterfactualControllingNormsArg, baseConflictsArg, counterfactualConflictsArg, baseSourceAnchorsArg, counterfactualSourceAnchorsArg
  baseTraceIdentity = baseTraceArg~traceIdentity
  counterfactualTraceIdentity = counterfactualTraceArg~traceIdentity
  baseStatus = baseTraceArg~status
  counterfactualStatus = counterfactualTraceArg~status
  assumption = assumptionArg
  counterfactualTrace = counterfactualTraceArg
  hypothetical = .true
  authoritative = .false
  baseDispositions = self~normalStrings(baseDispositionsArg)
  counterfactualDispositions = self~normalStrings(counterfactualDispositionsArg)
  addedDispositions = self~difference(counterfactualDispositions, baseDispositions)
  removedDispositions = self~difference(baseDispositions, counterfactualDispositions)
  baseControllingNorms = self~normalStrings(baseControllingNormsArg)
  counterfactualControllingNorms = self~normalStrings(counterfactualControllingNormsArg)
  addedControllingNorms = self~difference(counterfactualControllingNorms, baseControllingNorms)
  removedControllingNorms = self~difference(baseControllingNorms, counterfactualControllingNorms)
  baseConflicts = self~normalStrings(baseConflictsArg)
  counterfactualConflicts = self~normalStrings(counterfactualConflictsArg)
  addedConflicts = self~difference(counterfactualConflicts, baseConflicts)
  removedConflicts = self~difference(baseConflicts, counterfactualConflicts)
  baseSourceAnchors = self~normalStrings(baseSourceAnchorsArg)
  counterfactualSourceAnchors = self~normalStrings(counterfactualSourceAnchorsArg)
  addedSourceAnchors = self~difference(counterfactualSourceAnchors, baseSourceAnchors)
  removedSourceAnchors = self~difference(baseSourceAnchors, counterfactualSourceAnchors)
  statusChanged = (baseStatus <> counterfactualStatus)
  legallyMaterial = statusChanged
  if addedDispositions~items > 0 then legallyMaterial = .true
  if removedDispositions~items > 0 then legallyMaterial = .true
  if addedControllingNorms~items > 0 then legallyMaterial = .true
  if removedControllingNorms~items > 0 then legallyMaterial = .true
  if addedConflicts~items > 0 then legallyMaterial = .true
  if removedConflicts~items > 0 then legallyMaterial = .true
  if addedSourceAnchors~items > 0 then legallyMaterial = .true
  if removedSourceAnchors~items > 0 then legallyMaterial = .true

::method baseDispositions
  expose baseDispositions
  return self~copyArray(baseDispositions)
::method counterfactualDispositions
  expose counterfactualDispositions
  return self~copyArray(counterfactualDispositions)
::method addedDispositions
  expose addedDispositions
  return self~copyArray(addedDispositions)
::method removedDispositions
  expose removedDispositions
  return self~copyArray(removedDispositions)
::method baseControllingNorms
  expose baseControllingNorms
  return self~copyArray(baseControllingNorms)
::method counterfactualControllingNorms
  expose counterfactualControllingNorms
  return self~copyArray(counterfactualControllingNorms)
::method addedControllingNorms
  expose addedControllingNorms
  return self~copyArray(addedControllingNorms)
::method removedControllingNorms
  expose removedControllingNorms
  return self~copyArray(removedControllingNorms)
::method baseConflicts
  expose baseConflicts
  return self~copyArray(baseConflicts)
::method counterfactualConflicts
  expose counterfactualConflicts
  return self~copyArray(counterfactualConflicts)
::method addedConflicts
  expose addedConflicts
  return self~copyArray(addedConflicts)
::method removedConflicts
  expose removedConflicts
  return self~copyArray(removedConflicts)
::method baseSourceAnchors
  expose baseSourceAnchors
  return self~copyArray(baseSourceAnchors)
::method counterfactualSourceAnchors
  expose counterfactualSourceAnchors
  return self~copyArray(counterfactualSourceAnchors)
::method addedSourceAnchors
  expose addedSourceAnchors
  return self~copyArray(addedSourceAnchors)
::method removedSourceAnchors
  expose removedSourceAnchors
  return self~copyArray(removedSourceAnchors)

::method canonicalText
  expose baseTraceIdentity counterfactualTraceIdentity baseStatus counterfactualStatus assumption hypothetical authoritative statusChanged legallyMaterial baseDispositions counterfactualDispositions addedDispositions removedDispositions baseControllingNorms counterfactualControllingNorms addedControllingNorms removedControllingNorms baseConflicts counterfactualConflicts addedConflicts removedConflicts baseSourceAnchors counterfactualSourceAnchors addedSourceAnchors removedSourceAnchors
  text = .LegalCanonical~field("SCHEMA", "legal.effect.counterfactual/0.1")
  text ||= .LegalCanonical~field("BASE_TRACE_IDENTITY", baseTraceIdentity)
  text ||= .LegalCanonical~field("COUNTERFACTUAL_TRACE_IDENTITY", counterfactualTraceIdentity)
  text ||= .LegalCanonical~field("ASSUMPTION", assumption~canonicalText)
  text ||= .LegalCanonical~field("BASE_STATUS", baseStatus)
  text ||= .LegalCanonical~field("COUNTERFACTUAL_STATUS", counterfactualStatus)
  text ||= .LegalCanonical~field("HYPOTHETICAL", .LegalCanonical~scalar(hypothetical))
  text ||= .LegalCanonical~field("AUTHORITATIVE", .LegalCanonical~scalar(authoritative))
  text ||= .LegalCanonical~field("STATUS_CHANGED", .LegalCanonical~scalar(statusChanged))
  text ||= .LegalCanonical~field("LEGALLY_MATERIAL", .LegalCanonical~scalar(legallyMaterial))
  text ||= .LegalCanonical~joinCanonical("BASE_DISPOSITION", baseDispositions)
  text ||= .LegalCanonical~joinCanonical("COUNTERFACTUAL_DISPOSITION", counterfactualDispositions)
  text ||= .LegalCanonical~joinCanonical("ADDED_DISPOSITION", addedDispositions)
  text ||= .LegalCanonical~joinCanonical("REMOVED_DISPOSITION", removedDispositions)
  text ||= .LegalCanonical~joinCanonical("BASE_CONTROLLING_NORM", baseControllingNorms)
  text ||= .LegalCanonical~joinCanonical("COUNTERFACTUAL_CONTROLLING_NORM", counterfactualControllingNorms)
  text ||= .LegalCanonical~joinCanonical("ADDED_CONTROLLING_NORM", addedControllingNorms)
  text ||= .LegalCanonical~joinCanonical("REMOVED_CONTROLLING_NORM", removedControllingNorms)
  text ||= .LegalCanonical~joinCanonical("BASE_CONFLICT", baseConflicts)
  text ||= .LegalCanonical~joinCanonical("COUNTERFACTUAL_CONFLICT", counterfactualConflicts)
  text ||= .LegalCanonical~joinCanonical("ADDED_CONFLICT", addedConflicts)
  text ||= .LegalCanonical~joinCanonical("REMOVED_CONFLICT", removedConflicts)
  text ||= .LegalCanonical~joinCanonical("BASE_SOURCE_ANCHOR", baseSourceAnchors)
  text ||= .LegalCanonical~joinCanonical("COUNTERFACTUAL_SOURCE_ANCHOR", counterfactualSourceAnchors)
  text ||= .LegalCanonical~joinCanonical("ADDED_SOURCE_ANCHOR", addedSourceAnchors)
  text ||= .LegalCanonical~joinCanonical("REMOVED_SOURCE_ANCHOR", removedSourceAnchors)
  return text

::method counterfactualIdentity
  return self~canonicalText

::method normalStrings private
  use arg items
  values = .array~new
  if items == .nil then return values
  seen = .table~new
  do item over items
    value = item~string
    if seen~hasIndex(value) then iterate
    seen[value] = .true
    values~append(value)
  end
  return .LegalCanonical~sortedStrings(values)

::method difference private
  use arg left, right
  seen = .table~new
  do item over right
    seen[item] = .true
  end
  out = .array~new
  do item over left
    if \seen~hasIndex(item) then out~append(item)
  end
  return .LegalCanonical~sortedStrings(out)

::method copyArray private
  use arg items
  out = .array~new
  do item over items
    out~append(item)
  end
  return out


::class LegalCounterfactualSet public
::attribute factName get
::attribute hypothetical get
::attribute authoritative get

::method init
  expose factName hypothetical authoritative comparisons
  use arg factNameArg, comparisonsArg
  factName = factNameArg~string~upper
  hypothetical = .true
  authoritative = .false
  comparisons = .array~new
  do comparison over comparisonsArg
    comparisons~append(comparison)
  end

::method comparisons
  expose comparisons
  copy = .array~new
  do item over comparisons
    copy~append(item)
  end
  return copy

::method canonicalText
  expose factName hypothetical authoritative comparisons
  text = .LegalCanonical~field("SCHEMA", "legal.effect.counterfactual-set/0.1")
  text ||= .LegalCanonical~field("FACT_NAME", factName)
  text ||= .LegalCanonical~field("HYPOTHETICAL", .LegalCanonical~scalar(hypothetical))
  text ||= .LegalCanonical~field("AUTHORITATIVE", .LegalCanonical~scalar(authoritative))
  comparisonText = .array~new
  do item over comparisons
    comparisonText~append(item~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("COMPARISON", comparisonText)
  return text

::method setIdentity
  return self~canonicalText


::class LegalCounterfactualEvaluator subclass LegalAlchemyObject public

::method evaluateFact
  use arg assessment, factNameArg, valueArg = .nil, stateArg = "KNOWN", scopeArg = "CONTEXT"
  self~alchemyTouch("EVALUATEFACT")
  checked = self~checkAssessment(assessment)
  if \checked~ok then return checked
  factName = factNameArg~string~upper
  if factName = "" then return .LegalResult~failure("COUNTERFACTUAL_FACT_REQUIRED", "Fact name must not be empty")
  state = stateArg~string~upper
  if state <> "KNOWN" then do
    if state <> "UNKNOWN" then do
      if state <> "CONFLICT" then return .LegalResult~failure("COUNTERFACTUAL_STATE_INVALID", state)
    end
  end
  scope = scopeArg~string~upper
  if scope <> "CONTEXT" then do
    if scope <> "ACTION_OVERRIDE" then return .LegalResult~failure("COUNTERFACTUAL_SCOPE_INVALID", scope)
  end
  assumption = .LegalCounterfactualAssumption~new(factName, valueArg, state, scope)
  altAction = self~copyAction(assessment~action)
  altContext = assessment~currentContext~clone
  if scope = "CONTEXT" then ignored = assumption~mutation~apply(altContext~facts)
  else altAction~addMutation(assumption~mutation)
  altResult = .LegalEffectEngine~new~evaluate(altAction, assessment~generation, altContext)
  if \altResult~ok then return altResult
  alternative = altResult~value
  comparisonResult = self~compare(assessment, alternative, assumption)
  return comparisonResult

::method evaluateBoolean
  use arg assessment, factNameArg, scopeArg = "CONTEXT"
  self~alchemyTouch("EVALUATEBOOLEAN")
  checked = self~checkAssessment(assessment)
  if \checked~ok then return checked
  falseResult = self~evaluateFact(assessment, factNameArg, .false, "KNOWN", scopeArg)
  if \falseResult~ok then return falseResult
  trueResult = self~evaluateFact(assessment, factNameArg, .true, "KNOWN", scopeArg)
  if \trueResult~ok then return trueResult
  set = .LegalCounterfactualSet~new(factNameArg, .array~of(falseResult~value, trueResult~value))
  return .LegalResult~success(set)

::method checkAssessment private
  use arg assessment
  if assessment == .nil then return .LegalResult~failure("ASSESSMENT_REQUIRED", "Counterfactual analysis requires a completed LegalEffectAssessment")
  if \assessment~hasMethod("DECISIONTRACE") then return .LegalResult~failure("LEGAL_EFFECT_ASSESSMENT_REQUIRED", "Object does not expose a Legal Effect decision trace")
  if assessment~decisionTrace == .nil then return .LegalResult~failure("DECISION_TRACE_REQUIRED", "Counterfactual analysis requires a completed decision trace")
  if \assessment~generation~sealed then return .LegalResult~failure("GENERATION_NOT_SEALED", "Counterfactual analysis requires the same sealed legal generation")
  return .LegalResult~success(assessment)

::method copyAction private
  use arg action
  copy = .LegalAction~new(action~actionCode, action~description)
  do mutation over action~mutations
    copy~addMutation(.LegalFactMutation~new(mutation~factName, mutation~value, mutation~state, mutation~source, mutation~authority))
  end
  return copy

::method compare private
  use arg baseAssessment, alternativeAssessment, assumption
  query = .LegalDecisionTraceQuery~new
  baseTrace = baseAssessment~decisionTrace
  alternativeTrace = alternativeAssessment~decisionTrace
  baseControlResult = query~controllingNorms(baseTrace)
  if \baseControlResult~ok then return baseControlResult
  altControlResult = query~controllingNorms(alternativeTrace)
  if \altControlResult~ok then return altControlResult
  baseAnchorsResult = query~sourceAnchors(baseTrace)
  if \baseAnchorsResult~ok then return baseAnchorsResult
  altAnchorsResult = query~sourceAnchors(alternativeTrace)
  if \altAnchorsResult~ok then return altAnchorsResult
  comparison = .LegalCounterfactualComparison~new(baseTrace, alternativeTrace, assumption, baseAssessment~dispositions, alternativeAssessment~dispositions, self~normIds(baseControlResult~value~nodes), self~normIds(altControlResult~value~nodes), self~conflictIds(baseTrace), self~conflictIds(alternativeTrace), self~sourceAnchorIds(baseAnchorsResult~value~nodes), self~sourceAnchorIds(altAnchorsResult~value~nodes))
  return .LegalResult~success(comparison)

::method normIds private
  use arg nodes
  ids = .array~new
  do node over nodes
    ids~append(node~subjectId)
  end
  return .LegalCanonical~sortedStrings(ids)

::method conflictIds private
  use arg trace
  ids = .array~new
  do node over trace~nodesByType("NORM_CONFLICT")
    ids~append(node~nodeId)
  end
  return .LegalCanonical~sortedStrings(ids)

::method sourceAnchorIds private
  use arg nodes
  ids = .array~new
  do node over nodes
    if node~sourceId = "" then iterate
    ids~append(node~sourceId || "::" || node~provisionId || "::" || node~nodeType || "::" || node~subjectId)
  end
  return .LegalCanonical~sortedStrings(ids)

::class LegalDecisionTraceBuilder subclass LegalAlchemyObject public

::method build
  use arg assessment
  self~alchemyTouch("BUILD")
  if assessment == .nil then return .LegalResult~failure("INVALID_ASSESSMENT", "Assessment must not be .nil")
  generation = assessment~generation
  context = assessment~currentContext
  trace = .LegalDecisionTrace~new(assessment~action~actionCode, generation~generationId, generation~semanticIdentity, context~eventId, context~eventTime, context~evaluationTime, assessment~status, assessment~dispositions)

  actionAttrs = .table~new
  actionAttrs["DESCRIPTION"] = assessment~action~description
  actionNode = .LegalDecisionTraceNode~new("ACTION", "ACTION", "PROSPECTIVE", "PROPOSED", assessment~action~actionCode, "", "", assessment~action~description, actionAttrs)
  added = trace~addNode(actionNode)
  if \added~ok then return added

  mutationByFact = .table~new
  mutationIndex = 0
  do mutation over assessment~action~mutations
    mutationIndex += 1
    mutationId = "MUTATION::" || mutationIndex || "::" || mutation~factName
    attrs = .table~new
    attrs["FACT_NAME"] = mutation~factName
    attrs["STATE"] = mutation~state
    attrs["VALUE"] = mutation~value
    attrs["AUTHORITY"] = mutation~authority
    node = .LegalDecisionTraceNode~new(mutationId, "FACT_MUTATION", "PROSPECTIVE", mutation~state, mutation~factName, "", "", "candidate action mutates fact", attrs, .array~of(mutation~source))
    added = trace~addNode(node)
    if \added~ok then return added
    added = trace~addEdge(.LegalDecisionTraceEdge~new("ACTION", "MUTATES_FACT", mutationId))
    if \added~ok then return added
    if \mutationByFact~hasIndex(mutation~factName) then mutationByFact[mutation~factName] = .array~new
    mutationByFact[mutation~factName]~append(mutationId)
  end

  addBefore = self~addSnapshot(trace, assessment~beforeSnapshot, "BEFORE")
  if \addBefore~ok then return addBefore
  addAfter = self~addSnapshot(trace, assessment~afterSnapshot, "AFTER")
  if \addAfter~ok then return addAfter

  beforeMatches = self~sortNormMatches(assessment~beforeMatches)
  do match over beforeMatches
    added = self~addNormMatch(trace, match, "BEFORE", mutationByFact)
    if \added~ok then return added
  end
  afterMatches = self~sortNormMatches(assessment~afterMatches)
  do match over afterMatches
    added = self~addNormMatch(trace, match, "AFTER", mutationByFact)
    if \added~ok then return added
  end

  do match over assessment~newlyApplicable
    beforeId = "NORM::BEFORE::" || match~norm~normId
    afterId = "NORM::AFTER::" || match~norm~normId
    if trace~node(beforeId) \== .nil then do
      added = trace~addEdge(.LegalDecisionTraceEdge~new(beforeId, "BECOMES_APPLICABLE", afterId))
      if \added~ok then return added
    end
    else do
      added = trace~addEdge(.LegalDecisionTraceEdge~new("ACTION", "MAKES_APPLICABLE", afterId))
      if \added~ok then return added
    end
  end
  do match over assessment~ceasedApplicable
    beforeId = "NORM::BEFORE::" || match~norm~normId
    afterId = "NORM::AFTER::" || match~norm~normId
    if trace~node(afterId) \== .nil then do
      added = trace~addEdge(.LegalDecisionTraceEdge~new(beforeId, "CEASES_APPLICABLE", afterId))
      if \added~ok then return added
    end
  end

  conflicts = self~sortConflicts(assessment~resolvedConflicts, assessment~unresolvedConflicts)
  do conflict over conflicts
    added = self~addConflict(trace, conflict, mutationByFact)
    if \added~ok then return added
  end

  dispositions = .LegalCanonical~sortedStrings(assessment~dispositions)
  do disposition over dispositions
    dispositionId = "DISPOSITION::" || disposition
    node = .LegalDecisionTraceNode~new(dispositionId, "DISPOSITION", "FINAL", "EFFECTIVE", disposition, "", "", "effective legal disposition")
    added = trace~addNode(node)
    if \added~ok then return added
    do match over assessment~effectiveMatches
      if match~norm~disposition = disposition then do
        normId = "NORM::AFTER::" || match~norm~normId
        added = trace~addEdge(.LegalDecisionTraceEdge~new(normId, "PRODUCES_DISPOSITION", dispositionId))
        if \added~ok then return added
      end
    end
  end

  statusId = "STATUS::" || assessment~status
  statusNode = .LegalDecisionTraceNode~new(statusId, "STATUS", "FINAL", assessment~status, assessment~status, "", "", "final legal-effect assessment status")
  added = trace~addNode(statusNode)
  if \added~ok then return added
  do disposition over dispositions
    added = trace~addEdge(.LegalDecisionTraceEdge~new("DISPOSITION::" || disposition, "CONTRIBUTES_TO_STATUS", statusId))
    if \added~ok then return added
  end
  do match over assessment~unresolved
    id = "NORM::AFTER::" || match~norm~normId
    added = trace~addEdge(.LegalDecisionTraceEdge~new(id, "REQUIRES_REVIEW", statusId))
    if \added~ok then return added
  end
  do conflict over assessment~unresolvedConflicts
    conflictId = self~conflictNodeId(conflict)
    added = trace~addEdge(.LegalDecisionTraceEdge~new(conflictId, "REQUIRES_REVIEW", statusId))
    if \added~ok then return added
  end
  if dispositions~items = 0 then do
    if assessment~unresolved~items = 0 then do
      if assessment~unresolvedConflicts~items = 0 then do
        added = trace~addEdge(.LegalDecisionTraceEdge~new("ACTION", "ASSESSMENT_COMPLETED", statusId))
        if \added~ok then return added
      end
    end
  end

  trace~seal
  return .LegalResult~success(trace, "structured legal decision trace built")

::method addSnapshot private
  use arg trace, snapshot, phase
  if snapshot == .nil then return .LegalResult~success
  snapshotId = "FRAMEWORK::" || phase
  attrs = .table~new
  attrs["APPLIED_MODIFICATIONS"] = snapshot~appliedModifications~items
  attrs["UNRESOLVED_MODIFICATIONS"] = snapshot~unresolvedModifications~items
  node = .LegalDecisionTraceNode~new(snapshotId, "FRAMEWORK_SNAPSHOT", phase, "RESOLVED", snapshot~generation~generationId, "", "", "time/jurisdiction-specific legal framework", attrs)
  added = trace~addNode(node)
  if \added~ok then return added
  matches = .array~new
  do match over snapshot~appliedModifications
    matches~append(match)
  end
  do match over snapshot~unresolvedModifications
    matches~append(match)
  end
  matches = self~sortModificationMatches(matches)
  do match over matches
    effect = match~effect
    modId = "MODIFICATION::" || phase || "::" || effect~effectId
    attrs = .table~new
    attrs["EFFECT_TYPE"] = effect~effectType
    attrs["TARGET_SOURCE"] = effect~targetSourceId
    attrs["TARGET_PROVISION"] = effect~targetProvisionId
    attrs["APPLICATION_ORDER"] = effect~applicationOrder
    attrs["RESULTING_VERSION"] = effect~resultingVersion
    node = .LegalDecisionTraceNode~new(modId, "MODIFICATION", phase, match~status, effect~effectId, effect~sourceId, effect~sourceProvisionId, "documentary/legal modification", attrs, effect~evidence, match~reasons)
    added = trace~addNode(node)
    if \added~ok then return added
    added = trace~addEdge(.LegalDecisionTraceEdge~new(modId, "SHAPES_FRAMEWORK", snapshotId))
    if \added~ok then return added
    added = self~addPredicateEvaluations(trace, modId, match~predicateEvaluations, phase, "MODIFICATION", effect~effectId, .table~new)
    if \added~ok then return added
  end
  return .LegalResult~success

::method addNormMatch private
  use arg trace, match, phase, mutationByFact
  norm = match~norm
  normNodeId = "NORM::" || phase || "::" || norm~normId
  attrs = .table~new
  attrs["NORM_TYPE"] = norm~normType
  attrs["ACTION"] = norm~actionCode
  attrs["DISPOSITION"] = norm~disposition
  attrs["SUBJECT_MATTER"] = norm~subjectMatter
  attrs["MATERIAL_VERSION"] = norm~materialVersion
  attrs["CONFLICT_KEY"] = norm~conflictKey
  node = .LegalDecisionTraceNode~new(normNodeId, "NORM", phase, match~status, norm~normId, norm~sourceId, norm~provisionId, norm~rationale, attrs, norm~evidence, match~reasons)
  added = trace~addNode(node)
  if \added~ok then return added
  if phase = "AFTER" then do
    added = trace~addEdge(.LegalDecisionTraceEdge~new("ACTION", "EVALUATES_PROSPECTIVE_NORM", normNodeId))
    if \added~ok then return added
  end
  else do
    added = trace~addEdge(.LegalDecisionTraceEdge~new("FRAMEWORK::BEFORE", "EVALUATES_CURRENT_NORM", normNodeId))
    if \added~ok then return added
  end
  added = self~addPredicateEvaluations(trace, normNodeId, match~predicateEvaluations, phase, "NORM", norm~normId, mutationByFact)
  if \added~ok then return added
  do modPhase over .array~of("BEFORE", "AFTER")
    if modPhase <> phase then iterate
    do nodeCandidate over trace~nodesByType("MODIFICATION")
      if nodeCandidate~phase <> phase then iterate
      attrs2 = nodeCandidate~attributes
      if attrs2["TARGET_SOURCE"] = norm~sourceId then do
        if attrs2["TARGET_PROVISION"] = norm~provisionId then do
          added = trace~addEdge(.LegalDecisionTraceEdge~new(nodeCandidate~nodeId, "AFFECTS_NORM_PROVISION", normNodeId))
          if \added~ok then return added
        end
      end
    end
  end
  return .LegalResult~success

::method addPredicateEvaluations private
  use arg trace, parentId, evaluationsArg, phase, parentType, parentSubjectId, mutationByFact
  evaluations = self~sortPredicateEvaluations(evaluationsArg)
  index = 0
  do evaluation over evaluations
    index += 1
    predicate = evaluation~predicate
    role = evaluation~role
    predId = "PREDICATE::" || phase || "::" || parentType || "::" || parentSubjectId || "::" || role || "::" || index
    attrs = .table~new
    attrs["ROLE"] = role
    attrs["RESULT"] = evaluation~result
    attrs["FACT_NAME"] = evaluation~factName
    attrs["FACT_STATE"] = evaluation~factState
    attrs["FACT_VALUE"] = evaluation~factValue
    attrs["FACT_AUTHORITY"] = evaluation~factAuthority
    if predicate \== .nil then do
      attrs["OPERATOR"] = predicate~operator
      attrs["EXPECTED_VALUE"] = predicate~expectedValue
    end
    ev = .array~new
    if evaluation~factEvidence \== .nil then ev~append(evaluation~factEvidence)
    node = .LegalDecisionTraceNode~new(predId, "PREDICATE_EVALUATION", phase, evaluation~result, evaluation~factName, "", "", role || " predicate evaluation", attrs, ev)
    added = trace~addNode(node)
    if \added~ok then return added
    added = trace~addEdge(.LegalDecisionTraceEdge~new(predId, role || "_OF", parentId))
    if \added~ok then return added
    if phase = "AFTER" then do
      if mutationByFact~hasIndex(evaluation~factName) then do mutationId over mutationByFact[evaluation~factName]
        added = trace~addEdge(.LegalDecisionTraceEdge~new(mutationId, "SUPPLIES_PROPOSED_FACT", predId))
        if \added~ok then return added
      end
    end
  end
  return .LegalResult~success

::method addConflict private
  use arg trace, conflict, mutationByFact
  conflictId = self~conflictNodeId(conflict)
  attrs = .table~new
  attrs["CONFLICT_KEY"] = conflict~conflictKey
  if conflict~winnerMatch \== .nil then attrs["WINNER_NORM"] = conflict~winnerMatch~norm~normId
  if conflict~loserMatch \== .nil then attrs["LOSER_NORM"] = conflict~loserMatch~norm~normId
  node = .LegalDecisionTraceNode~new(conflictId, "NORM_CONFLICT", "AFTER", conflict~status, conflict~conflictKey, "", "", "conflicting applicable norms", attrs, .nil, conflict~reasons)
  added = trace~addNode(node)
  if \added~ok then return added
  leftId = "NORM::AFTER::" || conflict~leftMatch~norm~normId
  rightId = "NORM::AFTER::" || conflict~rightMatch~norm~normId
  added = trace~addEdge(.LegalDecisionTraceEdge~new(leftId, "PARTICIPATES_IN_CONFLICT", conflictId))
  if \added~ok then return added
  added = trace~addEdge(.LegalDecisionTraceEdge~new(rightId, "PARTICIPATES_IN_CONFLICT", conflictId))
  if \added~ok then return added
  if conflict~winnerMatch \== .nil then do
    added = trace~addEdge(.LegalDecisionTraceEdge~new(conflictId, "SELECTS", "NORM::AFTER::" || conflict~winnerMatch~norm~normId))
    if \added~ok then return added
  end
  if conflict~loserMatch \== .nil then do
    added = trace~addEdge(.LegalDecisionTraceEdge~new(conflictId, "SUPPRESSES", "NORM::AFTER::" || conflict~loserMatch~norm~normId))
    if \added~ok then return added
  end
  if conflict~authorityMatch \== .nil then do
    authorityMatch = conflict~authorityMatch
    rule = authorityMatch~rule
    authorityId = "AUTHORITY::" || rule~ruleId || "::" || conflictId
    attrs = .table~new
    attrs["RELATION_TYPE"] = rule~relationType
    attrs["WINNER_SOURCE"] = rule~winnerSourceId
    attrs["LOSER_SOURCE"] = rule~loserSourceId
    attrs["WINNER_NORM"] = rule~winnerNormId
    attrs["LOSER_NORM"] = rule~loserNormId
    node = .LegalDecisionTraceNode~new(authorityId, "AUTHORITY_RULE", "AFTER", authorityMatch~status, rule~ruleId, rule~authoritySourceId, rule~authorityProvisionId, rule~rationale, attrs, rule~evidence, authorityMatch~reasons)
    added = trace~addNode(node)
    if \added~ok then return added
    added = trace~addEdge(.LegalDecisionTraceEdge~new(authorityId, "RESOLVES_CONFLICT", conflictId))
    if \added~ok then return added
    added = self~addPredicateEvaluations(trace, authorityId, authorityMatch~predicateEvaluations, "AFTER", "AUTHORITY", rule~ruleId, mutationByFact)
    if \added~ok then return added
  end
  return .LegalResult~success

::method conflictNodeId private
  use arg conflict
  leftId = conflict~leftMatch~norm~normId
  rightId = conflict~rightMatch~norm~normId
  if leftId > rightId then do
    t = leftId
    leftId = rightId
    rightId = t
  end
  id = "CONFLICT::" || conflict~conflictKey || "::" || leftId || "::" || rightId || "::" || conflict~status
  if conflict~winnerMatch \== .nil then id ||= "::WIN::" || conflict~winnerMatch~norm~normId
  if conflict~loserMatch \== .nil then id ||= "::LOSE::" || conflict~loserMatch~norm~normId
  if conflict~authorityMatch \== .nil then id ||= "::AUTH::" || conflict~authorityMatch~rule~ruleId
  return id

::method sortNormMatches private
  use arg matches
  return self~sortObjects(matches, "NORM")

::method sortModificationMatches private
  use arg matches
  return self~sortObjects(matches, "MODIFICATION")

::method sortPredicateEvaluations private
  use arg evaluations
  return self~sortObjects(evaluations, "CANONICAL")

::method sortConflicts private
  use arg resolved, unresolved
  all = .array~new
  do item over resolved
    all~append(item)
  end
  do item over unresolved
    all~append(item)
  end
  sorted = .array~new
  do item over all
    key = self~conflictNodeId(item)
    placed = .false
    nextItems = .array~new
    do existing over sorted
      if \placed then do
        if key < self~conflictNodeId(existing) then do
          nextItems~append(item)
          placed = .true
        end
      end
      nextItems~append(existing)
    end
    if \placed then nextItems~append(item)
    sorted = nextItems
  end
  return sorted

::method sortObjects private
  use arg objects, kind
  sorted = .array~new
  do item over objects
    key = self~objectSortKey(item, kind)
    placed = .false
    nextItems = .array~new
    do existing over sorted
      if \placed then do
        if key < self~objectSortKey(existing, kind) then do
          nextItems~append(item)
          placed = .true
        end
      end
      nextItems~append(existing)
    end
    if \placed then nextItems~append(item)
    sorted = nextItems
  end
  return sorted

::method objectSortKey private
  use arg item, kind
  select
    when kind = "NORM" then return item~norm~normId
    when kind = "MODIFICATION" then return item~effect~effectId
    otherwise return item~canonicalText
  end


::class LegalEffectAssessment public
::attribute action get
::attribute generation get
::attribute currentContext get
::attribute prospectiveContext get
::attribute beforeSnapshot get
::attribute afterSnapshot get
::attribute beforeMatches get
::attribute afterMatches get
::attribute newlyApplicable get
::attribute ceasedApplicable get
::attribute unresolved get
::attribute effectiveMatches get
::attribute suppressedMatches get
::attribute resolvedConflicts get
::attribute unresolvedConflicts get
::attribute status get
::attribute dispositions get
::attribute trace get
::attribute decisionTrace get

::method init
  expose action generation currentContext prospectiveContext beforeSnapshot afterSnapshot beforeMatches afterMatches newlyApplicable ceasedApplicable unresolved effectiveMatches suppressedMatches resolvedConflicts unresolvedConflicts status dispositions trace decisionTrace
  use arg actionArg, generationArg, currentContextArg, prospectiveContextArg, beforeSnapshotArg = .nil, afterSnapshotArg = .nil
  action = actionArg
  generation = generationArg
  currentContext = currentContextArg
  prospectiveContext = prospectiveContextArg
  beforeSnapshot = beforeSnapshotArg
  afterSnapshot = afterSnapshotArg
  beforeMatches = .array~new
  afterMatches = .array~new
  newlyApplicable = .array~new
  ceasedApplicable = .array~new
  unresolved = .array~new
  effectiveMatches = .array~new
  suppressedMatches = .array~new
  resolvedConflicts = .array~new
  unresolvedConflicts = .array~new
  dispositions = .array~new
  trace = .array~new
  decisionTrace = .nil
  status = "ADMISSIBLE"

::method setStatus
  expose status
  use arg value
  status = value~string~upper
  return self

::method addDisposition
  expose dispositions
  use arg disposition
  wanted = disposition~string~upper
  do existing over dispositions
    if existing = wanted then return self
  end
  dispositions~append(wanted)
  return self

::method addTrace
  expose trace
  use arg line
  trace~append(line~string)
  return self

::method setDecisionTrace
  expose decisionTrace
  use arg traceObject
  if traceObject == .nil then return .LegalResult~failure("DECISION_TRACE_REQUIRED", "Decision trace must not be .nil")
  if decisionTrace \== .nil then return .LegalResult~failure("DECISION_TRACE_ALREADY_SET", "Decision trace is one-shot")
  decisionTrace = traceObject
  return .LegalResult~success(traceObject)

::method sourceForNorm
  expose generation
  use arg norm
  return generation~source(norm~sourceId)


::class LegalEffectEngine subclass LegalAlchemyObject public

::method evaluate
  use arg action, generation, context
  self~alchemyTouch("EVALUATE")
  if action == .nil then return .LegalResult~failure("INVALID_ACTION", "Action must not be .nil")
  if generation == .nil then return .LegalResult~failure("INVALID_GENERATION", "Generation must not be .nil")
  if \generation~sealed then return .LegalResult~failure("GENERATION_NOT_SEALED", "Only sealed legal rule generations may execute")
  if context == .nil then return .LegalResult~failure("INVALID_CONTEXT", "Context must not be .nil")

  prospective = action~simulate(context)
  resolver = .LegalFrameworkResolver~new
  beforeResolve = resolver~resolve(generation, context)
  if \beforeResolve~ok then return beforeResolve
  afterResolve = resolver~resolve(generation, prospective)
  if \afterResolve~ok then return afterResolve
  beforeSnapshot = beforeResolve~value
  afterSnapshot = afterResolve~value
  assessment = .LegalEffectAssessment~new(action, generation, context, prospective, beforeSnapshot, afterSnapshot)
  beforeById = .table~new
  afterById = .table~new

  do norm over generation~norms
    if \norm~matchesAction(action~actionCode) then iterate
    sourceObject = generation~source(norm~sourceId)
    if sourceObject == .nil then do
      reasons = .array~of("normative source missing from sealed generation: " || norm~sourceId)
      beforeMatch = .LegalNormMatch~new(norm, "UNRESOLVED", reasons)
      afterMatch = .LegalNormMatch~new(norm, "UNRESOLVED", reasons)
    end
    else do
      beforeMatch = self~evaluateNormInSnapshot(norm, sourceObject, context, beforeSnapshot)
      afterMatch = self~evaluateNormInSnapshot(norm, sourceObject, prospective, afterSnapshot)
    end
    assessment~beforeMatches~append(beforeMatch)
    assessment~afterMatches~append(afterMatch)
    beforeById[norm~normId] = beforeMatch
    afterById[norm~normId] = afterMatch
  end

  do normId over afterById
    beforeMatch = beforeById[normId]
    afterMatch = afterById[normId]
    if afterMatch~status = "UNRESOLVED" then assessment~unresolved~append(afterMatch)
    if afterMatch~status = "APPLIES" then do
      if beforeMatch == .nil then assessment~newlyApplicable~append(afterMatch)
      else if beforeMatch~status <> "APPLIES" then assessment~newlyApplicable~append(afterMatch)
    end
    if beforeMatch \== .nil then do
      if beforeMatch~status = "APPLIES" then do
        if afterMatch~status <> "APPLIES" then assessment~ceasedApplicable~append(beforeMatch)
      end
    end
  end

  conflictResult = self~resolveApplicableConflicts(generation, prospective, assessment)
  if \conflictResult~ok then return conflictResult
  do effectiveMatch over assessment~effectiveMatches
    assessment~addDisposition(effectiveMatch~norm~disposition)
  end

  if assessment~unresolved~items > 0 then assessment~setStatus("REVIEW_REQUIRED")
  if assessment~unresolvedConflicts~items > 0 then assessment~setStatus("REVIEW_REQUIRED")
  do disposition over assessment~dispositions
    select
      when disposition = "PROHIBITED" then assessment~setStatus("BLOCKED")
      when disposition = "CONTRACT_BREACH" then assessment~setStatus("BLOCKED")
      when disposition = "TREATY_BREACH" then assessment~setStatus("BLOCKED")
      when disposition = "REQUIRES_OBLIGATION" then do
        if assessment~status = "ADMISSIBLE" then assessment~setStatus("CONDITIONAL")
      end
      when disposition = "STATUS_EFFECT" then do
        if assessment~status = "ADMISSIBLE" then assessment~setStatus("REVIEW_REQUIRED")
      end
      when disposition = "REVIEW" then do
        if assessment~status = "ADMISSIBLE" then assessment~setStatus("REVIEW_REQUIRED")
      end
      otherwise nop
    end
  end

  assessment~addTrace("generation=" || generation~generationId)
  assessment~addTrace("action=" || action~actionCode)
  assessment~addTrace("status=" || assessment~status)
  assessment~addTrace("before-modifications=" || beforeSnapshot~appliedModifications~items)
  assessment~addTrace("after-modifications=" || afterSnapshot~appliedModifications~items)
  assessment~addTrace("newlyApplicable=" || assessment~newlyApplicable~items)
  assessment~addTrace("unresolved=" || assessment~unresolved~items)
  assessment~addTrace("resolvedConflicts=" || assessment~resolvedConflicts~items)
  assessment~addTrace("unresolvedConflicts=" || assessment~unresolvedConflicts~items)
  traceResult = .LegalDecisionTraceBuilder~new~build(assessment)
  if \traceResult~ok then return traceResult
  attachResult = assessment~setDecisionTrace(traceResult~value)
  if \attachResult~ok then return attachResult
  assessment~addTrace("decisionTraceIdentity=" || traceResult~value~traceIdentity)
  return .LegalResult~success(assessment, "legal effect evaluated")

::method resolveApplicableConflicts private
  use arg generation, context, assessment
  groups = .table~new
  ungrouped = .array~new
  do match over assessment~afterMatches
    if match~status <> "APPLIES" then iterate
    key = match~norm~conflictKey
    if key = "" then do
      ungrouped~append(match)
      iterate
    end
    if \groups~hasIndex(key) then groups[key] = .array~new
    groups[key]~append(match)
  end
  do match over ungrouped
    assessment~effectiveMatches~append(match)
  end
  do key over groups
    group = groups[key]
    if group~items = 1 then do
      assessment~effectiveMatches~append(group[1])
      iterate
    end
    unresolvedGroup = .false
    suppressed = .table~new
    i = 1
    do while i <= group~items
      j = i + 1
      do while j <= group~items
        leftMatch = group[i]
        rightMatch = group[j]
        if leftMatch~norm~disposition <> rightMatch~norm~disposition then do
          pairResult = self~resolveConflictPair(generation, context, key, leftMatch, rightMatch)
          if pairResult~status = "RESOLVED" then do
            assessment~resolvedConflicts~append(pairResult)
            suppressed[pairResult~loserMatch~norm~normId] = pairResult~loserMatch
          end
          else do
            assessment~unresolvedConflicts~append(pairResult)
            unresolvedGroup = .true
          end
        end
        j = j + 1
      end
      i = i + 1
    end
    if unresolvedGroup then iterate
    undefeated = .array~new
    do match over group
      if suppressed~hasIndex(match~norm~normId) then assessment~suppressedMatches~append(match)
      else undefeated~append(match)
    end
    if undefeated~items = 0 then do
      cycleReasons = .array~of("authority relations suppress every competing norm; possible precedence cycle")
      cycleResult = .LegalNormConflictResult~new(key, group[1], group[2], "UNRESOLVED", .nil, .nil, .nil, cycleReasons)
      assessment~unresolvedConflicts~append(cycleResult)
      iterate
    end
    do match over undefeated
      assessment~effectiveMatches~append(match)
    end
  end
  return .LegalResult~success

::method resolveConflictPair private
  use arg generation, context, conflictKey, leftMatch, rightMatch
  applicable = .array~new
  unresolvedRules = .array~new
  do rule over generation~authorityRules
    direction = rule~pairDirection(leftMatch~norm, rightMatch~norm)
    if direction = "NO_MATCH" then iterate
    authoritySource = generation~source(rule~authoritySourceId)
    if authoritySource == .nil then do
      reasons = .array~of("authority source missing: " || rule~authoritySourceId)
      return .LegalNormConflictResult~new(conflictKey, leftMatch, rightMatch, "UNRESOLVED", .nil, .nil, .nil, reasons)
    end
    if authoritySource~applicabilityMode = "EXPLICIT" then do
      if \context~isSourceBound(authoritySource~sourceId) then iterate
    end
    authorityMatch = rule~evaluate(context, context~facts, leftMatch~norm, rightMatch~norm)
    if authorityMatch~status = "APPLIES" then applicable~append(authorityMatch)
    if authorityMatch~status = "UNRESOLVED" then unresolvedRules~append(authorityMatch)
  end
  if unresolvedRules~items > 0 then do
    reasons = .array~of("one or more potentially controlling authority rules are unresolved")
    return .LegalNormConflictResult~new(conflictKey, leftMatch, rightMatch, "UNRESOLVED", .nil, .nil, unresolvedRules[1], reasons)
  end
  if applicable~items = 0 then do
    reasons = .array~of("no applicable authority relation resolves conflicting norms")
    return .LegalNormConflictResult~new(conflictKey, leftMatch, rightMatch, "UNRESOLVED", .nil, .nil, .nil, reasons)
  end
  winnerId = applicable[1]~winnerNorm~normId
  do authorityMatch over applicable
    if authorityMatch~winnerNorm~normId <> winnerId then do
      reasons = .array~of("applicable authority relations select different winners")
      return .LegalNormConflictResult~new(conflictKey, leftMatch, rightMatch, "UNRESOLVED", .nil, .nil, authorityMatch, reasons)
    end
  end
  winnerMatch = leftMatch
  loserMatch = rightMatch
  if rightMatch~norm~normId = winnerId then do
    winnerMatch = rightMatch
    loserMatch = leftMatch
  end
  return .LegalNormConflictResult~new(conflictKey, leftMatch, rightMatch, "RESOLVED", winnerMatch, loserMatch, applicable[1])

::method evaluateNormInSnapshot private
  use arg norm, sourceObject, context, snapshot
  if snapshot~hasUnresolvedForNorm(norm) then do
    reasons = .array~of("provision state unresolved because a modifying effect is unresolved")
    return .LegalNormMatch~new(norm, "UNRESOLVED", reasons)
  end
  eligibility = snapshot~normEligibility(norm)
  if eligibility = "DISABLED" then do
    state = snapshot~provisionState(norm~sourceId, norm~provisionId)
    if state == .nil then detail = "provision disabled"
    else detail = "provision state=" || state~status || " materialVersion=" || state~materialVersion
    return .LegalNormMatch~new(norm, "NOT_APPLICABLE", .array~of(detail))
  end
  if sourceObject~applicabilityMode = "EXPLICIT" then do
    if \context~isSourceBound(sourceObject~sourceId) then do
      reasons = .array~of("explicit normative source not bound to context: " || sourceObject~sourceId)
      return .LegalNormMatch~new(norm, "NOT_APPLICABLE", reasons)
    end
  end
  return norm~evaluate(context, context~facts)




/* -------------------------------------------------------------------------
 * Source verification boundary (v0.6)
 *
 * VERIFIED is no longer accepted as a caller assertion.  Verification is
 * evidence produced by LegalSourceVerifier over an explicit byte/text
 * representation of a retained source object.  The representation is hashed;
 * the source object itself is retained in the evidence graph.
 * ------------------------------------------------------------------------- */

::class LegalSourceVerificationAuthority

::class LegalVerificationMaterial public
::attribute sourceObject get
::attribute representation get
::attribute locator get
::attribute material get
::attribute parentObject get

::method init
  expose sourceObject representation locator material parentObject
  use arg sourceObjectArg, representationArg, locatorArg, materialArg, parentObjectArg = .nil
  if sourceObjectArg == .nil then raise syntax 88.900 array("LegalVerificationMaterial requires a retained source object")
  sourceObject = sourceObjectArg
  representation = representationArg~string~upper
  locator = locatorArg~string
  material = materialArg
  parentObject = parentObjectArg

::method fromText class
  use arg sourceObject, text, locator = "memory:text", representation = "RAW_TEXT"
  return self~new(sourceObject, representation, locator, text, .nil)

::method fromXmlDocument class
  use arg document
  if document == .nil then raise syntax 88.900 array("XML document required")
  if \document~hasMethod("SOURCETEXT") then raise syntax 88.900 array("Object does not expose sourceText")
  locator = ""
  if document~hasMethod("SOURCE") then locator = document~source
  return self~new(document, "XML_SOURCE_TEXT", locator, document~sourceText, .nil)

::method fromXmlNode class
  use arg node
  if node == .nil then raise syntax 88.900 array("XML node required")
  if \node~hasMethod("DOCUMENT") then raise syntax 88.900 array("Object is not a source-spanned XML node")
  if \node~hasMethod("SPAN") then raise syntax 88.900 array("Object is not a source-spanned XML node")
  span = node~span
  if span == .nil then raise syntax 88.900 array("XML node has no source span")
  document = node~document
  length = span~endOffset - span~startOffset + 1
  bytes = document~sourceText~substr(span~startOffset, length)
  locator = ""
  if node~hasMethod("PATH") then locator = node~path
  return self~new(node, "XML_SOURCE_SPAN", locator, bytes, document)

::method fromGitFileRevision class
  use arg revision
  if revision == .nil then raise syntax 88.900 array("Git file revision required")
  if \revision~hasMethod("CONTENT") then raise syntax 88.900 array("Object does not expose Git blob content")
  locator = ""
  if revision~hasMethod("PATH") then locator = revision~path
  return self~new(revision, "GIT_BLOB_CONTENT", locator, revision~content, revision~repository)

::method fromGitSourceSpan class
  use arg span
  if span == .nil then raise syntax 88.900 array("Git source span required")
  if \span~hasMethod("LEXICALVALUE") then raise syntax 88.900 array("Object does not expose lexical source bytes")
  locator = ""
  if span~hasMethod("PATH") then locator = span~path
  parent = .nil
  if span~hasMethod("FILEREVISION") then parent = span~fileRevision
  return self~new(span, "GIT_SOURCE_SPAN", locator, span~lexicalValue, parent)

::method fromLexicalObject class
  use arg sourceObject, locator = ""
  if sourceObject == .nil then raise syntax 88.900 array("Lexical source object required")
  if \sourceObject~hasMethod("LEXICALVALUE") then raise syntax 88.900 array("Object does not expose lexicalValue")
  if locator = "" then do
    if sourceObject~hasMethod("PATH") then locator = sourceObject~path
  end
  return self~new(sourceObject, "LEXICAL_VALUE", locator, sourceObject~lexicalValue, .nil)

::method materialLength
  expose material
  if material == .nil then return 0
  return material~length

::method provenance
  expose sourceObject representation locator parentObject
  p = .table~new
  p["kind"] = "LEGAL_VERIFICATION_MATERIAL"
  p["sourceObject"] = sourceObject
  p["representation"] = representation
  p["locator"] = locator
  p["parentObject"] = parentObject
  p["materialLength"] = self~materialLength
  return p


::class LegalSourceVerificationEvidence public
::attribute subjectKind get
::attribute sourceId get
::attribute provisionId get
::attribute expressionId get
::attribute locator get
::attribute algorithm get
::attribute expectedDigest get
::attribute actualDigest get
::attribute verified get
::attribute statusCode get
::attribute detail get
::attribute sourceObject get
::attribute materialRepresentation get
::attribute materialLength get
::attribute verifierId get
::attribute verifiedAt get
::attribute parentEvidence get

::method init
  expose subjectKind sourceId provisionId expressionId locator algorithm expectedDigest actualDigest verified statusCode detail sourceObject materialRepresentation materialLength verifierId verifiedAt parentEvidence
  use arg subjectKindArg, sourceIdArg, provisionIdArg, expressionIdArg, materialArg, algorithmArg, expectedDigestArg, actualDigestArg, verifiedArg, statusCodeArg, detailArg, verifierIdArg, parentEvidenceArg = .nil, authority = .nil
  if authority \== .LegalSourceVerificationAuthority then raise syntax 88.900 array("LegalSourceVerificationEvidence may only be produced by LegalSourceVerifier")
  subjectKind = subjectKindArg~string~upper
  sourceId = sourceIdArg~string
  provisionId = provisionIdArg~string
  expressionId = expressionIdArg~string
  locator = materialArg~locator
  algorithm = algorithmArg~string~upper
  expectedDigest = expectedDigestArg~string~lower
  actualDigest = actualDigestArg~string~lower
  verified = verifiedArg
  statusCode = statusCodeArg~string~upper
  detail = detailArg~string
  sourceObject = materialArg~sourceObject
  materialRepresentation = materialArg~representation
  materialLength = materialArg~materialLength
  verifierId = verifierIdArg~string
  verifiedAt = .DateTime~new~utcIsoDate
  parentEvidence = parentEvidenceArg

::method evidenceIdentity
  expose subjectKind sourceId provisionId expressionId actualDigest materialRepresentation locator
  return "legal-verification/" || subjectKind || "/" || sourceId || "/" || provisionId || "/" || expressionId || "/" || actualDigest || "/" || materialRepresentation || "/" || locator

::method provenance
  expose subjectKind sourceId provisionId expressionId locator algorithm expectedDigest actualDigest verified statusCode detail sourceObject materialRepresentation materialLength verifierId verifiedAt parentEvidence
  p = .table~new
  p["kind"] = "LEGAL_SOURCE_VERIFICATION_EVIDENCE"
  p["subjectKind"] = subjectKind
  p["sourceId"] = sourceId
  p["provisionId"] = provisionId
  p["expressionId"] = expressionId
  p["locator"] = locator
  p["algorithm"] = algorithm
  p["expectedDigest"] = expectedDigest
  p["actualDigest"] = actualDigest
  p["verified"] = verified
  p["statusCode"] = statusCode
  p["detail"] = detail
  p["sourceObject"] = sourceObject
  p["materialRepresentation"] = materialRepresentation
  p["materialLength"] = materialLength
  p["verifierId"] = verifierId
  p["verifiedAt"] = verifiedAt
  p["parentEvidence"] = parentEvidence
  return p

::method string
  expose subjectKind sourceId provisionId verified actualDigest
  return "LEGAL-VERIFY[" || subjectKind || ":" || sourceId || ":" || provisionId || "] verified=" || verified || " digest=" || actualDigest


::class LegalSourceVerifier subclass LegalAlchemyObject public
::attribute digestProvider get
::attribute verifierId get

::method init
  expose digestProvider verifierId
  use arg digestProviderArg, verifierIdArg = "legal-source-verifier", alchemySealer = .nil, alchemyAuthority = .nil
  if digestProviderArg == .nil then raise syntax 88.900 array("LegalSourceVerifier requires a digest provider")
  digestProvider = digestProviderArg
  verifierId = verifierIdArg~string
  self~initLegalAlchemy("LEGALSOURCEVERIFIER", alchemySealer, alchemyAuthority)
  self~registerStateVariable("verifierId", "CUSTOMER", "source representation verifier identity")
  ignored = self~recordRelationship("DIGEST_PROVIDER", digestProvider, "source representation verification", "INTERNAL")

::method verifySource
  expose digestProvider verifierId
  use arg identity, material
  self~alchemyTouch("VERIFY_SOURCE")
  if identity == .nil then raise syntax 88.900 array("LegalSourceIdentity required")
  return self~verify("SOURCE", identity~sourceId, "", identity~expressionId, identity~contentDigest, material, .nil)

::method verifyProvision
  expose digestProvider verifierId
  use arg reference, material, parentEvidence = .nil
  self~alchemyTouch("VERIFY_PROVISION")
  if reference == .nil then raise syntax 88.900 array("LegalProvisionReference required")
  return self~verify("PROVISION", reference~sourceId, reference~provisionId, reference~expressionId, reference~contentDigest, material, parentEvidence)

::method verify private
  expose digestProvider verifierId
  use arg subjectKind, sourceId, provisionId, expressionId, expectedDigest, material, parentEvidence
  expected = expectedDigest~string~lower
  algorithm = digestProvider~algorithm~upper
  prefix = algorithm~lower || ":"
  statusCode = "VERIFIED"
  detail = ""
  verified = .false
  actual = ""

  if material == .nil then do
    statusCode = "VERIFICATION_MATERIAL_REQUIRED"
    detail = "No verification material supplied"
  end
  else do
    gitFailure = self~gitAttestationFailure(material)
    if gitFailure <> "" then do
      statusCode = gitFailure
      detail = self~gitAttestationDetail(material, gitFailure)
    end
    else if expected~left(prefix~length) \= prefix then do
      statusCode = "DIGEST_ALGORITHM_MISMATCH"
      detail = "Expected digest must use " || prefix
    end
    else do
      actualHex = digestProvider~digest(material~material)
      actual = prefix || actualHex~lower
      if actual = expected then verified = .true
      else do
        statusCode = "DIGEST_MISMATCH"
        detail = "Expected " || expected || " but calculated " || actual
      end
    end
  end
  if material == .nil then material = .LegalVerificationMaterial~fromText(.LegalCanonical, "", "missing:material", "MISSING")
  return .LegalSourceVerificationEvidence~new(subjectKind, sourceId, provisionId, expressionId, material, algorithm, expected, actual, verified, statusCode, detail, verifierId, parentEvidence, .LegalSourceVerificationAuthority)

::method gitAttestationFailure private
  use arg material
  if material == .nil then return ""
  representation = material~representation
  isGitRepresentation = .false
  if representation = "GIT_BLOB_CONTENT" then isGitRepresentation = .true
  else if representation = "GIT_SOURCE_SPAN" then isGitRepresentation = .true
  if \isGitRepresentation then return ""

  revision = .nil
  sourceObject = material~sourceObject
  if sourceObject \== .nil then do
    if sourceObject~hasMethod("BLOBVERIFICATIONSTATE") then revision = sourceObject
  end
  if revision == .nil then do
    parentObject = material~parentObject
    if parentObject \== .nil then do
      if parentObject~hasMethod("BLOBVERIFICATIONSTATE") then revision = parentObject
    end
  end

  /* Local GitFileRevision objects are sourced from Git's object database and
   * do not expose the remote-claim state machine.  The extra gate applies only
   * when the source object explicitly models a remote blob claim. */
  if revision == .nil then return ""

  state = revision~blobVerificationState~string~upper
  select
    when state = "VERIFIED" then return ""
    when state = "MISMATCH" then return "GIT_BLOB_ATTESTATION_MISMATCH"
    when state = "VERIFICATION_FAILED" then return "GIT_BLOB_ATTESTATION_UNAVAILABLE"
    when state = "CLAIMED" then return "GIT_BLOB_ATTESTATION_REQUIRED"
    when state = "UNBOUND" then return "GIT_BLOB_IDENTITY_REQUIRED"
    otherwise return "GIT_BLOB_ATTESTATION_REQUIRED"
  end

::method gitAttestationDetail private
  use arg material, failureCode
  sourceObject = material~sourceObject
  revision = .nil
  if sourceObject \== .nil then do
    if sourceObject~hasMethod("BLOBVERIFICATIONSTATE") then revision = sourceObject
  end
  if revision == .nil then do
    parentObject = material~parentObject
    if parentObject \== .nil then do
      if parentObject~hasMethod("BLOBVERIFICATIONSTATE") then revision = parentObject
    end
  end
  if revision == .nil then return failureCode
  claimed = ""
  computed = ""
  if revision~hasMethod("BLOBSHA") then claimed = revision~blobSha
  if revision~hasMethod("COMPUTEDBLOBSHA") then computed = revision~computedBlobSha
  return failureCode || " state=" || revision~blobVerificationState || " claimed=" || claimed || " computed=" || computed

::method bindSource
  use arg identity, material
  if identity~verificationEvidence \== .nil then return identity~verificationEvidence
  evidence = self~verifySource(identity, material)
  bindResult = identity~bindVerificationEvidence(evidence, .LegalSourceVerificationAuthority)
  if \bindResult~ok then return identity~verificationEvidence
  return evidence

::method bindProvision
  use arg reference, material, parentEvidence = .nil
  if reference~verificationEvidence \== .nil then return reference~verificationEvidence
  evidence = self~verifyProvision(reference, material, parentEvidence)
  bindResult = reference~bindVerificationEvidence(evidence, .LegalSourceVerificationAuthority)
  if \bindResult~ok then return reference~verificationEvidence
  return evidence


/* -------------------------------------------------------------------------
 * Source-anchored compiler boundary (v0.4)
 * ------------------------------------------------------------------------- */

::class LegalCompilationAuthority



/* -------------------------------------------------------------------------
 * Source authority attestation boundary (v0.10)
 *
 * Digest verification answers "these are the bytes".  Authority attestation
 * answers "a trusted signer, under a host-owned policy, authorised these exact
 * source identity claims".  Attestation proof is provenance, not legal
 * semantic identity.
 * ------------------------------------------------------------------------- */

::class LegalSourceAuthorityBindingAuthority

::class LegalSourceAuthorityClaim public
::attribute claimId get
::attribute policyId get
::attribute sourceId get
::attribute sourceKind get
::attribute expressionId get
::attribute canonicalUri get
::attribute contentDigest get
::attribute authority get
::attribute jurisdictionId get
::attribute issuedAt get
::attribute publicationRef get

::method init
  expose claimId policyId sourceId sourceKind expressionId canonicalUri contentDigest authority jurisdictionId issuedAt publicationRef
  use arg claimIdArg, policyIdArg, sourceIdArg, sourceKindArg, expressionIdArg, canonicalUriArg, contentDigestArg, authorityArg, jurisdictionArg, issuedAtArg = "", publicationRefArg = ""
  claimId = claimIdArg~string
  policyId = policyIdArg~string
  sourceId = sourceIdArg~string
  sourceKind = sourceKindArg~string~upper
  expressionId = expressionIdArg~string
  canonicalUri = canonicalUriArg~string
  contentDigest = contentDigestArg~string~lower
  authority = authorityArg~string
  jurisdictionId = jurisdictionArg~string~upper
  issuedAt = issuedAtArg~string
  publicationRef = publicationRefArg~string

::method canonicalText
  expose claimId policyId sourceId sourceKind expressionId canonicalUri contentDigest authority jurisdictionId issuedAt publicationRef
  text = "LEGAL-SOURCE-AUTHORITY-CLAIM/1"
  text ||= .LegalCanonical~field("CLAIM_ID", claimId)
  text ||= .LegalCanonical~field("POLICY_ID", policyId)
  text ||= .LegalCanonical~field("SOURCE_ID", sourceId)
  text ||= .LegalCanonical~field("SOURCE_KIND", sourceKind)
  text ||= .LegalCanonical~field("EXPRESSION_ID", expressionId)
  text ||= .LegalCanonical~field("URI", canonicalUri)
  text ||= .LegalCanonical~field("DIGEST", contentDigest)
  text ||= .LegalCanonical~field("AUTHORITY", authority)
  text ||= .LegalCanonical~field("JURISDICTION", jurisdictionId)
  text ||= .LegalCanonical~field("ISSUED_AT", issuedAt)
  text ||= .LegalCanonical~field("PUBLICATION_REF", publicationRef)
  return text

::method matchesIdentity
  expose sourceId sourceKind expressionId canonicalUri contentDigest authority jurisdictionId
  use arg identity
  if identity == .nil then return .false
  if sourceId <> identity~sourceId then return .false
  if sourceKind <> identity~sourceKind then return .false
  if expressionId <> identity~expressionId then return .false
  if canonicalUri <> identity~canonicalUri then return .false
  if contentDigest <> identity~contentDigest then return .false
  if authority <> identity~authority then return .false
  return jurisdictionId = identity~jurisdictionId

::method evidenceIdentity
  expose claimId sourceId expressionId contentDigest policyId
  return "legal-source-authority-claim/" || claimId || "/" || policyId || "/" || sourceId || "/" || expressionId || "/" || contentDigest


::class LegalSourceAuthoritySignature public
::attribute signerId get
::attribute algorithm get
::attribute signatureValue get

::method init
  expose signerId algorithm signatureValue
  use arg signerIdArg, algorithmArg, signatureArg
  signerId = signerIdArg~string
  algorithm = algorithmArg~string~upper
  signatureValue = signatureArg~string

::method canonicalText
  expose signerId algorithm signatureValue
  text = .LegalCanonical~field("SIGNER_ID", signerId)
  text ||= .LegalCanonical~field("ALGORITHM", algorithm)
  text ||= .LegalCanonical~field("SIGNATURE", signatureValue)
  return text


::class LegalSourceAuthorityAttestation public
::attribute claim get

::method init
  expose claim signatures
  use arg claimArg, signaturesArg = .nil
  if claimArg == .nil then raise syntax 88.900 array("LegalSourceAuthorityAttestation requires a claim")
  if claimArg~class \== .LegalSourceAuthorityClaim then raise syntax 88.900 array("LegalSourceAuthorityClaim exact class required")
  claim = claimArg
  signatures = .array~new
  if signaturesArg \== .nil then do signature over signaturesArg
    if signature == .nil then raise syntax 88.900 array("Authority signature must not be .nil")
    if signature~class \== .LegalSourceAuthoritySignature then raise syntax 88.900 array("LegalSourceAuthoritySignature exact class required")
    signatures~append(signature)
  end

::method signatures
  expose signatures
  copy = .array~new
  do signature over signatures
    copy~append(signature)
  end
  return copy

::method canonicalText
  expose claim signatures
  text = claim~canonicalText
  signatureText = .array~new
  do signature over signatures
    signatureText~append(signature~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("SIGNATURE", signatureText)
  return text

::method evidenceIdentity
  expose claim
  return "legal-source-authority-attestation/" || claim~claimId || "/" || claim~sourceId || "/" || claim~policyId


::class LegalTrustedSourceSigner public
::attribute signerId get
::attribute publicKey get
::attribute revoked get

::method init
  expose signerId publicKey sourceKinds authorities jurisdictions revoked
  use arg signerIdArg, publicKeyArg, sourceKindsArg = .nil, authoritiesArg = .nil, jurisdictionsArg = .nil
  signerId = signerIdArg~string~strip
  publicKey = publicKeyArg~string~space(0)~lower
  if signerId = "" then raise syntax 88.900 array("LegalTrustedSourceSigner signerId must not be empty")
  if publicKey = "" then raise syntax 88.900 array("LegalTrustedSourceSigner public key must not be empty")
  sourceKinds = self~copyStrings(sourceKindsArg, .true)
  authorities = self~copyStrings(authoritiesArg, .true)
  jurisdictions = self~copyStrings(jurisdictionsArg, .true)
  revoked = .false

::method copyStrings private
  use arg source, upperValues
  out = .array~new
  if source == .nil then return out
  do value over source
    item = value~string~strip
    if upperValues then item = item~upper
    if item <> "" then out~append(item)
  end
  return out

::method allows
  expose sourceKinds authorities jurisdictions revoked
  use arg identity
  if revoked then return .false
  if identity == .nil then return .false
  if \self~matches(sourceKinds, identity~sourceKind~upper) then return .false
  if \self~matches(authorities, identity~authority~upper) then return .false
  return self~matches(jurisdictions, identity~jurisdictionId~upper)

::method matches private
  use arg allowed, value
  if allowed~items = 0 then return .true
  do item over allowed
    if item = "*" then return .true
    if item = value then return .true
  end
  return .false

::method revoke
  expose revoked
  revoked = .true
  return .true


::class LegalSourceAuthorityPolicy public
::attribute policyId get
::attribute minimumSignatures get

::method init
  expose policyId minimumSignatures requiredSignerIds
  use arg policyIdArg, minimumSignaturesArg = 1, requiredSignerIdsArg = .nil
  policyId = policyIdArg~string
  minimumSignatures = minimumSignaturesArg
  if minimumSignatures < 1 then raise syntax 88.900 array("Source authority policy minimum signatures must be >= 1")
  requiredSignerIds = .array~new
  if requiredSignerIdsArg \== .nil then do signerId over requiredSignerIdsArg
    requiredSignerIds~append(signerId~string)
  end

::method requiredSignerIds
  expose requiredSignerIds
  copy = .array~new
  do signerId over requiredSignerIds
    copy~append(signerId)
  end
  return copy

::method canonicalText
  expose policyId minimumSignatures requiredSignerIds
  text = .LegalCanonical~field("POLICY_ID", policyId)
  text ||= .LegalCanonical~field("MINIMUM_SIGNATURES", minimumSignatures)
  text ||= .LegalCanonical~joinCanonical("REQUIRED_SIGNER", requiredSignerIds)
  return text


::class LegalSourceAuthorityTrustProfile subclass LegalAlchemyObject public
::attribute profileId get

::method init
  expose profileId signers policies keyOwners
  use arg profileIdArg = "legal-source-authority", alchemySealer = .nil, alchemyAuthority = .nil
  profileId = profileIdArg~string
  signers = .table~new
  policies = .table~new
  keyOwners = .table~new
  self~initLegalAlchemy("LEGALSOURCEAUTHORITYTRUSTPROFILE", alchemySealer, alchemyAuthority)
  self~registerStateVariable("profileId", "CUSTOMER", "host-owned source authority trust profile id")

::method addSigner
  expose signers keyOwners
  use arg signer
  self~alchemyTouch("ADD_SIGNER")
  guard on
  if signer == .nil then return .LegalResult~failure("SOURCE_AUTHORITY_SIGNER_REQUIRED", "")
  if signer~class \== .LegalTrustedSourceSigner then return .LegalResult~failure("SOURCE_AUTHORITY_SIGNER_CLASS_REQUIRED", signer~class~id~string)
  if signers~hasIndex(signer~signerId) then return .LegalResult~failure("SOURCE_AUTHORITY_SIGNER_DUPLICATE", signer~signerId)
  key = signer~publicKey~space(0)~lower
  existingOwner = keyOwners[key]
  if existingOwner \== .nil then return .LegalResult~failure("SOURCE_AUTHORITY_DUPLICATE_KEY", existingOwner || "/" || signer~signerId)
  signers[signer~signerId] = signer
  keyOwners[key] = signer~signerId
  return .LegalResult~success(signer)

::method addPolicy
  expose policies
  use arg policy
  self~alchemyTouch("ADD_POLICY")
  guard on
  if policy == .nil then return .LegalResult~failure("SOURCE_AUTHORITY_POLICY_REQUIRED", "")
  if policy~class \== .LegalSourceAuthorityPolicy then return .LegalResult~failure("SOURCE_AUTHORITY_POLICY_CLASS_REQUIRED", policy~class~id~string)
  if policies~hasIndex(policy~policyId) then return .LegalResult~failure("SOURCE_AUTHORITY_POLICY_DUPLICATE", policy~policyId)
  policies[policy~policyId] = policy
  return .LegalResult~success(policy)

::method signer
  expose signers
  use arg signerId
  guard on
  return signers[signerId~string]

::method policy
  expose policies
  use arg policyId
  guard on
  return policies[policyId~string]

::method revokeSigner
  expose signers
  use arg signerId
  guard on
  signer = signers[signerId~string]
  if signer == .nil then return .LegalResult~failure("SOURCE_AUTHORITY_SIGNER_UNTRUSTED", signerId~string)
  ignored = signer~revoke
  return .LegalResult~success(signer)


::class LegalSourceAuthorityVerificationEvidence public
::attribute sourceId get
::attribute claimId get
::attribute policyId get
::attribute trustProfileId get
::attribute verified get
::attribute statusCode get
::attribute detail get
::attribute checkedAt get

::method init
  expose sourceId claimId policyId trustProfileId verified statusCode detail checkedAt verifiedSignerIds
  use arg sourceIdArg, claimIdArg, policyIdArg, trustProfileIdArg, verifiedArg, statusCodeArg, detailArg = "", verifiedSignerIdsArg = .nil
  sourceId = sourceIdArg~string
  claimId = claimIdArg~string
  policyId = policyIdArg~string
  trustProfileId = trustProfileIdArg~string
  verified = verifiedArg
  statusCode = statusCodeArg~string~upper
  detail = detailArg~string
  verifiedSignerIds = .array~new
  if verifiedSignerIdsArg \== .nil then do signerId over verifiedSignerIdsArg
    verifiedSignerIds~append(signerId~string)
  end
  checkedAt = .DateTime~new

::method verifiedSignerIds
  expose verifiedSignerIds
  copy = .array~new
  do signerId over verifiedSignerIds
    copy~append(signerId)
  end
  return copy

::method provenance
  expose sourceId claimId policyId trustProfileId verified statusCode detail checkedAt
  p = .table~new
  p["kind"] = "LEGAL_SOURCE_AUTHORITY_VERIFICATION"
  p["sourceId"] = sourceId
  p["claimId"] = claimId
  p["policyId"] = policyId
  p["trustProfileId"] = trustProfileId
  p["verified"] = verified
  p["statusCode"] = statusCode
  p["detail"] = detail
  p["verifiedSignerIds"] = self~verifiedSignerIds
  p["checkedAt"] = checkedAt
  return p


::class LegalSourceAuthorityVerifier subclass LegalAlchemyObject public
::attribute signatureProvider get

::method init
  expose signatureProvider
  use arg signatureProviderArg, alchemySealer = .nil, alchemyAuthority = .nil
  if signatureProviderArg == .nil then raise syntax 88.900 array("LegalSourceAuthorityVerifier requires a signature provider")
  signatureProvider = signatureProviderArg
  self~initLegalAlchemy("LEGALSOURCEAUTHORITYVERIFIER", alchemySealer, alchemyAuthority)
  ignored = self~recordRelationship("SIGNATURE_PROVIDER", signatureProvider, "source authority signature verification", "INTERNAL")

::method verify
  expose signatureProvider
  use arg identity, attestation, trustProfile
  self~alchemyTouch("VERIFY_AUTHORITY")
  sourceId = ""
  claimId = ""
  policyId = ""
  profileId = ""
  if identity \== .nil then sourceId = identity~sourceId
  if attestation \== .nil then do
    if attestation~hasMethod("CLAIM") then do
      claimId = attestation~claim~claimId
      policyId = attestation~claim~policyId
    end
  end
  if trustProfile \== .nil then do
    if trustProfile~hasMethod("PROFILEID") then profileId = trustProfile~profileId
  end

  if identity == .nil then return self~failure(sourceId, claimId, policyId, profileId, "SOURCE_AUTHORITY_IDENTITY_REQUIRED", "")
  if identity~class~id~string~upper <> "LEGALSOURCEIDENTITY" then return self~failure(sourceId, claimId, policyId, profileId, "SOURCE_AUTHORITY_IDENTITY_CLASS_REQUIRED", identity~class~id~string)
  if attestation == .nil then return self~failure(sourceId, claimId, policyId, profileId, "SOURCE_AUTHORITY_ATTESTATION_REQUIRED", "")
  if attestation~class~id~string~upper <> "LEGALSOURCEAUTHORITYATTESTATION" then return self~failure(sourceId, claimId, policyId, profileId, "SOURCE_AUTHORITY_ATTESTATION_CLASS_REQUIRED", attestation~class~id~string)
  if trustProfile == .nil then return self~failure(sourceId, claimId, policyId, profileId, "SOURCE_AUTHORITY_TRUST_PROFILE_REQUIRED", "")
  if trustProfile~class \== .LegalSourceAuthorityTrustProfile then return self~failure(sourceId, claimId, policyId, profileId, "SOURCE_AUTHORITY_TRUST_PROFILE_CLASS_REQUIRED", trustProfile~class~id~string)

  claim = attestation~claim
  if claim == .nil then return self~failure(sourceId, claimId, policyId, profileId, "SOURCE_AUTHORITY_CLAIM_REQUIRED", "")
  if claim~class~id~string~upper <> "LEGALSOURCEAUTHORITYCLAIM" then return self~failure(sourceId, claimId, policyId, profileId, "SOURCE_AUTHORITY_CLAIM_CLASS_REQUIRED", claim~class~id~string)
  if \self~claimMatchesIdentity(identity, claim) then return self~failure(sourceId, claimId, policyId, profileId, "SOURCE_AUTHORITY_CLAIM_MISMATCH", self~claimCanonicalText(claim))
  policy = trustProfile~policy(claim~policyId)
  if policy == .nil then return self~failure(sourceId, claimId, policyId, profileId, "SOURCE_AUTHORITY_POLICY_UNTRUSTED", claim~policyId)

  verifiedSignerIds = .array~new
  seenSigners = .table~new
  do signature over attestation~signatures
    if signature == .nil then iterate
    if signature~class~id~string~upper <> "LEGALSOURCEAUTHORITYSIGNATURE" then iterate
    signerId = signature~signerId
    if seenSigners~hasIndex(signerId) then iterate
    seenSigners[signerId] = .true
    signer = trustProfile~signer(signerId)
    if signer == .nil then iterate
    if signer~revoked then iterate
    if \signer~allows(identity) then iterate
    if signature~algorithm <> signatureProvider~algorithm~upper then iterate
    valid = signatureProvider~verify(self~claimCanonicalText(claim), signature~signatureValue, signer~publicKey)
    if valid then verifiedSignerIds~append(signerId)
  end

  do requiredSignerId over policy~requiredSignerIds
    found = .false
    do verifiedSignerId over verifiedSignerIds
      if verifiedSignerId = requiredSignerId then found = .true
    end
    if \found then return self~failure(sourceId, claimId, policyId, profileId, "SOURCE_AUTHORITY_REQUIRED_SIGNER_MISSING", requiredSignerId, verifiedSignerIds)
  end

  if verifiedSignerIds~items < policy~minimumSignatures then return self~failure(sourceId, claimId, policyId, profileId, "SOURCE_AUTHORITY_SIGNATURE_THRESHOLD_NOT_MET", verifiedSignerIds~items || "/" || policy~minimumSignatures, verifiedSignerIds)
  return .LegalSourceAuthorityVerificationEvidence~new(sourceId, claimId, policyId, profileId, .true, "VERIFIED", "host trust policy satisfied", verifiedSignerIds)

::method claimMatchesIdentity private
  use arg identity, claim
  if claim~sourceId <> identity~sourceId then return .false
  if claim~sourceKind~upper <> identity~sourceKind~upper then return .false
  if claim~expressionId <> identity~expressionId then return .false
  if claim~canonicalUri <> identity~canonicalUri then return .false
  if claim~contentDigest~lower <> identity~contentDigest~lower then return .false
  if claim~authority <> identity~authority then return .false
  return claim~jurisdictionId~upper = identity~jurisdictionId~upper

::method claimCanonicalText private
  use arg claim
  text = "LEGAL-SOURCE-AUTHORITY-CLAIM/1"
  text ||= .LegalCanonical~field("CLAIM_ID", claim~claimId)
  text ||= .LegalCanonical~field("POLICY_ID", claim~policyId)
  text ||= .LegalCanonical~field("SOURCE_ID", claim~sourceId)
  text ||= .LegalCanonical~field("SOURCE_KIND", claim~sourceKind~upper)
  text ||= .LegalCanonical~field("EXPRESSION_ID", claim~expressionId)
  text ||= .LegalCanonical~field("URI", claim~canonicalUri)
  text ||= .LegalCanonical~field("DIGEST", claim~contentDigest~lower)
  text ||= .LegalCanonical~field("AUTHORITY", claim~authority)
  text ||= .LegalCanonical~field("JURISDICTION", claim~jurisdictionId~upper)
  text ||= .LegalCanonical~field("ISSUED_AT", claim~issuedAt)
  text ||= .LegalCanonical~field("PUBLICATION_REF", claim~publicationRef)
  return text

::method failure private
  use arg sourceId, claimId, policyId, profileId, code, detail = "", verifiedSignerIds = .nil
  return .LegalSourceAuthorityVerificationEvidence~new(sourceId, claimId, policyId, profileId, .false, code, detail, verifiedSignerIds)


::class LegalSourceIdentity public
::attribute sourceId get
::attribute sourceKind get
::attribute expressionId get
::attribute canonicalUri get
::attribute contentDigest get
::attribute authority get
::attribute jurisdictionId get
::attribute verificationState get
::attribute assertedVerificationState get
::attribute verificationEvidence get

::method init
  expose sourceId sourceKind expressionId canonicalUri contentDigest authority jurisdictionId verificationState assertedVerificationState verificationEvidence authorityAttestations
  use arg sourceIdArg, sourceKindArg, expressionIdArg, canonicalUriArg, contentDigestArg, authorityArg = "", jurisdictionArg = "*", verificationArg = "UNVERIFIED"
  sourceId = sourceIdArg~string
  sourceKind = sourceKindArg~string~upper
  expressionId = expressionIdArg~string
  canonicalUri = canonicalUriArg~string
  contentDigest = contentDigestArg~string~lower
  authority = authorityArg~string
  jurisdictionId = jurisdictionArg~string~upper
  assertedVerificationState = verificationArg~string~upper
  verificationState = "UNVERIFIED"
  verificationEvidence = .nil
  authorityAttestations = .array~new

::method bindVerificationEvidence
  expose sourceId expressionId contentDigest verificationState verificationEvidence
  use arg evidence, authority = .nil
  if authority \== .LegalSourceVerificationAuthority then return .LegalResult~failure("SOURCE_VERIFICATION_AUTHORITY_REQUIRED", sourceId)
  if evidence == .nil then return .LegalResult~failure("SOURCE_VERIFICATION_EVIDENCE_REQUIRED", sourceId)
  if verificationEvidence \== .nil then return .LegalResult~failure("SOURCE_VERIFICATION_ALREADY_BOUND", sourceId)
  if evidence~subjectKind <> "SOURCE" then return .LegalResult~failure("SOURCE_VERIFICATION_KIND_MISMATCH", evidence~subjectKind)
  if evidence~sourceId <> sourceId then return .LegalResult~failure("SOURCE_VERIFICATION_ID_MISMATCH", evidence~sourceId)
  if evidence~expressionId <> expressionId then return .LegalResult~failure("SOURCE_VERIFICATION_EXPRESSION_MISMATCH", evidence~expressionId)
  if evidence~expectedDigest <> contentDigest then return .LegalResult~failure("SOURCE_VERIFICATION_DIGEST_IDENTITY_MISMATCH", evidence~expectedDigest)
  verificationEvidence = evidence
  if evidence~verified then verificationState = "VERIFIED"
  else verificationState = "UNVERIFIED"
  return .LegalResult~success(evidence)


::method bindAuthorityAttestation
  expose sourceId authorityAttestations
  use arg attestation, authorityToken = .nil
  if authorityToken \== .LegalSourceAuthorityBindingAuthority then return .LegalResult~failure("SOURCE_AUTHORITY_BINDING_AUTHORITY_REQUIRED", sourceId)
  if attestation == .nil then return .LegalResult~failure("SOURCE_AUTHORITY_ATTESTATION_REQUIRED", sourceId)
  if attestation~class \== .LegalSourceAuthorityAttestation then return .LegalResult~failure("SOURCE_AUTHORITY_ATTESTATION_CLASS_REQUIRED", attestation~class~id~string)
  if \attestation~claim~matchesIdentity(self) then return .LegalResult~failure("SOURCE_AUTHORITY_CLAIM_MISMATCH", sourceId)
  do existing over authorityAttestations
    if existing~canonicalText = attestation~canonicalText then return .LegalResult~failure("SOURCE_AUTHORITY_ATTESTATION_DUPLICATE", sourceId)
  end
  authorityAttestations~append(attestation)
  return .LegalResult~success(attestation)

::method authorityAttestations
  expose authorityAttestations
  copy = .array~new
  do attestation over authorityAttestations
    copy~append(attestation)
  end
  return copy

::method authorityAttestationCount
  expose authorityAttestations
  return authorityAttestations~items

::method authorityAttestationCanonicalText
  expose authorityAttestations
  texts = .array~new
  do attestation over authorityAttestations
    texts~append(attestation~canonicalText)
  end
  return .LegalCanonical~joinCanonical("SOURCE_AUTHORITY_ATTESTATION", texts)

::method cryptographicallyVerified
  expose verificationState verificationEvidence
  if verificationState <> "VERIFIED" then return .false
  if verificationEvidence == .nil then return .false
  if \verificationEvidence~hasMethod("VERIFIED") then return .false
  return verificationEvidence~verified

::method isComplete
  expose sourceId sourceKind expressionId canonicalUri contentDigest
  if sourceId = "" then return .false
  if sourceKind = "" then return .false
  if expressionId = "" then return .false
  if canonicalUri = "" then return .false
  return contentDigest <> ""

::method evidenceIdentity
  expose sourceId expressionId contentDigest
  return "legal-source/" || sourceId || "/" || expressionId || "/" || contentDigest

::method canonicalText
  expose sourceId sourceKind expressionId canonicalUri contentDigest authority jurisdictionId verificationState
  text = .LegalCanonical~field("SOURCE_ID", sourceId)
  text ||= .LegalCanonical~field("SOURCE_KIND", sourceKind)
  text ||= .LegalCanonical~field("EXPRESSION_ID", expressionId)
  text ||= .LegalCanonical~field("URI", canonicalUri)
  text ||= .LegalCanonical~field("DIGEST", contentDigest)
  text ||= .LegalCanonical~field("AUTHORITY", authority)
  text ||= .LegalCanonical~field("JURISDICTION", jurisdictionId)
  text ||= .LegalCanonical~field("VERIFICATION", verificationState)
  return text


::class LegalProvisionReference public
::attribute sourceId get
::attribute provisionId get
::attribute expressionId get
::attribute locator get
::attribute contentDigest get
::attribute lexicalText get
::attribute verificationState get
::attribute assertedVerificationState get
::attribute verificationEvidence get

::method init
  expose sourceId provisionId expressionId locator contentDigest lexicalText verificationState assertedVerificationState verificationEvidence
  use arg sourceIdArg, provisionIdArg, expressionIdArg, locatorArg, contentDigestArg, lexicalTextArg = "", verificationArg = "UNVERIFIED"
  sourceId = sourceIdArg~string
  provisionId = provisionIdArg~string
  expressionId = expressionIdArg~string
  locator = locatorArg~string
  contentDigest = contentDigestArg~string~lower
  lexicalText = lexicalTextArg~string
  assertedVerificationState = verificationArg~string~upper
  verificationState = "UNVERIFIED"
  verificationEvidence = .nil

::method bindVerificationEvidence
  expose sourceId provisionId expressionId contentDigest verificationState verificationEvidence
  use arg evidence, authority = .nil
  if authority \== .LegalSourceVerificationAuthority then return .LegalResult~failure("PROVISION_VERIFICATION_AUTHORITY_REQUIRED", provisionId)
  if evidence == .nil then return .LegalResult~failure("PROVISION_VERIFICATION_EVIDENCE_REQUIRED", provisionId)
  if verificationEvidence \== .nil then return .LegalResult~failure("PROVISION_VERIFICATION_ALREADY_BOUND", provisionId)
  if evidence~subjectKind <> "PROVISION" then return .LegalResult~failure("PROVISION_VERIFICATION_KIND_MISMATCH", evidence~subjectKind)
  if evidence~sourceId <> sourceId then return .LegalResult~failure("PROVISION_VERIFICATION_SOURCE_MISMATCH", evidence~sourceId)
  if evidence~provisionId <> provisionId then return .LegalResult~failure("PROVISION_VERIFICATION_ID_MISMATCH", evidence~provisionId)
  if evidence~expressionId <> expressionId then return .LegalResult~failure("PROVISION_VERIFICATION_EXPRESSION_MISMATCH", evidence~expressionId)
  if evidence~expectedDigest <> contentDigest then return .LegalResult~failure("PROVISION_VERIFICATION_DIGEST_IDENTITY_MISMATCH", evidence~expectedDigest)
  verificationEvidence = evidence
  if evidence~verified then verificationState = "VERIFIED"
  else verificationState = "UNVERIFIED"
  return .LegalResult~success(evidence)

::method cryptographicallyVerified
  expose verificationState verificationEvidence
  if verificationState <> "VERIFIED" then return .false
  if verificationEvidence == .nil then return .false
  if \verificationEvidence~hasMethod("VERIFIED") then return .false
  return verificationEvidence~verified

::method isComplete
  expose sourceId provisionId expressionId locator contentDigest
  if sourceId = "" then return .false
  if provisionId = "" then return .false
  if expressionId = "" then return .false
  if locator = "" then return .false
  return contentDigest <> ""

::method evidenceIdentity
  expose sourceId provisionId expressionId contentDigest
  return "legal-provision/" || sourceId || "/" || provisionId || "/" || expressionId || "/" || contentDigest

::method canonicalText
  expose sourceId provisionId expressionId locator contentDigest lexicalText verificationState
  text = .LegalCanonical~field("SOURCE_ID", sourceId)
  text ||= .LegalCanonical~field("PROVISION_ID", provisionId)
  text ||= .LegalCanonical~field("EXPRESSION_ID", expressionId)
  text ||= .LegalCanonical~field("LOCATOR", locator)
  text ||= .LegalCanonical~field("DIGEST", contentDigest)
  text ||= .LegalCanonical~field("LEXICAL_TEXT", lexicalText)
  text ||= .LegalCanonical~field("VERIFICATION", verificationState)
  return text


::class LegalCompileProposal public
::attribute proposalId get
::attribute proposalKind get
::attribute semanticObject get
::attribute producerId get
::attribute producerKind get
::attribute confidence get

::method init
  expose proposalId proposalKind semanticObject producerId producerKind confidence evidenceReferences
  use arg proposalIdArg, proposalKindArg, semanticObjectArg, producerIdArg, producerKindArg = "TOOL", confidenceArg = ""
  proposalId = proposalIdArg~string~upper
  proposalKind = proposalKindArg~string~upper
  semanticObject = semanticObjectArg
  producerId = producerIdArg~string
  producerKind = producerKindArg~string~upper
  confidence = confidenceArg~string
  evidenceReferences = .array~new

::method addEvidenceReference
  expose evidenceReferences
  use arg reference
  if reference == .nil then return .LegalResult~failure("PROPOSAL_EVIDENCE_REQUIRED", "Evidence reference must not be .nil")
  evidenceReferences~append(reference)
  return .LegalResult~success(reference)

::method evidenceReferences
  expose evidenceReferences
  copy = .array~new
  do reference over evidenceReferences
    copy~append(reference)
  end
  return copy

::method canonicalText
  expose proposalId proposalKind semanticObject producerId producerKind confidence evidenceReferences
  text = .LegalCanonical~field("PROPOSAL_ID", proposalId)
  text ||= .LegalCanonical~field("PROPOSAL_KIND", proposalKind)
  text ||= .LegalCanonical~field("PRODUCER_ID", producerId)
  text ||= .LegalCanonical~field("PRODUCER_KIND", producerKind)
  text ||= .LegalCanonical~field("CONFIDENCE", confidence)
  if semanticObject == .nil then semanticText = "NONE"
  else if semanticObject~hasMethod("CANONICALTEXT") then semanticText = semanticObject~canonicalText
  else semanticText = .LegalCanonical~objectIdentity(semanticObject)
  text ||= .LegalCanonical~field("SEMANTIC_OBJECT", semanticText)
  evidenceText = .array~new
  do reference over evidenceReferences
    evidenceText~append(reference~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("EVIDENCE_REF", evidenceText)
  return text


::class LegalCompilationDiagnostic public
::attribute severity get
::attribute code get
::attribute subjectId get
::attribute detail get

::method init
  expose severity code subjectId detail
  use arg severityArg, codeArg, subjectArg = "", detailArg = ""
  severity = severityArg~string~upper
  code = codeArg~string~upper
  subjectId = subjectArg~string
  detail = detailArg~string

::method string
  expose severity code subjectId detail
  return severity || " " || code || " " || subjectId || " " || detail


::class LegalVerificationEvidenceSnapshot public
::attribute evidenceIdentity get
::attribute subjectKind get
::attribute sourceId get
::attribute provisionId get
::attribute expressionId get
::attribute locator get
::attribute algorithm get
::attribute expectedDigest get
::attribute actualDigest get
::attribute verified get
::attribute statusCode get
::attribute sourceObject get
::attribute materialRepresentation get
::attribute materialLength get
::attribute verifierId get
::attribute verifiedAt get
::attribute parentEvidenceIdentity get
::attribute capturedAt get

::method init
  expose evidenceIdentity subjectKind sourceId provisionId expressionId locator algorithm expectedDigest actualDigest verified statusCode sourceObject materialRepresentation materialLength verifierId verifiedAt parentEvidenceIdentity capturedAt
  use arg evidence
  if evidence == .nil then raise syntax 88.900 array("LegalVerificationEvidenceSnapshot requires evidence")
  evidenceIdentity = evidence~evidenceIdentity
  subjectKind = evidence~subjectKind
  sourceId = evidence~sourceId
  provisionId = evidence~provisionId
  expressionId = evidence~expressionId
  locator = evidence~locator
  algorithm = evidence~algorithm
  expectedDigest = evidence~expectedDigest
  actualDigest = evidence~actualDigest
  verified = evidence~verified
  statusCode = evidence~statusCode
  sourceObject = evidence~sourceObject
  materialRepresentation = evidence~materialRepresentation
  materialLength = evidence~materialLength
  verifierId = evidence~verifierId
  verifiedAt = evidence~verifiedAt
  parentEvidenceIdentity = ""
  if evidence~parentEvidence \== .nil then parentEvidenceIdentity = evidence~parentEvidence~evidenceIdentity
  capturedAt = .DateTime~new

::method canonicalText
  expose evidenceIdentity subjectKind sourceId provisionId expressionId locator algorithm expectedDigest actualDigest verified statusCode materialRepresentation materialLength verifierId verifiedAt parentEvidenceIdentity
  text = .LegalCanonical~field("EVIDENCE_ID", evidenceIdentity)
  text ||= .LegalCanonical~field("SUBJECT_KIND", subjectKind)
  text ||= .LegalCanonical~field("SOURCE_ID", sourceId)
  text ||= .LegalCanonical~field("PROVISION_ID", provisionId)
  text ||= .LegalCanonical~field("EXPRESSION_ID", expressionId)
  text ||= .LegalCanonical~field("LOCATOR", locator)
  text ||= .LegalCanonical~field("ALGORITHM", algorithm)
  text ||= .LegalCanonical~field("EXPECTED_DIGEST", expectedDigest)
  text ||= .LegalCanonical~field("ACTUAL_DIGEST", actualDigest)
  text ||= .LegalCanonical~field("VERIFIED", verified)
  text ||= .LegalCanonical~field("STATUS", statusCode)
  text ||= .LegalCanonical~field("REPRESENTATION", materialRepresentation)
  text ||= .LegalCanonical~field("MATERIAL_LENGTH", materialLength)
  text ||= .LegalCanonical~field("VERIFIER_ID", verifierId)
  text ||= .LegalCanonical~field("VERIFIED_AT", verifiedAt)
  text ||= .LegalCanonical~field("PARENT_EVIDENCE", parentEvidenceIdentity)
  return text

::method provenance
  expose evidenceIdentity subjectKind sourceId provisionId expressionId locator algorithm expectedDigest actualDigest verified statusCode sourceObject materialRepresentation materialLength verifierId verifiedAt parentEvidenceIdentity capturedAt
  p = .table~new
  p["kind"] = "LEGAL_VERIFICATION_EVIDENCE_SNAPSHOT"
  p["evidenceIdentity"] = evidenceIdentity
  p["subjectKind"] = subjectKind
  p["sourceId"] = sourceId
  p["provisionId"] = provisionId
  p["expressionId"] = expressionId
  p["locator"] = locator
  p["algorithm"] = algorithm
  p["expectedDigest"] = expectedDigest
  p["actualDigest"] = actualDigest
  p["verified"] = verified
  p["statusCode"] = statusCode
  p["sourceObject"] = sourceObject
  p["materialRepresentation"] = materialRepresentation
  p["materialLength"] = materialLength
  p["verifierId"] = verifierId
  p["verifiedAt"] = verifiedAt
  p["parentEvidenceIdentity"] = parentEvidenceIdentity
  p["capturedAt"] = capturedAt
  return p



::class LegalSourceAuthorityAttestationSnapshot public
::attribute sourceId get
::attribute claimId get
::attribute policyId get
::attribute canonicalText get
::attribute capturedAt get

::method init
  expose sourceId claimId policyId canonicalText capturedAt signerIds
  use arg attestation
  if attestation == .nil then raise syntax 88.900 array("Authority attestation snapshot requires attestation")
  sourceId = attestation~claim~sourceId
  claimId = attestation~claim~claimId
  policyId = attestation~claim~policyId
  canonicalText = attestation~canonicalText
  signerIds = .array~new
  do signature over attestation~signatures
    signerIds~append(signature~signerId)
  end
  capturedAt = .DateTime~new

::method signerIds
  expose signerIds
  copy = .array~new
  do signerId over signerIds
    copy~append(signerId)
  end
  return copy

::method provenance
  expose sourceId claimId policyId canonicalText capturedAt
  p = .table~new
  p["kind"] = "LEGAL_SOURCE_AUTHORITY_ATTESTATION_SNAPSHOT"
  p["sourceId"] = sourceId
  p["claimId"] = claimId
  p["policyId"] = policyId
  p["canonicalText"] = canonicalText
  p["signerIds"] = self~signerIds
  p["capturedAt"] = capturedAt
  return p


::class LegalCompilationCertificate public
::attribute compilerId get
::attribute compilerVersion get
::attribute inputIdentity get
::attribute compiledAt get
::attribute proposalCount get
::attribute sourceCount get
::attribute provisionCount get

::method init
  expose compilerId compilerVersion inputIdentity compiledAt proposalCount sourceCount provisionCount verificationSnapshots authorityAttestationSnapshots
  use arg compilerIdArg, compilerVersionArg, inputIdentityArg, proposalCountArg, sourceCountArg, provisionCountArg, verificationEvidenceArg = .nil, authorityAttestationsArg = .nil
  compilerId = compilerIdArg~string
  compilerVersion = compilerVersionArg~string
  inputIdentity = inputIdentityArg~string
  proposalCount = proposalCountArg
  sourceCount = sourceCountArg
  provisionCount = provisionCountArg
  verificationSnapshots = .array~new
  if verificationEvidenceArg \== .nil then do evidence over verificationEvidenceArg
    verificationSnapshots~append(.LegalVerificationEvidenceSnapshot~new(evidence))
  end
  authorityAttestationSnapshots = .array~new
  if authorityAttestationsArg \== .nil then do attestation over authorityAttestationsArg
    authorityAttestationSnapshots~append(.LegalSourceAuthorityAttestationSnapshot~new(attestation))
  end
  compiledAt = .DateTime~new~utcIsoDate

::method verificationEvidence
  expose verificationSnapshots
  copy = .array~new
  do snapshot over verificationSnapshots
    copy~append(snapshot)
  end
  return copy

::method sourceAuthorityAttestations
  expose authorityAttestationSnapshots
  copy = .array~new
  do snapshot over authorityAttestationSnapshots
    copy~append(snapshot)
  end
  return copy

::method canonicalText
  expose compilerId compilerVersion inputIdentity proposalCount sourceCount provisionCount verificationSnapshots authorityAttestationSnapshots
  text = .LegalCanonical~field("COMPILER_ID", compilerId)
  text ||= .LegalCanonical~field("COMPILER_VERSION", compilerVersion)
  text ||= .LegalCanonical~field("INPUT_IDENTITY", inputIdentity)
  text ||= .LegalCanonical~field("PROPOSALS", proposalCount)
  text ||= .LegalCanonical~field("SOURCES", sourceCount)
  text ||= .LegalCanonical~field("PROVISIONS", provisionCount)
  verificationText = .array~new
  do snapshot over verificationSnapshots
    verificationText~append(snapshot~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("SOURCE_VERIFICATION", verificationText)
  attestationText = .array~new
  do snapshot over authorityAttestationSnapshots
    attestationText~append(snapshot~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("SOURCE_AUTHORITY_ATTESTATION", attestationText)
  return text


::class LegalCompilationReport public
::attribute ok get
::attribute generation get
::attribute certificate get
::attribute inputIdentity get

::method init
  expose ok generation certificate inputIdentity diagnostics
  use arg okArg, generationArg = .nil, certificateArg = .nil, inputIdentityArg = "", diagnosticsArg = .nil
  ok = okArg
  generation = generationArg
  certificate = certificateArg
  inputIdentity = inputIdentityArg~string
  if diagnosticsArg == .nil then diagnostics = .array~new
  else diagnostics = diagnosticsArg

::method diagnostics
  expose diagnostics
  copy = .array~new
  do diagnostic over diagnostics
    copy~append(diagnostic)
  end
  return copy

::method errorCount
  expose diagnostics
  count = 0
  do diagnostic over diagnostics
    if diagnostic~severity = "ERROR" then count = count + 1
  end
  return count

::method warningCount
  expose diagnostics
  count = 0
  do diagnostic over diagnostics
    if diagnostic~severity = "WARNING" then count = count + 1
  end
  return count



::class LegalCompilationCopy

::method sourceIdentity class
  use arg identity
  if identity == .nil then return .nil
  copy = .LegalSourceIdentity~new(identity~sourceId, identity~sourceKind, identity~expressionId, identity~canonicalUri, identity~contentDigest, identity~authority, identity~jurisdictionId, identity~assertedVerificationState)
  evidence = identity~verificationEvidence
  if evidence \== .nil then ignored = copy~bindVerificationEvidence(evidence, .LegalSourceVerificationAuthority)
  do attestation over identity~authorityAttestations
    ignored = copy~bindAuthorityAttestation(attestation, .LegalSourceAuthorityBindingAuthority)
  end
  return copy

::method provisionReference class
  use arg reference
  if reference == .nil then return .nil
  copy = .LegalProvisionReference~new(reference~sourceId, reference~provisionId, reference~expressionId, reference~locator, reference~contentDigest, reference~lexicalText, reference~assertedVerificationState)
  evidence = reference~verificationEvidence
  if evidence \== .nil then ignored = copy~bindVerificationEvidence(evidence, .LegalSourceVerificationAuthority)
  return copy

::method sourceObject class
  use arg sourceObject
  if sourceObject == .nil then return .nil
  copy = .NormativeSource~new(sourceObject~sourceId, sourceObject~sourceKind, sourceObject~title, sourceObject~authority, sourceObject~jurisdictionId, sourceObject~governingLaw, sourceObject~applicabilityMode)
  do anchor over sourceObject~evidence
    ignored = copy~addEvidence(anchor)
  end
  return copy

::method provisionObject class
  use arg provisionObject
  if provisionObject == .nil then return .nil
  copy = .LegalProvision~new(provisionObject~sourceId, provisionObject~provisionId, provisionObject~initialStatus, provisionObject~materialVersion, provisionObject~lexicalText)
  do anchor over provisionObject~evidence
    ignored = copy~addEvidence(anchor)
  end
  return copy

::method norm class
  use arg norm
  copy = .LegalNorm~new(norm~normId, norm~sourceId, norm~provisionId, norm~normType, norm~actionCode, norm~disposition, norm~subjectMatter, norm~rationale, norm~temporalScope, norm~materialVersion, norm~conflictKey)
  do predicate over norm~conditions
    ignored = copy~addCondition(predicate)
  end
  do predicate over norm~exceptions
    ignored = copy~addException(predicate)
  end
  do claim over norm~jurisdictionClaims
    ignored = copy~addJurisdiction(claim)
  end
  do anchor over norm~evidence
    ignored = copy~addEvidence(anchor)
  end
  if norm~sealed then ignored = copy~seal
  return copy

::method modification class
  use arg effect
  copy = .LegalModificationEffect~new(effect~effectId, effect~sourceId, effect~sourceProvisionId, effect~effectType, effect~targetSourceId, effect~targetProvisionId, effect~temporalScope, effect~applicationOrder, effect~resultingVersion, effect~replacementText)
  do predicate over effect~conditions
    ignored = copy~addCondition(predicate)
  end
  do predicate over effect~exceptions
    ignored = copy~addException(predicate)
  end
  do claim over effect~jurisdictionClaims
    ignored = copy~addJurisdiction(claim)
  end
  do anchor over effect~evidence
    ignored = copy~addEvidence(anchor)
  end
  if effect~sealed then ignored = copy~seal
  return copy

::method authorityRule class
  use arg rule
  copy = .LegalAuthorityRule~new(rule~ruleId, rule~authoritySourceId, rule~authorityProvisionId, rule~winnerSourceId, rule~loserSourceId, rule~relationType, rule~subjectMatter, rule~actionCode, rule~temporalScope, rule~winnerNormId, rule~loserNormId, rule~rationale)
  do predicate over rule~conditions
    ignored = copy~addCondition(predicate)
  end
  do predicate over rule~exceptions
    ignored = copy~addException(predicate)
  end
  do claim over rule~jurisdictionClaims
    ignored = copy~addJurisdiction(claim)
  end
  do anchor over rule~evidence
    ignored = copy~addEvidence(anchor)
  end
  if rule~sealed then ignored = copy~seal
  return copy

::method semanticObject class
  use arg object
  if object == .nil then return .nil
  if object~isA(.LegalNorm) then return self~norm(object)
  if object~isA(.LegalModificationEffect) then return self~modification(object)
  if object~isA(.LegalAuthorityRule) then return self~authorityRule(object)
  return object

::method proposal class
  use arg proposal
  if proposal == .nil then return .nil
  copy = .LegalCompileProposal~new(proposal~proposalId, proposal~proposalKind, self~semanticObject(proposal~semanticObject), proposal~producerId, proposal~producerKind, proposal~confidence)
  do reference over proposal~evidenceReferences
    ignored = copy~addEvidenceReference(self~provisionReference(reference))
  end
  return copy


::class LegalCompilationSnapshot
::attribute generationId get
::attribute version get
::attribute compilerId get
::attribute compilerVersion get

::method init
  expose generationId version compilerId compilerVersion sourceIdentities sourceObjects provisionReferences provisionObjects proposals
  use arg unit
  generationId = unit~generationId
  version = unit~version
  compilerId = unit~compilerId
  compilerVersion = unit~compilerVersion
  sourceIdentities = unit~sourceIdentities
  sourceObjects = unit~sources
  provisionReferences = unit~provisionReferences
  provisionObjects = unit~provisions
  proposals = .array~new
  unitProposals = unit~proposals
  do unitProposal over unitProposals
    proposalCopy = .LegalCompileProposal~new(unitProposal~proposalId, unitProposal~proposalKind, .LegalCompilationCopy~semanticObject(unitProposal~semanticObject), unitProposal~producerId, unitProposal~producerKind, unitProposal~confidence)
    do evidenceReference over unitProposal~evidenceReferences
      evidenceKey = evidenceReference~sourceId || "::" || evidenceReference~provisionId
      declaredReference = provisionReferences[evidenceKey]
      if declaredReference == .nil then declaredReference = evidenceReference
      ignored = proposalCopy~addEvidenceReference(.LegalCompilationCopy~provisionReference(declaredReference))
    end
    proposals~append(proposalCopy)
  end

::method sourceIdentities
  expose sourceIdentities
  copy = .table~new
  do key over sourceIdentities
    copy[key] = .LegalCompilationCopy~sourceIdentity(sourceIdentities[key])
  end
  return copy

::method sources
  expose sourceObjects
  copy = .table~new
  do key over sourceObjects
    copy[key] = .LegalCompilationCopy~sourceObject(sourceObjects[key])
  end
  return copy

::method provisionReferences
  expose provisionReferences
  copy = .table~new
  do key over provisionReferences
    copy[key] = .LegalCompilationCopy~provisionReference(provisionReferences[key])
  end
  return copy

::method provisions
  expose provisionObjects
  copy = .table~new
  do key over provisionObjects
    copy[key] = .LegalCompilationCopy~provisionObject(provisionObjects[key])
  end
  return copy

::method proposals
  expose proposals
  copy = .array~new
  do proposal over proposals
    copy~append(.LegalCompilationCopy~proposal(proposal))
  end
  return copy

::method sourceIdentity
  expose sourceIdentities
  use arg sourceId
  return .LegalCompilationCopy~sourceIdentity(sourceIdentities[sourceId~string])

::method source
  expose sourceObjects
  use arg sourceId
  return .LegalCompilationCopy~sourceObject(sourceObjects[sourceId~string])

::method provisionReference
  expose provisionReferences
  use arg sourceId, provisionId
  return .LegalCompilationCopy~provisionReference(provisionReferences[self~provisionKey(sourceId, provisionId)])

::method provision
  expose provisionObjects
  use arg sourceId, provisionId
  return .LegalCompilationCopy~provisionObject(provisionObjects[self~provisionKey(sourceId, provisionId)])

::method verificationEvidence
  expose sourceIdentities provisionReferences
  out = .array~new
  do key over sourceIdentities
    evidence = sourceIdentities[key]~verificationEvidence
    if evidence \== .nil then out~append(evidence)
  end
  do key over provisionReferences
    evidence = provisionReferences[key]~verificationEvidence
    if evidence \== .nil then out~append(evidence)
  end
  return out

::method authorityAttestations
  expose sourceIdentities
  out = .array~new
  do key over sourceIdentities
    do attestation over sourceIdentities[key]~authorityAttestations
      out~append(attestation)
    end
  end
  return out

::method inputIdentity
  expose generationId version sourceIdentities sourceObjects provisionReferences provisionObjects proposals
  text = "LEGAL-EFFECT-COMPILATION-INPUT/2"
  text ||= .LegalCanonical~field("GENERATION_ID", generationId)
  text ||= .LegalCanonical~field("VERSION", version)
  sourceText = .array~new
  do key over sourceIdentities
    pair = sourceIdentities[key]~canonicalText || sourceObjects[key]~canonicalText
    pair ||= sourceIdentities[key]~authorityAttestationCanonicalText
    sourceText~append(pair)
  end
  text ||= .LegalCanonical~joinCanonical("SOURCE", sourceText)
  provisionText = .array~new
  do key over provisionReferences
    pair = provisionReferences[key]~canonicalText || provisionObjects[key]~canonicalText
    provisionText~append(pair)
  end
  text ||= .LegalCanonical~joinCanonical("PROVISION", provisionText)
  proposalText = .array~new
  do proposal over proposals
    proposalText~append(proposal~canonicalText)
  end
  text ||= .LegalCanonical~joinCanonical("PROPOSAL", proposalText)
  return text

::method sourceCount
  expose sourceIdentities
  return sourceIdentities~items

::method provisionCount
  expose provisionReferences
  return provisionReferences~items

::method proposalCount
  expose proposals
  return proposals~items

::method rawSources
  expose sourceObjects
  use arg authority = .nil
  if authority \== .LegalCompilationAuthority then return .nil
  copy = .table~new
  do key over sourceObjects
    copy[key] = .LegalCompilationCopy~sourceObject(sourceObjects[key])
  end
  return copy

::method rawSourceIdentities
  expose sourceIdentities
  use arg authority = .nil
  if authority \== .LegalCompilationAuthority then return .nil
  copy = .table~new
  do key over sourceIdentities
    copy[key] = .LegalCompilationCopy~sourceIdentity(sourceIdentities[key])
  end
  return copy

::method rawProvisions
  expose provisionObjects
  use arg authority = .nil
  if authority \== .LegalCompilationAuthority then return .nil
  copy = .table~new
  do key over provisionObjects
    copy[key] = .LegalCompilationCopy~provisionObject(provisionObjects[key])
  end
  return copy

::method rawProvisionReferences
  expose provisionReferences
  use arg authority = .nil
  if authority \== .LegalCompilationAuthority then return .nil
  copy = .table~new
  do key over provisionReferences
    copy[key] = .LegalCompilationCopy~provisionReference(provisionReferences[key])
  end
  return copy

::method rawProposals
  expose proposals
  use arg authority = .nil
  if authority \== .LegalCompilationAuthority then return .nil
  copy = .array~new
  do proposal over proposals
    copy~append(.LegalCompilationCopy~proposal(proposal))
  end
  return copy

::method rawSource
  expose sourceObjects
  use arg sourceId, authority = .nil
  if authority \== .LegalCompilationAuthority then return .nil
  return .LegalCompilationCopy~sourceObject(sourceObjects[sourceId~string])

::method rawProvision
  expose provisionObjects
  use arg sourceId, provisionId, authority = .nil
  if authority \== .LegalCompilationAuthority then return .nil
  return .LegalCompilationCopy~provisionObject(provisionObjects[self~provisionKey(sourceId, provisionId)])

::method rawProvisionReference
  expose provisionReferences
  use arg sourceId, provisionId, authority = .nil
  if authority \== .LegalCompilationAuthority then return .nil
  return .LegalCompilationCopy~provisionReference(provisionReferences[self~provisionKey(sourceId, provisionId)])

::method provisionKey private
  use arg sourceId, provisionId
  return sourceId~string || "::" || provisionId~string


::class LegalCompilationUnit public
::attribute generationId get
::attribute version get
::attribute compilerId get
::attribute compilerVersion get
::attribute frozen get

::method init
  expose generationId version compilerId compilerVersion sourceIdentities sourceObjects provisionReferences provisionObjects proposals frozen frozenSnapshot
  use arg generationIdArg, versionArg, compilerIdArg = "legal-effect-compiler", compilerVersionArg = "0.10"
  generationId = generationIdArg~string
  version = versionArg~string
  compilerId = compilerIdArg~string
  compilerVersion = compilerVersionArg~string
  sourceIdentities = .table~new
  sourceObjects = .table~new
  provisionReferences = .table~new
  provisionObjects = .table~new
  proposals = .array~new
  frozen = .false
  frozenSnapshot = .nil

::method addSource
  expose sourceIdentities sourceObjects frozen
  use arg identity, sourceObject
  guard on
  if frozen then return .LegalResult~failure("COMPILATION_UNIT_FROZEN", "Sources cannot be added after compilation snapshot")
  if identity == .nil then return .LegalResult~failure("SOURCE_IDENTITY_REQUIRED", "")
  if sourceObject == .nil then return .LegalResult~failure("SOURCE_OBJECT_REQUIRED", identity~sourceId)
  key = identity~sourceId
  if sourceIdentities~hasIndex(key) then return .LegalResult~failure("DUPLICATE_SOURCE", key)
  sourceIdentities[key] = .LegalCompilationCopy~sourceIdentity(identity)
  sourceObjects[key] = .LegalCompilationCopy~sourceObject(sourceObject)
  return .LegalResult~success(.LegalCompilationCopy~sourceObject(sourceObjects[key]))

::method addProvision
  expose provisionReferences provisionObjects frozen
  use arg reference, provisionObject
  guard on
  if frozen then return .LegalResult~failure("COMPILATION_UNIT_FROZEN", "Provisions cannot be added after compilation snapshot")
  if reference == .nil then return .LegalResult~failure("PROVISION_REFERENCE_REQUIRED", "")
  if provisionObject == .nil then return .LegalResult~failure("PROVISION_OBJECT_REQUIRED", reference~provisionId)
  key = self~provisionKey(reference~sourceId, reference~provisionId)
  if provisionReferences~hasIndex(key) then return .LegalResult~failure("DUPLICATE_PROVISION", key)
  provisionReferences[key] = .LegalCompilationCopy~provisionReference(reference)
  provisionObjects[key] = .LegalCompilationCopy~provisionObject(provisionObject)
  return .LegalResult~success(.LegalCompilationCopy~provisionObject(provisionObjects[key]))

::method verifySource
  expose sourceIdentities frozen
  use arg sourceId, material, verifier
  guard on
  if frozen then return .LegalResult~failure("COMPILATION_UNIT_FROZEN", "Source verification cannot change after compilation snapshot")
  key = sourceId~string
  identity = sourceIdentities[key]
  if identity == .nil then return .LegalResult~failure("SOURCE_IDENTITY_MISSING", key)
  if verifier == .nil then return .LegalResult~failure("SOURCE_VERIFIER_REQUIRED", key)
  evidence = verifier~bindSource(identity, material)
  return .LegalResult~success(evidence)

::method addSourceAuthorityAttestation
  expose sourceIdentities frozen
  use arg sourceId, attestation
  guard on
  if frozen then return .LegalResult~failure("COMPILATION_UNIT_FROZEN", "Source authority attestation cannot change after compilation snapshot")
  key = sourceId~string
  identity = sourceIdentities[key]
  if identity == .nil then return .LegalResult~failure("SOURCE_IDENTITY_MISSING", key)
  return identity~bindAuthorityAttestation(attestation, .LegalSourceAuthorityBindingAuthority)

::method verifyProvision
  expose provisionReferences sourceIdentities frozen
  use arg sourceId, provisionId, material, verifier
  guard on
  if frozen then return .LegalResult~failure("COMPILATION_UNIT_FROZEN", "Provision verification cannot change after compilation snapshot")
  key = self~provisionKey(sourceId, provisionId)
  reference = provisionReferences[key]
  if reference == .nil then return .LegalResult~failure("PROVISION_REFERENCE_MISSING", key)
  if verifier == .nil then return .LegalResult~failure("SOURCE_VERIFIER_REQUIRED", key)
  sourceIdentity = sourceIdentities[sourceId~string]
  if sourceIdentity == .nil then return .LegalResult~failure("PROVISION_SOURCE_IDENTITY_MISSING", key)
  parentEvidence = sourceIdentity~verificationEvidence
  evidence = verifier~bindProvision(reference, material, parentEvidence)
  return .LegalResult~success(evidence)

::method addProposal
  expose proposals frozen
  use arg proposal
  guard on
  if frozen then return .LegalResult~failure("COMPILATION_UNIT_FROZEN", "Proposals cannot be added after compilation snapshot")
  if proposal == .nil then return .LegalResult~failure("PROPOSAL_REQUIRED", "")
  do existing over proposals
    if existing~proposalId = proposal~proposalId then return .LegalResult~failure("DUPLICATE_PROPOSAL", proposal~proposalId)
  end
  proposals~append(.LegalCompilationCopy~proposal(proposal))
  return .LegalResult~success(.LegalCompilationCopy~proposal(proposal))

::method freeze
  expose frozen frozenSnapshot
  guard on
  if self~class \== .LegalCompilationUnit then return .LegalResult~failure("COMPILATION_UNIT_CLASS_REQUIRED", self~class~id~string)
  if frozen then return .LegalResult~success(frozenSnapshot, "compilation unit already frozen")
  frozen = .true
  guard off
  signal on syntax name freezeFailed
  snapshot = .LegalCompilationSnapshot~new(self)
  signal off syntax
  guard on
  frozenSnapshot = snapshot
  return .LegalResult~success(snapshot, "compilation input frozen")
freezeFailed:
  signal off syntax
  conditionObject = condition("O")
  message = "snapshot construction failed"
  if conditionObject \== .nil then do
    if conditionObject["MESSAGE"] \== .nil then message = conditionObject["MESSAGE"]~string
  end
  return .LegalResult~failure("COMPILATION_SNAPSHOT_FAILED", message)

::method sourceIdentities
  expose sourceIdentities
  copy = .table~new
  do key over sourceIdentities
    copy[key] = .LegalCompilationCopy~sourceIdentity(sourceIdentities[key])
  end
  return copy

::method sources
  expose sourceObjects
  copy = .table~new
  do key over sourceObjects
    copy[key] = .LegalCompilationCopy~sourceObject(sourceObjects[key])
  end
  return copy

::method provisionReferences
  expose provisionReferences
  copy = .table~new
  do key over provisionReferences
    copy[key] = .LegalCompilationCopy~provisionReference(provisionReferences[key])
  end
  return copy

::method provisions
  expose provisionObjects
  copy = .table~new
  do key over provisionObjects
    copy[key] = .LegalCompilationCopy~provisionObject(provisionObjects[key])
  end
  return copy

::method proposals
  expose proposals
  copy = .array~new
  do proposal over proposals
    copy~append(.LegalCompilationCopy~proposal(proposal))
  end
  return copy

::method sourceIdentity
  expose sourceIdentities
  use arg sourceId
  return .LegalCompilationCopy~sourceIdentity(sourceIdentities[sourceId~string])

::method source
  expose sourceObjects
  use arg sourceId
  return .LegalCompilationCopy~sourceObject(sourceObjects[sourceId~string])

::method provisionReference
  expose provisionReferences
  use arg sourceId, provisionId
  return .LegalCompilationCopy~provisionReference(provisionReferences[self~provisionKey(sourceId, provisionId)])

::method provision
  expose provisionObjects
  use arg sourceId, provisionId
  return .LegalCompilationCopy~provisionObject(provisionObjects[self~provisionKey(sourceId, provisionId)])

::method verificationEvidence
  expose sourceIdentities provisionReferences
  out = .array~new
  do key over sourceIdentities
    evidence = sourceIdentities[key]~verificationEvidence
    if evidence \== .nil then out~append(evidence)
  end
  do key over provisionReferences
    evidence = provisionReferences[key]~verificationEvidence
    if evidence \== .nil then out~append(evidence)
  end
  return out

::method inputIdentity
  expose frozenSnapshot
  if frozenSnapshot \== .nil then return frozenSnapshot~inputIdentity
  temporary = .LegalCompilationSnapshot~new(self)
  return temporary~inputIdentity

::method sourceCount
  expose sourceIdentities
  return sourceIdentities~items

::method provisionCount
  expose provisionReferences
  return provisionReferences~items

::method proposalCount
  expose proposals
  return proposals~items

::method provisionKey private
  use arg sourceId, provisionId
  return sourceId~string || "::" || provisionId~string


::class LegalRuleCompiler subclass LegalAlchemyObject public

::method compile
  use arg unit
  self~alchemyTouch("COMPILE")
  diagnostics = .array~new
  if unit == .nil then do
    diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "COMPILATION_UNIT_REQUIRED"))
    return .LegalCompilationReport~new(.false, .nil, .nil, "", diagnostics)
  end
  if unit~class \== .LegalCompilationUnit then do
    diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "COMPILATION_UNIT_CLASS_REQUIRED", unit~class~id~string))
    return .LegalCompilationReport~new(.false, .nil, .nil, "", diagnostics)
  end

  freezeResult = unit~freeze
  if \freezeResult~ok then do
    diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", freezeResult~code, unit~generationId, freezeResult~detail))
    return .LegalCompilationReport~new(.false, .nil, .nil, "", diagnostics)
  end
  snapshot = freezeResult~value
  if snapshot == .nil then do
    diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "COMPILATION_SNAPSHOT_MISSING", unit~generationId))
    return .LegalCompilationReport~new(.false, .nil, .nil, "", diagnostics)
  end

  inputIdentity = snapshot~inputIdentity
  self~validateSources(snapshot, diagnostics)
  self~validateProvisions(snapshot, diagnostics)
  self~validateProposals(snapshot, diagnostics)
  if self~hasErrors(diagnostics) then return .LegalCompilationReport~new(.false, .nil, .nil, inputIdentity, diagnostics)

  generation = .LegalRuleGeneration~new(snapshot~generationId, snapshot~version)
  sourceObjects = snapshot~rawSources(.LegalCompilationAuthority)
  sourceIdentities = snapshot~rawSourceIdentities(.LegalCompilationAuthority)
  do sourceId over sourceObjects
    sourceObject = sourceObjects[sourceId]
    bindResult = sourceObject~bindSourceIdentity(sourceIdentities[sourceId])
    if \bindResult~ok then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", bindResult~code, sourceId, bindResult~detail))
    if bindResult~ok then do
      addResult = generation~addSource(sourceObject)
      if \addResult~ok then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", addResult~code, sourceId, addResult~detail))
    end
  end

  provisionObjects = snapshot~rawProvisions(.LegalCompilationAuthority)
  provisionReferences = snapshot~rawProvisionReferences(.LegalCompilationAuthority)
  do key over provisionObjects
    provisionObject = provisionObjects[key]
    bindResult = provisionObject~bindProvisionReference(provisionReferences[key])
    if \bindResult~ok then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", bindResult~code, key, bindResult~detail))
    if bindResult~ok then do
      addResult = generation~addProvision(provisionObject)
      if \addResult~ok then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", addResult~code, key, addResult~detail))
    end
  end

  if self~hasErrors(diagnostics) then return .LegalCompilationReport~new(.false, .nil, .nil, inputIdentity, diagnostics)

  do proposal over snapshot~rawProposals(.LegalCompilationAuthority)
    semanticObject = proposal~semanticObject
    self~attachProposalEvidence(snapshot, proposal, semanticObject)
    select
      when proposal~proposalKind = "NORM" then addResult = generation~addNorm(semanticObject)
      when proposal~proposalKind = "MODIFICATION" then addResult = generation~addModification(semanticObject)
      when proposal~proposalKind = "AUTHORITY_RULE" then addResult = generation~addAuthorityRule(semanticObject)
      otherwise addResult = .LegalResult~failure("UNKNOWN_PROPOSAL_KIND", proposal~proposalKind)
    end
    if \addResult~ok then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", addResult~code, proposal~proposalId, addResult~detail))
  end

  if self~hasErrors(diagnostics) then return .LegalCompilationReport~new(.false, .nil, .nil, inputIdentity, diagnostics)

  certificate = .LegalCompilationCertificate~new(snapshot~compilerId, snapshot~compilerVersion, inputIdentity, snapshot~proposalCount, snapshot~sourceCount, snapshot~provisionCount, snapshot~verificationEvidence, snapshot~authorityAttestations)
  certifyResult = generation~certifyCompilation(certificate, .LegalCompilationAuthority)
  if \certifyResult~ok then do
    diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", certifyResult~code, snapshot~generationId, certifyResult~detail))
    return .LegalCompilationReport~new(.false, .nil, .nil, inputIdentity, diagnostics)
  end
  ignored = generation~seal
  return .LegalCompilationReport~new(.true, generation, certificate, inputIdentity, diagnostics)

::method validateSources private
  use arg unit, diagnostics
  identities = unit~sourceIdentities
  sources = unit~sources
  do sourceId over identities
    identity = identities[sourceId]
    sourceObject = sources[sourceId]
    if \identity~isComplete then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "SOURCE_IDENTITY_INCOMPLETE", sourceId))
    verification = identity~verificationEvidence
    if verification == .nil then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "SOURCE_VERIFICATION_EVIDENCE_MISSING", sourceId, identity~assertedVerificationState))
    else do
      if \verification~verified then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "SOURCE_VERIFICATION_FAILED", sourceId, verification~statusCode))
      if verification~expectedDigest <> identity~contentDigest then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "SOURCE_VERIFICATION_DIGEST_IDENTITY_MISMATCH", sourceId))
      if verification~actualDigest <> identity~contentDigest then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "SOURCE_DIGEST_MISMATCH", sourceId, verification~actualDigest))
    end
    if identity~verificationState <> "VERIFIED" then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "SOURCE_IDENTITY_UNVERIFIED", sourceId, identity~verificationState))
    if sourceObject == .nil then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "SOURCE_OBJECT_MISSING", sourceId))
    else do
      if sourceObject~sourceId <> identity~sourceId then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "SOURCE_IDENTITY_MISMATCH", sourceId))
      if sourceObject~sourceKind <> identity~sourceKind then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "SOURCE_KIND_MISMATCH", sourceId))
    end
  end
  do sourceId over sources
    if \identities~hasIndex(sourceId) then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "SOURCE_IDENTITY_MISSING", sourceId))
  end

::method validateProvisions private
  use arg unit, diagnostics
  references = unit~provisionReferences
  provisions = unit~provisions
  identities = unit~sourceIdentities
  do key over references
    reference = references[key]
    provisionObject = provisions[key]
    if \reference~isComplete then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROVISION_REFERENCE_INCOMPLETE", key))
    verification = reference~verificationEvidence
    if verification == .nil then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROVISION_VERIFICATION_EVIDENCE_MISSING", key, reference~assertedVerificationState))
    else do
      if \verification~verified then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROVISION_VERIFICATION_FAILED", key, verification~statusCode))
      if verification~expectedDigest <> reference~contentDigest then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROVISION_VERIFICATION_DIGEST_IDENTITY_MISMATCH", key))
      if verification~actualDigest <> reference~contentDigest then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROVISION_DIGEST_MISMATCH", key, verification~actualDigest))
      parentEvidence = verification~parentEvidence
      if parentEvidence == .nil then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROVISION_PARENT_SOURCE_EVIDENCE_MISSING", key))
      else do
        if parentEvidence~subjectKind <> "SOURCE" then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROVISION_PARENT_EVIDENCE_KIND_MISMATCH", key))
        if parentEvidence~sourceId <> reference~sourceId then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROVISION_PARENT_SOURCE_MISMATCH", key))
        if \parentEvidence~verified then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROVISION_PARENT_SOURCE_UNVERIFIED", key))
      end
    end
    if reference~verificationState <> "VERIFIED" then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROVISION_REFERENCE_UNVERIFIED", key, reference~verificationState))
    sourceIdentity = identities[reference~sourceId]
    if sourceIdentity == .nil then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROVISION_SOURCE_IDENTITY_MISSING", key))
    else if sourceIdentity~expressionId <> reference~expressionId then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROVISION_EXPRESSION_MISMATCH", key))
    if provisionObject == .nil then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROVISION_OBJECT_MISSING", key))
    else do
      if provisionObject~sourceId <> reference~sourceId then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROVISION_SOURCE_MISMATCH", key))
      if provisionObject~provisionId <> reference~provisionId then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROVISION_ID_MISMATCH", key))
      if reference~lexicalText <> "" then do
        if provisionObject~lexicalText <> reference~lexicalText then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROVISION_TEXT_MISMATCH", key))
      end
    end
  end
  do key over provisions
    if \references~hasIndex(key) then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROVISION_REFERENCE_MISSING", key))
  end

::method validateProposals private
  use arg unit, diagnostics
  do proposal over unit~proposals
    semanticObject = proposal~semanticObject
    if semanticObject == .nil then do
      diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROPOSAL_OBJECT_MISSING", proposal~proposalId))
      iterate
    end
    kind = proposal~proposalKind
    validKind = .false
    if kind = "NORM" then do
      validKind = semanticObject~isA(.LegalNorm)
    end
    else if kind = "MODIFICATION" then do
      validKind = semanticObject~isA(.LegalModificationEffect)
    end
    else if kind = "AUTHORITY_RULE" then do
      validKind = semanticObject~isA(.LegalAuthorityRule)
    end
    if \validKind then do
      diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROPOSAL_KIND_MISMATCH", proposal~proposalId, kind))
      iterate
    end
    if semanticObject~sealed then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PRESEALED_PROPOSAL_REJECTED", proposal~proposalId))
    if semanticObject~evidence~items > 0 then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROPOSAL_PREATTACHED_EVIDENCE_REJECTED", proposal~proposalId))
    references = proposal~evidenceReferences
    if references~items = 0 then do
      diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROPOSAL_EVIDENCE_MISSING", proposal~proposalId))
      iterate
    end
    primarySource = ""
    primaryProvision = ""
    if kind = "NORM" then do
      primarySource = semanticObject~sourceId
      primaryProvision = semanticObject~provisionId
    end
    else if kind = "MODIFICATION" then do
      primarySource = semanticObject~sourceId
      primaryProvision = semanticObject~sourceProvisionId
      if unit~provision(semanticObject~targetSourceId, semanticObject~targetProvisionId) == .nil then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "MODIFICATION_TARGET_MISSING", proposal~proposalId))
    end
    else do
      primarySource = semanticObject~authoritySourceId
      primaryProvision = semanticObject~authorityProvisionId
      if unit~source(semanticObject~winnerSourceId) == .nil then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "AUTHORITY_WINNER_SOURCE_MISSING", proposal~proposalId))
      if unit~source(semanticObject~loserSourceId) == .nil then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "AUTHORITY_LOSER_SOURCE_MISSING", proposal~proposalId))
      if semanticObject~winnerNormId <> "*" then do
        if \self~proposalNormExists(unit, semanticObject~winnerSourceId, semanticObject~winnerNormId) then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "AUTHORITY_WINNER_NORM_MISSING", proposal~proposalId, semanticObject~winnerNormId))
      end
      if semanticObject~loserNormId <> "*" then do
        if \self~proposalNormExists(unit, semanticObject~loserSourceId, semanticObject~loserNormId) then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "AUTHORITY_LOSER_NORM_MISSING", proposal~proposalId, semanticObject~loserNormId))
      end
    end
    if unit~provision(primarySource, primaryProvision) == .nil then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROPOSAL_PRIMARY_PROVISION_MISSING", proposal~proposalId, primarySource || "::" || primaryProvision))
    foundPrimary = .false
    do reference over references
      declaredReference = unit~provisionReference(reference~sourceId, reference~provisionId)
      if declaredReference == .nil then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROPOSAL_EVIDENCE_UNDECLARED", proposal~proposalId, reference~sourceId || "::" || reference~provisionId))
      else if declaredReference~evidenceIdentity <> reference~evidenceIdentity then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROPOSAL_EVIDENCE_IDENTITY_MISMATCH", proposal~proposalId, reference~locator))
      if reference~sourceId = primarySource then do
        if reference~provisionId = primaryProvision then foundPrimary = .true
      end
    end
    if \foundPrimary then diagnostics~append(.LegalCompilationDiagnostic~new("ERROR", "PROPOSAL_PRIMARY_EVIDENCE_MISSING", proposal~proposalId, primarySource || "::" || primaryProvision))
  end

::method proposalNormExists private
  use arg unit, sourceId, normId
  do candidateProposal over unit~proposals
    if candidateProposal~proposalKind <> "NORM" then iterate
    candidateNorm = candidateProposal~semanticObject
    if candidateNorm == .nil then iterate
    if candidateNorm~sourceId = sourceId then do
      if candidateNorm~normId = normId then return .true
    end
  end
  return .false

::method attachProposalEvidence private
  use arg unit, proposal, semanticObject
  do reference over proposal~evidenceReferences
    if unit~isA(.LegalCompilationSnapshot) then sourceObject = unit~rawSource(reference~sourceId, .LegalCompilationAuthority)
    else sourceObject = unit~source(reference~sourceId)
    authority = ""
    if sourceObject \== .nil then authority = sourceObject~authority
    metadata = .table~new
    metadata["proposalId"] = proposal~proposalId
    metadata["producerId"] = proposal~producerId
    metadata["producerKind"] = proposal~producerKind
    metadata["expressionId"] = reference~expressionId
    metadata["contentDigest"] = reference~contentDigest
    anchor = .LegalEvidenceAnchor~new(reference~sourceId, "LEGAL_PROVISION", reference~locator, reference, authority, metadata)
    ignored = semanticObject~addEvidence(anchor)
  end

::method hasErrors private
  use arg diagnostics
  do diagnostic over diagnostics
    if diagnostic~severity = "ERROR" then return .true
  end
  return .false


::class LegalStructuredRelationBridge public

::method factSetFrom class
  use arg richFacts
  resultSet = .LegalFactSet~new
  do richFact over richFacts
    addResult = resultSet~putRichFact(richFact)
    if \addResult~ok then return addResult
  end
  return .LegalResult~success(resultSet)

::method evidenceAnchor class
  use arg sourceId, sourceKind, citation, richObject, authority = ""
  return .LegalEvidenceAnchor~new(sourceId, sourceKind, citation, richObject, authority)


::class LegalHardWorldBridge public

::method applyAssessment class
  use arg assessment, world, prefix = "LEGAL_"
  if assessment == .nil then return .LegalResult~failure("INVALID_ASSESSMENT", "Assessment must not be .nil")
  if world == .nil then return .LegalResult~failure("INVALID_WORLD", "World must not be .nil")
  if \world~hasMethod("PUTKNOWN") then return .LegalResult~failure("INVALID_WORLD", "World does not support putKnown")
  source = assessment
  authority = "LEGAL_EFFECT/" || assessment~generation~generationId
  blocked = assessment~status = "BLOCKED"
  review = assessment~status = "REVIEW_REQUIRED"
  conditional = assessment~status = "CONDITIONAL"
  ignored = world~putKnown(prefix || "ACTION_BLOCKED", blocked, source, authority)
  ignored = world~putKnown(prefix || "ACTION_REVIEW_REQUIRED", review, source, authority)
  ignored = world~putKnown(prefix || "ACTION_CONDITIONAL", conditional, source, authority)
  return .LegalResult~success(world)


::class LegalCompilationEvidenceSnapshot public
::attribute compilerId get
::attribute compilerVersion get
::attribute inputIdentity get
::attribute compiledAt get
::attribute proposalCount get
::attribute sourceCount get
::attribute provisionCount get
::attribute certificateCanonicalText get
::attribute capturedAt get

::method init
  expose compilerId compilerVersion inputIdentity compiledAt proposalCount sourceCount provisionCount certificateCanonicalText capturedAt verificationSnapshots authorityAttestationSnapshots
  use arg certificate
  if certificate == .nil then raise syntax 88.900 array("LegalCompilationEvidenceSnapshot requires a compilation certificate")
  compilerId = certificate~compilerId
  compilerVersion = certificate~compilerVersion
  inputIdentity = certificate~inputIdentity
  compiledAt = certificate~compiledAt
  proposalCount = certificate~proposalCount
  sourceCount = certificate~sourceCount
  provisionCount = certificate~provisionCount
  certificateCanonicalText = certificate~canonicalText
  verificationSnapshots = .array~new
  do snapshot over certificate~verificationEvidence
    verificationSnapshots~append(snapshot)
  end
  authorityAttestationSnapshots = .array~new
  do snapshot over certificate~sourceAuthorityAttestations
    authorityAttestationSnapshots~append(snapshot)
  end
  capturedAt = .DateTime~new

::method verificationEvidence
  expose verificationSnapshots
  copy = .array~new
  do snapshot over verificationSnapshots
    copy~append(snapshot)
  end
  return copy

::method sourceAuthorityAttestations
  expose authorityAttestationSnapshots
  copy = .array~new
  do snapshot over authorityAttestationSnapshots
    copy~append(snapshot)
  end
  return copy

::method provenance
  expose compilerId compilerVersion inputIdentity compiledAt proposalCount sourceCount provisionCount certificateCanonicalText capturedAt verificationSnapshots authorityAttestationSnapshots
  p = .table~new
  p["kind"] = "LEGAL_COMPILATION_EVIDENCE_SNAPSHOT"
  p["compilerId"] = compilerId
  p["compilerVersion"] = compilerVersion
  p["inputIdentity"] = inputIdentity
  p["compiledAt"] = compiledAt
  p["proposalCount"] = proposalCount
  p["sourceCount"] = sourceCount
  p["provisionCount"] = provisionCount
  p["certificateCanonicalText"] = certificateCanonicalText
  p["verificationEvidence"] = self~verificationEvidence
  p["sourceAuthorityAttestations"] = self~sourceAuthorityAttestations
  p["capturedAt"] = capturedAt
  return p

::method string
  expose compilerId compilerVersion inputIdentity
  return "LEGAL-COMPILATION[" || compilerId || ":" || compilerVersion || "] " || inputIdentity


::class LegalRuntimeSemanticBindingEvidence public
::attribute legalGenerationId get
::attribute legalSemanticIdentity get
::attribute compilationEvidence get
::attribute runtimeEvidence get
::attribute capturedAt get

::method init
  expose legalGenerationId legalSemanticIdentity compilationEvidence runtimeEvidence capturedAt sourceAuthorityEvidence
  use arg legalGeneration, runtimeEvidenceArg, sourceAuthorityEvidenceArg = .nil
  if legalGeneration == .nil then raise syntax 88.900 array("LegalRuntimeSemanticBindingEvidence requires a legal generation")
  if runtimeEvidenceArg == .nil then raise syntax 88.900 array("LegalRuntimeSemanticBindingEvidence requires runtime evidence")
  if \legalGeneration~publicationEligible then raise syntax 88.900 array("LegalRuntimeSemanticBindingEvidence requires a compiler-certified legal generation")
  certificate = legalGeneration~compilationCertificate
  if certificate == .nil then raise syntax 88.900 array("LegalRuntimeSemanticBindingEvidence requires compilation certificate")
  legalGenerationId = legalGeneration~generationId
  legalSemanticIdentity = legalGeneration~semanticIdentity
  compilationEvidence = .LegalCompilationEvidenceSnapshot~new(certificate)
  runtimeEvidence = runtimeEvidenceArg
  sourceAuthorityEvidence = .array~new
  if sourceAuthorityEvidenceArg \== .nil then do item over sourceAuthorityEvidenceArg
    sourceAuthorityEvidence~append(item)
  end
  capturedAt = .DateTime~new

::method sourceAuthorityEvidence
  expose sourceAuthorityEvidence
  copy = .array~new
  do item over sourceAuthorityEvidence
    copy~append(item)
  end
  return copy

::method provenance
  expose legalGenerationId legalSemanticIdentity compilationEvidence runtimeEvidence capturedAt sourceAuthorityEvidence
  p = .table~new
  p["kind"] = "LEGAL_RUNTIME_SEMANTIC_BINDING_EVIDENCE"
  p["legalGenerationId"] = legalGenerationId
  p["legalSemanticIdentity"] = legalSemanticIdentity
  p["capturedAt"] = capturedAt
  p["compilation"] = compilationEvidence~provenance
  p["runtime"] = runtimeEvidence~provenance
  authority = .array~new
  do item over sourceAuthorityEvidence
    authority~append(item~provenance)
  end
  p["sourceAuthority"] = authority
  return p

::method string
  expose legalGenerationId runtimeEvidence
  return "LEGAL-RUNTIME-BINDING[" || legalGenerationId || "] " || runtimeEvidence~string


::class LegalEffectExecutionEnvelope public
::attribute assessment get
::attribute bindingEvidence get
::attribute createdAt get

::method init
  expose assessment bindingEvidence upstreamRuntimeEvidence createdAt
  use arg assessmentArg, bindingEvidenceArg
  if assessmentArg == .nil then raise syntax 88.900 array("LegalEffectExecutionEnvelope requires an assessment")
  if bindingEvidenceArg == .nil then raise syntax 88.900 array("LegalEffectExecutionEnvelope requires binding evidence")
  assessment = assessmentArg
  bindingEvidence = bindingEvidenceArg
  createdAt = .DateTime~new
  upstreamRuntimeEvidence = self~collectUpstreamRuntimeEvidence(assessmentArg)

::method status
  expose assessment
  return assessment~status

::method decisionTrace
  expose assessment
  return assessment~decisionTrace

::method upstreamRuntimeEvidence
  expose upstreamRuntimeEvidence
  copy = .array~new
  do i = 1 to upstreamRuntimeEvidence~items
    copy~append(upstreamRuntimeEvidence~at(i))
  end
  return copy

::method provenance
  expose assessment bindingEvidence createdAt
  p = .table~new
  p["kind"] = "LEGAL_EFFECT_EXECUTION_ENVELOPE"
  p["createdAt"] = createdAt
  p["status"] = assessment~status
  if assessment~decisionTrace \== .nil then p["decisionTraceIdentity"] = assessment~decisionTrace~traceIdentity
  p["legalRuntimeBinding"] = bindingEvidence~provenance
  p["upstreamRuntimeEvidence"] = self~upstreamRuntimeEvidence
  return p

::method collectUpstreamRuntimeEvidence private
  use arg assessment
  out = .array~new
  seen = .table~new
  contexts = .array~of(assessment~currentContext, assessment~prospectiveContext)
  do context over contexts
    if context == .nil then iterate
    factSet = context~facts
    if factSet == .nil then iterate
    do factObject over factSet~allFacts
      runtimeEvidence = factObject~runtimeEvidence
      if runtimeEvidence == .nil then iterate
      key = runtimeEvidence~environment || "|" || runtimeEvidence~moduleId || "|" || runtimeEvidence~generationId || "|" || runtimeEvidence~artifactId
      if seen~hasIndex(key) then iterate
      seen[key] = .true
      out~append(runtimeEvidence)
    end
  end
  return out

::method string
  expose assessment bindingEvidence
  return "LEGAL-EXECUTION[" || assessment~status || "] " || bindingEvidence~string


::class LegalRuntimeRuleLease public
::attribute runtimeLease get
::attribute generation get
::attribute released get
::attribute acquiredRuntimeEvidence get

::method init
  expose runtimeLease generation released acquiredRuntimeEvidence lastRuntimeEvidence sourceAuthorityEvidence
  use arg runtimeLeaseArg, generationArg, sourceAuthorityEvidenceArg = .nil
  runtimeLease = runtimeLeaseArg
  generation = generationArg
  released = .false
  acquiredRuntimeEvidence = .nil
  lastRuntimeEvidence = .nil
  sourceAuthorityEvidence = .array~new
  if sourceAuthorityEvidenceArg \== .nil then do item over sourceAuthorityEvidenceArg
    sourceAuthorityEvidence~append(item)
  end
  if runtimeLease~hasMethod("EXECUTIONEVIDENCE") then do
    acquiredRuntimeEvidence = runtimeLease~executionEvidence
    lastRuntimeEvidence = acquiredRuntimeEvidence
  end

::method sourceAuthorityEvidence
  expose sourceAuthorityEvidence
  copy = .array~new
  do item over sourceAuthorityEvidence
    copy~append(item)
  end
  return copy

::method runtimeEvidence
  expose runtimeLease released acquiredRuntimeEvidence lastRuntimeEvidence
  if \released then do
    if runtimeLease~hasMethod("EXECUTIONEVIDENCE") then do
      currentEvidence = runtimeLease~executionEvidence
      if currentEvidence \== .nil then lastRuntimeEvidence = currentEvidence
    end
  end
  if lastRuntimeEvidence \== .nil then return lastRuntimeEvidence
  return acquiredRuntimeEvidence

::method bindingEvidence
  expose generation sourceAuthorityEvidence
  currentEvidence = self~runtimeEvidence
  if currentEvidence == .nil then return .nil
  return .LegalRuntimeSemanticBindingEvidence~new(generation, currentEvidence, sourceAuthorityEvidence)

::method evaluate
  expose generation released sourceAuthorityEvidence
  use arg action, context
  if released then return .LegalResult~failure("LEGAL_LEASE_RELEASED", "Legal rule lease has been released")
  currentEvidence = self~runtimeEvidence
  if currentEvidence == .nil then return .LegalResult~failure("LEGAL_RUNTIME_EVIDENCE_UNAVAILABLE", "Runtime Registry does not expose execution evidence")
  binding = .LegalRuntimeSemanticBindingEvidence~new(generation, currentEvidence, sourceAuthorityEvidence)
  engineResult = .LegalEffectEngine~new~evaluate(action, generation, context)
  if \engineResult~ok then return engineResult
  envelope = .LegalEffectExecutionEnvelope~new(engineResult~value, binding)
  return .LegalResult~success(envelope, engineResult~detail)

::method release
  expose runtimeLease released
  if released then return .LegalResult~success(.nil, "already released")
  releaseResult = runtimeLease~release
  released = .true
  return releaseResult

::method uninit
  expose released
  if \released then ignored = self~release


::class LegalRuntimeRuleResolver subclass LegalAlchemyObject public

::method acquire
  use arg runtimeKernel, environment, moduleId, trustProfile = .nil, authorityVerifier = .nil
  self~alchemyTouch("ACQUIRE")
  if runtimeKernel == .nil then return .LegalResult~failure("INVALID_RUNTIME", "Runtime kernel must not be .nil")
  acquireResult = runtimeKernel~acquire(environment, moduleId)
  if \acquireResult~ok then return .LegalResult~failure(acquireResult~code, acquireResult~detail)
  runtimeLease = acquireResult~value
  runtimeGeneration = runtimeLease~generation
  if runtimeGeneration == .nil then do
    ignored = runtimeLease~release
    return .LegalResult~failure("LEGAL_RUNTIME_GENERATION_MISSING", "Runtime lease has no generation")
  end
  if runtimeGeneration~moduleKind <> "LEGAL_RULES" then do
    badKind = runtimeGeneration~moduleKind
    ignored = runtimeLease~release
    return .LegalResult~failure("LEGAL_MODULE_KIND_REQUIRED", badKind)
  end
  /* Runtime Registry v0.5+ deliberately exposes a read-only generation
   * view rather than the mutable RuntimeArtifact object.  Legal Effect needs
   * only the published API identity, so consume that public view directly. */
  if \runtimeGeneration~hasMethod("APIVERSION") then do
    ignored = runtimeLease~release
    return .LegalResult~failure("LEGAL_RUNTIME_API_SURFACE_REQUIRED", moduleId~string)
  end
  if runtimeGeneration~apiVersion <> .LegalEffectBuild~API_VERSION then do
    badApi = runtimeGeneration~apiVersion
    ignored = runtimeLease~release
    return .LegalResult~failure("LEGAL_API_VERSION_MISMATCH", badApi || " expected " || .LegalEffectBuild~API_VERSION)
  end
  moduleObject = runtimeLease~module
  if moduleObject == .nil then do
    ignored = runtimeLease~release
    return .LegalResult~failure("LEGAL_MODULE_EMPTY", "Runtime module is empty")
  end
  if \moduleObject~hasMethod("LEGALGENERATION") then do
    ignored = runtimeLease~release
    return .LegalResult~failure("LEGAL_GENERATION_METHOD_MISSING", "Runtime module has no legalGeneration method")
  end
  legalGeneration = moduleObject~legalGeneration
  if legalGeneration == .nil then do
    ignored = runtimeLease~release
    return .LegalResult~failure("LEGAL_GENERATION_MISSING", "Runtime module returned no legal generation")
  end
  if \legalGeneration~sealed then do
    ignored = runtimeLease~release
    return .LegalResult~failure("LEGAL_GENERATION_NOT_SEALED", legalGeneration~generationId)
  end
  if \legalGeneration~publicationEligible then do
    ignored = runtimeLease~release
    return .LegalResult~failure("LEGAL_GENERATION_NOT_COMPILED", legalGeneration~generationId)
  end
  if \runtimeLease~hasMethod("EXECUTIONEVIDENCE") then do
    ignored = runtimeLease~release
    return .LegalResult~failure("LEGAL_RUNTIME_EVIDENCE_REQUIRED", "Runtime Registry execution evidence is required by legal.effect/0.10")
  end
  runtimeEvidence = runtimeLease~executionEvidence
  if runtimeEvidence == .nil then do
    ignored = runtimeLease~release
    return .LegalResult~failure("LEGAL_RUNTIME_EVIDENCE_REQUIRED", "Runtime Registry returned no execution evidence")
  end
  if trustProfile == .nil then do
    ignored = runtimeLease~release
    return .LegalResult~failure("LEGAL_SOURCE_AUTHORITY_TRUST_PROFILE_REQUIRED", "Host-owned source authority trust profile is required by legal.effect/0.10")
  end
  if authorityVerifier == .nil then do
    ignored = runtimeLease~release
    return .LegalResult~failure("LEGAL_SOURCE_AUTHORITY_VERIFIER_REQUIRED", "Host-owned source authority verifier is required by legal.effect/0.10")
  end
  authorityResult = self~verifySourceAuthority(legalGeneration, trustProfile, authorityVerifier)
  if \authorityResult~ok then do
    ignored = runtimeLease~release
    return authorityResult
  end
  return .LegalResult~success(.LegalRuntimeRuleLease~new(runtimeLease, legalGeneration, authorityResult~value))

::method verifySourceAuthority private
  use arg legalGeneration, trustProfile, authorityVerifier
  if trustProfile~class \== .LegalSourceAuthorityTrustProfile then return .LegalResult~failure("LEGAL_SOURCE_AUTHORITY_TRUST_PROFILE_CLASS_REQUIRED", trustProfile~class~id~string)
  if authorityVerifier~class \== .LegalSourceAuthorityVerifier then return .LegalResult~failure("LEGAL_SOURCE_AUTHORITY_VERIFIER_CLASS_REQUIRED", authorityVerifier~class~id~string)
  sources = legalGeneration~sources
  evidence = .array~new
  do sourceId over sources
    source = sources[sourceId]
    identity = source~sourceIdentity
    if identity == .nil then return .LegalResult~failure("LEGAL_SOURCE_IDENTITY_REQUIRED", sourceId)
    if \identity~cryptographicallyVerified then return .LegalResult~failure("LEGAL_SOURCE_VERIFICATION_REQUIRED", sourceId)
    attestations = identity~authorityAttestations
    if attestations~items = 0 then return .LegalResult~failure("LEGAL_SOURCE_AUTHORITY_ATTESTATION_REQUIRED", sourceId)
    accepted = .nil
    lastFailure = .nil
    do attestation over attestations
      check = authorityVerifier~verify(identity, attestation, trustProfile)
      if check~verified then do
        accepted = check
        leave
      end
      lastFailure = check
    end
    if accepted == .nil then do
      if lastFailure == .nil then return .LegalResult~failure("LEGAL_SOURCE_AUTHORITY_UNVERIFIED", sourceId)
      return .LegalResult~failure("LEGAL_" || lastFailure~statusCode, sourceId || ": " || lastFailure~detail, lastFailure)
    end
    evidence~append(accepted)
  end
  return .LegalResult~success(evidence, "host source authority policy satisfied")

::requires "AlchemyObject.cls"
