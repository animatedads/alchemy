/*
 * Civic -> Accounting assessment adapter v0.2.
 *
 * No Civic classes are required here. Civic owns retrieval, source bytes,
 * immutable evidence and source-format parsing. Accounting consumes only the
 * normalized Companies House accounts projection contract.
 */

::options digits 50

::class AccountingCivicCompaniesHouseImport public
::constant CONTRACT "accounting.civic.companieshouse/0.2"
::constant EXPECTED_SOURCE_PREFIX "civic.companieshouse.accounts/"

::method fromProjection class
  use arg projection
  if projection == .nil then raise syntax 93.900 additional("Civic Companies House accounting projection required")

  sourceContract = self~required(projection, "contract_generation")
  if sourceContract~left(self~EXPECTED_SOURCE_PREFIX~length) \= self~EXPECTED_SOURCE_PREFIX then -
    raise syntax 93.900 additional("Unsupported Civic Companies House accounting contract: " || sourceContract)

  mappingGeneration = self~required(projection, "mapping_generation")
  evidenceIdentity = self~required(projection, "evidence_identity")
  bodyDigest = self~requiredSha512(projection, "body_sha512")
  companyNumber = self~required(projection, "company_number")
  periodEnd = self~required(projection, "period_end")
  statementKind = self~required(projection, "statement_kind")
  filingIdentity = self~required(projection, "filing_identity")
  sourceUrl = self~optional(projection, "source_url")
  companyName = self~optional(projection, "company_name")
  periodStart = self~optional(projection, "period_start")
  reportingBasis = self~optional(projection, "reporting_basis", "UNKNOWN")
  units = self~optional(projection, "units_description", "SOURCE_NATIVE")
  retrievedAt = self~optional(projection, "retrieved_at")

  metadata = .directory~new
  metadata["civic_import_contract"] = self~CONTRACT
  metadata["filing_identity"] = filingIdentity
  metadata["source_access_state"] = self~optional(projection, "access_state")
  metadata["source_cache_state"] = self~optional(projection, "cache_state")
  metadata["source_document_record_id"] = self~optional(projection, "body_record_id")
  metadata["source_observation_record_id"] = self~optional(projection, "observation_record_id")
  metadata["source_document_name"] = self~optional(projection, "source_document_name")
  metadata["source_content_type"] = self~optional(projection, "source_content_type")
  metadata["source_body_sha256"] = self~optional(projection, "body_sha256")
  metadata["filing_date"] = self~optional(projection, "filing_date")
  metadata["authorised_at"] = self~optional(projection, "authorised_at")

  taxonomyRefs = projection["taxonomy_refs"]
  if taxonomyRefs == .nil then taxonomyRefs = .array~new
  completeness = projection["completeness"]
  if completeness == .nil then completeness = .directory~new

  externalIdentity = "CIVIC-COMPANIES-HOUSE:" || companyNumber || ":" || filingIdentity || ":" || mappingGeneration
  statement = .AccountingExternalStatement~new(externalIdentity, "CIVIC", sourceContract, mappingGeneration, evidenceIdentity, bodyDigest, sourceUrl, companyNumber, companyName, statementKind, periodStart, periodEnd, reportingBasis, units, retrievedAt, metadata, taxonomyRefs, completeness)

  facts = projection["facts"]
  if facts == .nil then raise syntax 93.900 additional("Civic accounting projection requires facts")
  isV02 = sourceContract = "civic.companieshouse.accounts/0.2"
  do sourceFact over facts
    dimensions = sourceFact["dimensions"]
    provenance = sourceFact["provenance"]
    sourcePointer = self~optional(sourceFact, "source_pointer")
    if isV02 & sourcePointer = "" then raise syntax 93.900 additional("v0.2 Civic accounting facts require source_pointer")
    fact = .AccountingExternalFact~new(self~required(sourceFact, "concept_id"), self~requiredPresent(sourceFact, "lexical_value"), -
      self~optional(sourceFact, "value_type", "DECIMAL"), self~optional(sourceFact, "label"), self~optional(sourceFact, "currency"), -
      self~optional(sourceFact, "unit"), self~optional(sourceFact, "period_start"), self~optional(sourceFact, "period_end"), -
      self~optional(sourceFact, "instant_date"), sourcePointer, self~optional(sourceFact, "mapping_state", "REPORTED"), dimensions, provenance)
    statement~addFact(fact)
  end
  return statement

::method required class private
  use arg directory, key
  if \directory~hasIndex(key) then raise syntax 93.900 additional("Missing required projection field: " || key)
  return .AccountingUtil~requireText(directory[key], key)

/* Required-present differs from required-text: an XBRL lexical value may
 * intentionally be empty when its format/context carries the reported value. */
::method requiredPresent class private
  use arg directory, key
  if \directory~hasIndex(key) then raise syntax 93.900 additional("Missing required projection field: " || key)
  if directory[key] == .nil then return ""
  return directory[key]~string

::method requiredSha512 class private
  use arg directory, key
  value = self~required(directory, key)~lower
  if value~length \= 128 then raise syntax 93.900 additional(key || " must contain a 128-character SHA-512 hex digest")
  do i = 1 to value~length
    ch = value~substr(i, 1)
    if pos(ch, "0123456789abcdef") = 0 then raise syntax 93.900 additional(key || " contains non-hexadecimal characters")
  end
  return value

::method optional class private
  use arg directory, key, defaultValue = ""
  if \directory~hasIndex(key) then return defaultValue
  if directory[key] == .nil then return defaultValue
  return directory[key]~string

::requires "AccountingAssessment.cls"
