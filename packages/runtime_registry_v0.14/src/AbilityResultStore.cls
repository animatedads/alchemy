/* Ability Result Store v0.1
 *
 * Materialised query/evaluation resources above AbilityRegistry.
 * A result owns the exact AbilitySession which created it until DELETE/expiry.
 * Rich evidence objects remain live in-process and are exposed externally only
 * through stable evidence references plus bounded JSON projections.
 */

::class AbilityResultStoreBuild public
::constant PRODUCT "ooRexx Ability Result Store"
::constant RELEASE "0.2"
::constant API_VERSION "ability.result/0.2"

::class AbilityEvidenceRecord public
::attribute evidenceId get
::attribute resultId get
::attribute rawObject get

::method init
  expose evidenceId resultId rawObject
  use arg evidenceIdArg, resultIdArg, rawObjectArg
  evidenceId = evidenceIdArg~string
  resultId = resultIdArg~string
  rawObject = rawObjectArg

::method summary
  expose evidenceId resultId rawObject
  d = .directory~new
  d["evidence_id"] = evidenceId
  d["evidence_uri"] = "/v1/evidence/" || evidenceId
  d["result_id"] = resultId
  if rawObject~hasMethod("VALUE") then d["value"] = rawObject~value
  if rawObject~hasMethod("NAME") then d["name"] = rawObject~name
  if rawObject~hasMethod("SEMANTICTYPE") then d["semantic_type"] = rawObject~semanticType
  if rawObject~hasMethod("STATE") then d["state"] = rawObject~state
  return d

::method detail
  expose evidenceId resultId rawObject
  d = self~summary
  if rawObject~hasMethod("LEXICALVALUE") then do
    lexical = rawObject~lexicalValue
    if lexical \== .nil then d["lexical_value"] = lexical
  end
  if rawObject~hasMethod("ISEVIDENCEBEARING") then d["evidence_bearing"] = rawObject~isEvidenceBearing

  source = .directory~new
  hasSource = .false
  if rawObject~hasMethod("SOURCEPATH") then do
    sourcePath = rawObject~sourcePath
    if sourcePath <> "" then do
      source["path"] = sourcePath
      hasSource = .true
    end
  end
  if rawObject~hasMethod("SOURCEDOCUMENT") then do
    doc = rawObject~sourceDocument
    if doc \== .nil then do
      if doc~hasMethod("SOURCE") then source["document"] = doc~source
      else source["document"] = doc~string
      hasSource = .true
    end
  end
  if hasSource then d["source"] = source

  /* Provider-neutral structured provenance.  The result store does not need to
   * understand NoSQLServer, Camera, Librarian, XML, EDI, or another provider;
   * evidence objects may expose a detached Directory through PROVENANCE. */
  if rawObject~hasMethod("PROVENANCE") then do
    provenance = rawObject~provenance
    if provenance \== .nil then d["provenance"] = provenance
  end
  return d


::class AbilityMaterializedResult public
::attribute resultId get
::attribute kind get
::attribute clientId get
::attribute profileId get
::attribute revision get
::attribute abilityGeneration get
::attribute environment get
::attribute abilityId get
::attribute createdAt get
::attribute expiresAt get
::attribute projectedValue get
::attribute rawValue get
::attribute rows get
::attribute evidenceIds get
::attribute executionMetadata get
::attribute released get

::method init
  expose resultId kind clientId profileId revision abilityGeneration environment abilityId createdAt expiresAt projectedValue rawValue rows evidenceIds executionMetadata session released expiryObject
  use arg resultIdArg, kindArg, sessionArg, abilityIdArg, rawValueArg, projectedValueArg, rowsArg, evidenceIdsArg, ttlSeconds, executionMetadataArg = .nil
  resultId = resultIdArg~string
  kind = kindArg~string~lower
  session = sessionArg
  clientId = session~clientId
  profileId = session~profileId
  revision = session~revision
  abilityGeneration = session~generationId
  environment = session~environment
  abilityId = abilityIdArg~string
  rawValue = rawValueArg
  projectedValue = projectedValueArg
  rows = rowsArg
  evidenceIds = evidenceIdsArg
  executionMetadata = executionMetadataArg
  created = .DateTime~new
  createdAt = created~utcIsoDate
  expires = created~addSeconds(ttlSeconds)
  expiresAt = expires~utcIsoDate
  /* Keep the DateTime object private for compare semantics. */
  expiryObject = expires
  released = .false

::attribute expiryObject private

::method expired
  expose expiryObject released
  if released then return .true
  now = .DateTime~new
  if now~compareTo(expiryObject) >= 0 then return .true
  return .false

::method descriptor
  expose resultId kind clientId profileId revision abilityGeneration environment abilityId createdAt expiresAt projectedValue evidenceIds rows executionMetadata
  d = .directory~new
  d["id"] = resultId
  d["kind"] = kind
  d["uri"] = "/v1/" || self~pluralKind || "/" || resultId
  d["client_id"] = clientId
  d["profile_id"] = profileId
  d["profile_revision"] = revision
  d["ability_generation"] = abilityGeneration
  d["environment"] = environment
  d["ability"] = abilityId
  d["created_at"] = createdAt
  d["expires_at"] = expiresAt
  d["result"] = projectedValue
  d["row_count"] = rows~items
  d["evidence_count"] = evidenceIds~items
  if executionMetadata \== .nil then d["execution"] = executionMetadata
  return d

::method pluralKind private
  expose kind
  if kind = "query" then return "queries"
  if kind = "evaluation" then return "evaluations"
  return kind || "s"

::method release
  expose session released rawValue projectedValue rows evidenceIds executionMetadata
  if released then return .RuntimeResult~success
  released = .true
  if session \== .nil then do
    releaseResult = session~release
    session = .nil
  end
  rawValue = .nil
  projectedValue = .nil
  rows = .array~new
  evidenceIds = .array~new
  executionMetadata = .nil
  return .RuntimeResult~success

::method uninit
  ignored = self~release


::class AbilityResultStore public
::attribute defaultTtlSeconds get
::attribute maxResults get

::method init
  expose defaultTtlSeconds maxResults results evidence nextResultSequence
  use arg defaultTtlSecondsArg = 300, maxResultsArg = 1000
  defaultTtlSeconds = defaultTtlSecondsArg
  maxResults = maxResultsArg
  if \datatype(defaultTtlSeconds, "W") then raise syntax 88.900 array("result TTL must be a whole number")
  if defaultTtlSeconds < 1 then raise syntax 88.900 array("result TTL must be positive")
  if \datatype(maxResults, "W") then raise syntax 88.900 array("maxResults must be a whole number")
  if maxResults < 1 then raise syntax 88.900 array("maxResults must be positive")
  results = .table~new
  evidence = .table~new
  nextResultSequence = 1

::method create
  expose defaultTtlSeconds maxResults results evidence nextResultSequence
  use arg kind, session, abilityId, rawValue, ttlSeconds = .nil, executionMetadata = .nil
  ignored = self~collectExpired
  if results~items >= maxResults then return .RuntimeResult~failure("RESULT_STORE_FULL", "materialised result limit reached")
  kind = kind~string~strip~lower
  if kind <> "query" then do
    if kind <> "evaluation" then return .RuntimeResult~failure("RESULT_KIND_INVALID", kind)
  end
  if ttlSeconds == .nil then ttlSeconds = defaultTtlSeconds
  if \datatype(ttlSeconds, "W") then return .RuntimeResult~failure("RESULT_TTL_INVALID", ttlSeconds)
  if ttlSeconds < 1 then return .RuntimeResult~failure("RESULT_TTL_INVALID", ttlSeconds)

  sequence = nextResultSequence
  nextResultSequence = nextResultSequence + 1
  if kind = "query" then prefix = "qry-"
  else prefix = "eval-"
  resultId = prefix || right(sequence, 8, "0")

  evidenceIds = .array~new
  projected = self~projectValue(rawValue, resultId, evidenceIds)
  rows = self~deriveRows(projected)
  materialized = .AbilityMaterializedResult~new(resultId, kind, session, abilityId, rawValue, projected, rows, evidenceIds, ttlSeconds, executionMetadata)
  results~put(materialized, resultId)
  return .RuntimeResult~success(materialized)

::method projectValue private
  expose evidence
  use arg value, resultId, evidenceIds
  if value == .nil then return .nil

  if value~isa(.Directory) then do
    out = .directory~new
    supplier = value~supplier
    do while supplier~available
      out[supplier~index] = self~projectValue(supplier~item, resultId, evidenceIds)
      supplier~next
    end
    return out
  end

  if value~isa(.Array) then do
    out = .array~new
    do i = 1 to value~items
      out~append(self~projectValue(value~at(i), resultId, evidenceIds))
    end
    return out
  end

  if value~hasMethod("ISEVIDENCEBEARING") then do
    if value~isEvidenceBearing then do
      ordinal = evidenceIds~items + 1
      evidenceId = resultId || "-ev-" || right(ordinal, 8, "0")
      record = .AbilityEvidenceRecord~new(evidenceId, resultId, value)
      evidence~put(record, evidenceId)
      evidenceIds~append(evidenceId)
      return record~summary
    end
  end
  return value

::method deriveRows private
  use arg projected
  if projected == .nil then return .array~new
  if projected~isa(.Array) then return projected
  if projected~isa(.Directory) then do
    candidate = projected~at("rows")
    if candidate \== .nil then do
      if candidate~isa(.Array) then return candidate
    end
  end
  return .array~of(projected)

::method getResult
  expose results
  use arg clientId, resultId, expectedKind = ""
  id = resultId~string~strip
  item = results~at(id)
  if item == .nil then return .RuntimeResult~failure("RESULT_NOT_FOUND", id)
  if item~clientId <> clientId~string~strip~lower then return .RuntimeResult~failure("RESULT_NOT_FOUND", id)
  if expectedKind <> "" then do
    if item~kind <> expectedKind~string~lower then return .RuntimeResult~failure("RESULT_NOT_FOUND", id)
  end
  if item~expired then do
    ignored = self~removeInternal(id)
    return .RuntimeResult~failure("RESULT_EXPIRED", id)
  end
  return .RuntimeResult~success(item)

::method getEvidence
  expose evidence results
  use arg clientId, evidenceId
  id = evidenceId~string~strip
  record = evidence~at(id)
  if record == .nil then return .RuntimeResult~failure("EVIDENCE_NOT_FOUND", id)
  ownerResult = results~at(record~resultId)
  if ownerResult == .nil then return .RuntimeResult~failure("EVIDENCE_NOT_FOUND", id)
  if ownerResult~clientId <> clientId~string~strip~lower then return .RuntimeResult~failure("EVIDENCE_NOT_FOUND", id)
  if ownerResult~expired then do
    ignored = self~removeInternal(ownerResult~resultId)
    return .RuntimeResult~failure("EVIDENCE_NOT_FOUND", id)
  end
  return .RuntimeResult~success(record)

::method evidenceForResult
  expose evidence
  use arg clientId, resultId, expectedKind = ""
  lookup = self~getResult(clientId, resultId, expectedKind)
  if \lookup~ok then return lookup
  item = lookup~value
  output = .array~new
  ids = item~evidenceIds
  do i = 1 to ids~items
    record = evidence~at(ids~at(i))
    if record \== .nil then output~append(record~summary)
  end
  return .RuntimeResult~success(output)

::method page
  use arg clientId, resultId, offset, limit
  lookup = self~getResult(clientId, resultId, "query")
  if \lookup~ok then return lookup
  item = lookup~value
  if \datatype(offset, "W") then return .RuntimeResult~failure("CURSOR_INVALID", offset)
  if \datatype(limit, "W") then return .RuntimeResult~failure("LIMIT_INVALID", limit)
  if offset < 0 then return .RuntimeResult~failure("CURSOR_INVALID", offset)
  if limit < 1 then return .RuntimeResult~failure("LIMIT_INVALID", limit)
  rows = item~rows
  if offset > rows~items then return .RuntimeResult~failure("CURSOR_INVALID", offset)
  pageRows = .array~new
  start = offset + 1
  stop = offset + limit
  if stop > rows~items then stop = rows~items
  do i = start to stop
    if i >= 1 then pageRows~append(rows~at(i))
  end
  nextOffset = stop
  nextCursor = .nil
  if nextOffset < rows~items then nextCursor = "c." || nextOffset
  d = .directory~new
  d["id"] = item~resultId
  d["items"] = pageRows
  d["count"] = pageRows~items
  d["total"] = rows~items
  d["next_cursor"] = nextCursor
  return .RuntimeResult~success(d)

::method deleteResult
  use arg clientId, resultId
  lookup = self~getResult(clientId, resultId)
  if \lookup~ok then return lookup
  return self~removeInternal(resultId)

::method collectExpired
  expose results
  ids = .array~new
  supplier = results~supplier
  do while supplier~available
    item = supplier~item
    if item~expired then ids~append(supplier~index)
    supplier~next
  end
  do i = 1 to ids~items
    ignored = self~removeInternal(ids~at(i))
  end
  return .RuntimeResult~success(ids~items)

::method removeInternal private
  expose results evidence
  use arg resultId
  item = results~at(resultId)
  if item == .nil then return .RuntimeResult~failure("RESULT_NOT_FOUND", resultId)
  ids = item~evidenceIds
  do i = 1 to ids~items
    ignoredEvidence = evidence~remove(ids~at(i))
  end
  ignoredResult = results~remove(resultId)
  releaseResult = item~release
  return .RuntimeResult~success

::method resultCount
  expose results
  ignored = self~collectExpired
  return results~items

::requires "AbilityRegistry.cls"
