/* External financial-statement assessment surface. Imported statements are
 * evidence for analysis and never become posted GL journals implicitly. */

::options digits 50

::class AccountingExternalFact public
::attribute conceptId get
::attribute label get
::attribute lexicalValue get
::attribute valueType get
::attribute currency get
::attribute unit get
::attribute periodStart get
::attribute periodEnd get
::attribute instantDate get
::attribute sourcePointer get
::attribute mappingState get
::method init
  expose conceptId label lexicalValue valueType currency unit periodStart periodEnd instantDate sourcePointer mappingState dimensions provenance
  use arg conceptArg, valueArg, typeArg = "DECIMAL", labelArg = "", currencyArg = "", unitArg = "", startArg = "", endArg = "", instantArg = "", pointerArg = "", stateArg = "REPORTED", dimensionsArg = .nil, provenanceArg = .nil
  conceptId = .AccountingUtil~requireText(conceptArg, "external fact conceptId")
  lexicalValue = valueArg~string
  valueType = typeArg~string~upper
  label = labelArg~string
  currency = currencyArg~string~upper
  unit = unitArg~string
  periodStart = startArg~string
  periodEnd = endArg~string
  instantDate = instantArg~string
  sourcePointer = pointerArg~string
  mappingState = stateArg~string~upper
  dimensions = .AccountingUtil~copyDirectory(dimensionsArg)
  provenance = .AccountingUtil~copyDirectory(provenanceArg)

::method dimensions
  expose dimensions
  return .AccountingUtil~copyDirectory(dimensions)

::method provenance
  expose provenance
  return .AccountingUtil~copyDirectory(provenance)

::method sourceConcept
  expose provenance conceptId
  value = provenance["source_concept_qname"]
  if value == .nil | value~string = "" then return conceptId
  return value~string

::method conceptLocalName
  expose conceptId
  text = conceptId~string
  if text~left(1) = "{" then do
    p = text~pos("}")
    if p > 0 then return text~substr(p + 1)
  end
  p = text~pos(":")
  if p > 0 then return text~substr(p + 1)
  return text

::method conceptNamespace
  expose conceptId
  text = conceptId~string
  if text~left(1) = "{" then do
    p = text~pos("}")
    if p > 0 then return text~substr(2, p - 2)
  end
  return ""

::method normalizedValue
  expose provenance lexicalValue
  value = provenance["normalized_value"]
  if value == .nil then return lexicalValue
  return value~string

::method isDuplicate
  expose mappingState provenance
  if mappingState = "REPORTED_DUPLICATE" then return .true
  duplicateOf = provenance["duplicate_of"]
  return duplicateOf \== .nil & duplicateOf~string \= ""

::method fingerprint
  expose conceptId lexicalValue valueType label currency unit periodStart periodEnd instantDate sourcePointer mappingState dimensions provenance
  return conceptId || "|" || lexicalValue || "|" || valueType || "|" || label || "|" || currency || "|" || unit || "|" || periodStart || "|" || periodEnd || "|" || instantDate || "|" || sourcePointer || "|" || mappingState || "|" || .AccountingUtil~canonicalDirectory(dimensions) || "|" || .AccountingUtil~canonicalDirectory(provenance)

::class AccountingExternalStatement public
::attribute externalIdentity get
::attribute sourceSystem get
::attribute sourceContract get
::attribute mappingGeneration get
::attribute evidenceIdentity get
::attribute bodyDigest get
::attribute sourceUrl get
::attribute sourceEntityId get
::attribute sourceEntityName get
::attribute statementKind get
::attribute periodStart get
::attribute periodEnd get
::attribute reportingBasis get
::attribute unitsDescription get
::attribute retrievedAt get
::method init
  expose externalIdentity sourceSystem sourceContract mappingGeneration evidenceIdentity bodyDigest sourceUrl sourceEntityId sourceEntityName statementKind periodStart periodEnd reportingBasis unitsDescription retrievedAt facts metadata taxonomyRefs completeness
  use arg identityArg, sourceSystemArg, sourceContractArg, mappingArg, evidenceArg, digestArg, urlArg, entityIdArg, entityNameArg, kindArg, startArg, endArg, basisArg = "UNKNOWN", unitsArg = "SOURCE_NATIVE", retrievedArg = "", metadataArg = .nil, taxonomyRefsArg = .nil, completenessArg = .nil
  externalIdentity = .AccountingUtil~requireText(identityArg, "externalIdentity")
  sourceSystem = .AccountingUtil~requireText(sourceSystemArg, "sourceSystem")
  sourceContract = .AccountingUtil~requireText(sourceContractArg, "sourceContract")
  mappingGeneration = .AccountingUtil~requireText(mappingArg, "mappingGeneration")
  evidenceIdentity = .AccountingUtil~requireText(evidenceArg, "evidenceIdentity")
  bodyDigest = .AccountingUtil~requireText(digestArg, "bodyDigest")
  sourceUrl = urlArg~string
  sourceEntityId = .AccountingUtil~requireText(entityIdArg, "sourceEntityId")
  sourceEntityName = entityNameArg~string
  statementKind = .AccountingUtil~requireText(kindArg, "statementKind")~upper
  periodStart = startArg~string
  periodEnd = .AccountingUtil~requireDate(endArg, "external statement periodEnd")
  reportingBasis = basisArg~string
  unitsDescription = unitsArg~string
  retrievedAt = retrievedArg~string
  facts = .array~new
  metadata = .AccountingUtil~copyDirectory(metadataArg)
  taxonomyRefs = .AccountingUtil~copyArray(taxonomyRefsArg)
  completeness = .AccountingUtil~copyDirectory(completenessArg)

::method addFact
  expose facts
  use arg fact
  if fact == .nil | \fact~isA(.AccountingExternalFact) then raise syntax 93.900 additional("AccountingExternalFact required")
  facts~append(fact)
  return self

::method facts
  expose facts
  return .AccountingUtil~copyArray(facts)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::method taxonomyRefs
  expose taxonomyRefs
  return .AccountingUtil~copyArray(taxonomyRefs)

::method completeness
  expose completeness
  return .AccountingUtil~copyDirectory(completeness)

::method factCount
  expose facts
  return facts~items

::method factsByConcept
  expose facts
  use arg conceptId
  matches = .array~new
  do fact over facts
    if fact~conceptId = conceptId~string then matches~append(fact)
  end
  return matches

::method factsBySourceConcept
  expose facts
  use arg sourceConcept
  matches = .array~new
  wanted = sourceConcept~string
  do fact over facts
    if fact~sourceConcept = wanted then matches~append(fact)
  end
  return matches

::method factsByLocalConcept
  expose facts
  use arg localConcept
  matches = .array~new
  wanted = localConcept~string
  do fact over facts
    if fact~conceptLocalName = wanted then matches~append(fact)
  end
  return matches

::method primaryFactsBySourceConcept
  expose facts
  use arg sourceConcept
  matches = .array~new
  wanted = sourceConcept~string
  do fact over facts
    if fact~sourceConcept = wanted & \fact~isDuplicate then matches~append(fact)
  end
  return matches

::method factsAtInstant
  expose facts
  use arg instantDate
  matches = .array~new
  wanted = instantDate~string
  do fact over facts
    if fact~instantDate = wanted then matches~append(fact)
  end
  return matches

::method fingerprint
  expose externalIdentity sourceSystem sourceContract mappingGeneration evidenceIdentity bodyDigest sourceUrl sourceEntityId sourceEntityName statementKind periodStart periodEnd reportingBasis unitsDescription retrievedAt facts metadata taxonomyRefs completeness
  text = externalIdentity || "|" || sourceSystem || "|" || sourceContract || "|" || mappingGeneration || "|" || evidenceIdentity || "|" || bodyDigest || "|" || sourceUrl || "|" || sourceEntityId || "|" || sourceEntityName || "|" || statementKind || "|" || periodStart || "|" || periodEnd || "|" || reportingBasis || "|" || unitsDescription || "|" || retrievedAt || "|" || .AccountingUtil~canonicalDirectory(metadata) || "|" || .AccountingUtil~canonicalArray(taxonomyRefs) || "|" || .AccountingUtil~canonicalDirectory(completeness)
  do fact over facts
    text = text || "||" || fact~fingerprint
  end
  return text

::class AccountingAssessmentImportResult public
::attribute ok get
::attribute status get
::attribute statement get
::attribute errorCode get
::attribute message get
::method success class
  use arg statusArg, statementArg
  return self~new(.true, statusArg, statementArg, "", "")
::method failure class
  use arg codeArg, messageArg
  return self~new(.false, "REJECTED", .nil, codeArg, messageArg)
::method init
  expose ok status statement errorCode message
  use arg okArg, statusArg, statementArg, codeArg, messageArg
  ok=okArg; status=statusArg; statement=statementArg; errorCode=codeArg; message=messageArg

::class AccountingAssessmentBook public
::attribute assessmentEntityId get
::method init
  expose assessmentEntityId statements identityIndex
  use arg entityArg
  assessmentEntityId = .AccountingUtil~requireText(entityArg, "assessmentEntityId")
  statements = .array~new
  identityIndex = .directory~new

::method importStatement
  expose statements identityIndex
  use arg statement
  if statement == .nil | \statement~isA(.AccountingExternalStatement) then return .AccountingAssessmentImportResult~failure("STATEMENT_REQUIRED", "AccountingExternalStatement required")
  existing = identityIndex[statement~externalIdentity]
  if existing \== .nil then do
    if existing~fingerprint == statement~fingerprint then return .AccountingAssessmentImportResult~success("DUPLICATE", existing)
    return .AccountingAssessmentImportResult~failure("EXTERNAL_IDENTITY_CONFLICT", statement~externalIdentity)
  end
  statements~append(statement)
  identityIndex[statement~externalIdentity] = statement
  return .AccountingAssessmentImportResult~success("IMPORTED", statement)

::method statements
  expose statements
  return .AccountingUtil~copyArray(statements)

::method statementCount
  expose statements
  return statements~items

::method statement
  expose identityIndex
  use arg externalIdentity
  return identityIndex[externalIdentity~string]

::method latestFor
  expose statements
  use arg sourceEntityId, statementKind = ""
  best = .nil
  do s over statements
    if s~sourceEntityId \= sourceEntityId~string then iterate
    if statementKind~string \= "" & s~statementKind \= statementKind~string~upper then iterate
    if best == .nil | s~periodEnd > best~periodEnd then best = s
  end
  return best

::requires "AccountingCore.cls"
