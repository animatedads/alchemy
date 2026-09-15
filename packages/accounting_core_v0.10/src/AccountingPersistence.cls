/*
 * Accounting persistence v0.6.
 *
 * Append-only JSONL store for one AccountingBook. Monetary amounts are
 * serialized as canonical integer strings. The store records the arithmetic
 * profile so recovery cannot silently change NUMERIC DIGITS semantics.
 */

::options digits 50

::class AccountingFileStore public
::constant RECORD_CONTRACT "accounting.store.record/0.1"

::attribute path get

::method init
  expose path nextSequence
  use arg pathArg
  path = .AccountingUtil~requireText(pathArg, "accounting store path")
  nextSequence = 1

::method createBook
  expose path nextSequence
  use arg entityArg, bookArg, basisArg = "ENTITY_GAAP"
  /* Explicit create truncates. Recovery never truncates. */
  stream = .stream~new(path)
  rc = stream~open("write replace")
  if rc \= "READY:" & rc \= "READY" then raise syntax 93.900 additional("Unable to create accounting store: " || rc)
  stream~close
  nextSequence = 1

  data = .directory~new
  data["legal_entity_id"] = .AccountingUtil~requireText(entityArg, "legalEntityId")
  data["book_id"] = .AccountingUtil~requireText(bookArg, "bookId")
  data["reporting_basis"] = .AccountingUtil~requireText(basisArg, "reportingBasis")
  data["arithmetic_profile"] = .AccountingBuild~ARITHMETIC_PROFILE
  data["numeric_digits"] = .AccountingBuild~NUMERIC_DIGITS~string
  data["amount_representation"] = "PREFIXED_INTEGER_MINOR_UNIT_STRING"
  self~appendRecord("BOOK_CREATED", data)
  return .AccountingBook~new(data["legal_entity_id"], data["book_id"], data["reporting_basis"], self)

::method recoverBook
  expose path nextSequence
  numeric digits 50
  stream = .stream~new(path)
  rc = stream~open("read")
  if rc \= "READY:" & rc \= "READY" then raise syntax 93.900 additional("Unable to open accounting store: " || rc)

  book = .nil
  expected = 1
  do while stream~lines > 0
    line = stream~linein
    if line~strip = "" then iterate
    record = .json~fromJSON(line)
    if \record~isA(.Directory) then raise syntax 93.900 additional("Invalid accounting store record")
    if self~required(record, "contract") \= self~RECORD_CONTRACT then raise syntax 93.900 additional("Unsupported accounting store record contract")
    seq = .AccountingUtil~requireWholeNonNegative(self~required(record, "sequence"), "store sequence")
    if seq \= expected then raise syntax 93.900 additional("Accounting store sequence gap: expected=" || expected || " actual=" || seq)
    recordType = self~required(record, "record_type")
    data = record["data"]
    if data == .nil then raise syntax 93.900 additional("Accounting store record data required")
    data = self~storageDecode(data)
    if \data~isA(.Directory) then raise syntax 93.900 additional("Accounting store record data required")

    select
      when recordType = "BOOK_CREATED" then do
        if book \== .nil then raise syntax 93.900 additional("Duplicate BOOK_CREATED record")
        if self~required(data, "arithmetic_profile") \= .AccountingBuild~ARITHMETIC_PROFILE then raise syntax 93.900 additional("Accounting arithmetic profile mismatch")
        if self~required(data, "numeric_digits") \= .AccountingBuild~NUMERIC_DIGITS~string then raise syntax 93.900 additional("Accounting numeric digits mismatch")
        if self~required(data, "amount_representation") \= "PREFIXED_INTEGER_MINOR_UNIT_STRING" then raise syntax 93.900 additional("Unsupported accounting amount representation")
        book = .AccountingBook~new(self~required(data, "legal_entity_id"), self~required(data, "book_id"), self~required(data, "reporting_basis"))
      end
      when recordType = "ACCOUNT_ADDED" then do
        self~requireBook(book)
        book~chart~add(self~accountFromProjection(data))
      end
      when recordType = "CHART_SEALED" then do
        self~requireBook(book)
        book~chart~seal
      end
      when recordType = "PERIOD_ADDED" then do
        self~requireBook(book)
        book~addPeriod(self~periodFromProjection(data))
      end
      when recordType = "PERIOD_STATE_CHANGED" then do
        self~requireBook(book)
        ev = data["evidence_refs"]; if ev == .nil then ev = .array~new
        book~transitionPeriod(self~required(data, "period_id"), self~required(data, "to_state"), self~optional(data, "actor_ref"), self~optional(data, "reason"), ev, self~optional(data, "occurred_at"))
      end
      when recordType = "JOURNAL_POSTED" then do
        self~requireBook(book)
        entryId = self~required(data, "entry_id")
        draftData = data["draft"]
        if draftData == .nil | \draftData~isA(.Directory) then raise syntax 93.900 additional("Stored journal draft required")
        result = book~post(self~draftFromProjection(draftData))
        if \result~ok then raise syntax 93.900 additional("Stored journal replay failed: " || result~errorCode || ":" || result~message)
        if result~entry~entryId \= entryId then raise syntax 93.900 additional("Stored journal entry identity mismatch: " || entryId || " != " || result~entry~entryId)
        if self~required(data, "draft_fingerprint") \= result~entry~fingerprint then raise syntax 93.900 additional("Stored journal fingerprint mismatch: " || entryId)
      end
      otherwise raise syntax 93.900 additional("Unsupported accounting store record type: " || recordType)
    end
    expected += 1
  end
  stream~close
  self~requireBook(book)
  nextSequence = expected
  book~attachStore(self)
  return book

::method appendAccount
  use arg book, account
  self~assertBook(book)
  data = self~accountProjection(account)
  self~appendRecord("ACCOUNT_ADDED", data)

::method appendChartSeal
  use arg book
  self~assertBook(book)
  data = .directory~new
  data["book_id"] = book~bookId
  self~appendRecord("CHART_SEALED", data)

::method appendPeriod
  use arg book, period
  self~assertBook(book)
  self~appendRecord("PERIOD_ADDED", self~periodProjection(period))

::method appendPeriodTransition
  use arg book, transitionSequence, periodId, fromState, toState, actorRef = "", reason = "", evidenceArg = .nil, occurredAt = ""
  self~assertBook(book)
  data = .directory~new
  data["transition_sequence"] = transitionSequence~string
  data["period_id"] = periodId~string
  data["from_state"] = fromState~string
  data["to_state"] = toState~string
  data["actor_ref"] = actorRef~string
  data["reason"] = reason~string
  data["evidence_refs"] = .AccountingUtil~copyArray(evidenceArg)
  data["occurred_at"] = occurredAt~string
  self~appendRecord("PERIOD_STATE_CHANGED", data)

::method appendJournal
  use arg book, entryId, draft
  self~assertBook(book)
  if draft == .nil | \draft~isA(.AccountingJournalDraft) then raise syntax 93.900 additional("AccountingJournalDraft required")
  data = .directory~new
  data["entry_id"] = entryId~string
  data["draft_fingerprint"] = draft~fingerprint
  data["draft"] = self~draftProjection(draft)
  self~appendRecord("JOURNAL_POSTED", data)

::method appendRecord private
  expose path nextSequence
  numeric digits 50
  use arg recordType, data
  record = .directory~new
  record["contract"] = self~RECORD_CONTRACT
  record["sequence"] = nextSequence~string
  record["record_type"] = recordType~string
  /* json.cls treats numeric-looking Rexx strings as JSON numbers. Encode every
   * persisted data scalar so opaque IDs, evidence and leading zeroes survive. */
  record["data"] = self~storageEncode(data)
  text = .json~toJSON(record)
  stream = .stream~new(path)
  rc = stream~open("write append")
  if rc \= "READY:" & rc \= "READY" then raise syntax 93.900 additional("Unable to append accounting store: " || rc)
  writeRc = stream~lineout(text)
  stream~close
  if writeRc \= 0 then raise syntax 93.900 additional("Unable to append accounting store record")
  nextSequence += 1
  return .true

::method accountProjection private
  use arg account
  data = .directory~new
  data["account_id"] = account~accountId
  data["name"] = account~name
  data["account_type"] = account~accountType
  data["normal_side"] = account~normalSide
  data["currency_mode"] = account~currencyMode
  data["account_currency"] = account~accountCurrency
  if account~active then data["active"] = "1"
  else data["active"] = "0"
  return data

::method accountFromProjection private
  use arg data
  active = self~required(data, "active") = "1"
  return .AccountingAccount~new(self~required(data, "account_id"), self~required(data, "name"), self~required(data, "account_type"), self~required(data, "normal_side"), self~required(data, "currency_mode"), active, self~optional(data, "account_currency"))

::method periodProjection private
  use arg period
  data = .directory~new
  data["period_id"] = period~periodId
  data["start_date"] = period~startDate
  data["end_date"] = period~endDate
  data["state"] = period~state
  return data

::method periodFromProjection private
  use arg data
  return .AccountingPeriod~new(self~required(data, "period_id"), self~required(data, "start_date"), self~required(data, "end_date"), self~required(data, "state"))

::method draftProjection private
  use arg draft
  data = .directory~new
  data["source_event_ref"] = draft~sourceEventRef
  data["correlation_ref"] = draft~correlationRef
  data["posting_date"] = draft~postingDate
  data["period_id"] = draft~periodId
  data["policy_ref"] = draft~policyRef
  data["narrative"] = draft~narrative
  data["reversal_of"] = draft~reversalOf
  data["policy_identity"] = draft~policyIdentity
  data["source_event_fingerprint"] = draft~sourceEventFingerprint
  data["event_type"] = draft~eventType
  data["counterparty_entity_id"] = draft~counterpartyEntityId
  data["evidence_refs"] = draft~evidenceRefs
  data["metadata"] = draft~metadata
  lines = .array~new
  do line over draft~lines
    lp = .directory~new
    lp["account_id"] = line~accountId
    lp["currency"] = line~currency
    /* Deliberately strings: no JSON numeric coercion is allowed for money. */
    lp["debit_minor"] = self~encodeAmount(line~debitMinor)
    lp["credit_minor"] = self~encodeAmount(line~creditMinor)
    lp["narrative"] = line~narrative
    lp["dimensions"] = line~dimensions
    lines~append(lp)
  end
  data["lines"] = lines
  return data

::method draftFromProjection private
  use arg data
  draft = .AccountingJournalDraft~new(self~required(data, "source_event_ref"), self~required(data, "posting_date"), self~required(data, "period_id"), self~required(data, "policy_ref"), self~optional(data, "narrative"), self~optional(data, "correlation_ref"), -
    self~arrayValue(data, "evidence_refs"), self~directoryValue(data, "metadata"), self~optional(data, "reversal_of"), self~optional(data, "policy_identity"), self~optional(data, "source_event_fingerprint"), self~optional(data, "event_type"), self~optional(data, "counterparty_entity_id"))
  lines = data["lines"]
  if lines == .nil | \lines~isA(.Array) then raise syntax 93.900 additional("Stored journal lines required")
  do lp over lines
    if \lp~isA(.Directory) then raise syntax 93.900 additional("Stored journal line must be a Directory")
    draft~addLine(.AccountingJournalLine~new(self~required(lp, "account_id"), self~required(lp, "currency"), self~decodeAmount(self~required(lp, "debit_minor")), self~decodeAmount(self~required(lp, "credit_minor")), self~optional(lp, "narrative"), self~directoryValue(lp, "dimensions")))
  end
  return draft

::method storageEncode private
  use arg value
  if value == .nil then return "N:"
  if value~isA(.Directory) then do
    target = .directory~new
    do key over value
      target[key] = self~storageEncode(value[key])
    end
    return target
  end
  if value~isA(.Array) then do
    target = .array~new
    do item over value
      target~append(self~storageEncode(item))
    end
    return target
  end
  if value~class~id = "JSONBoolean" then do
    if value~value then return "B:1"
    return "B:0"
  end
  return "S:" || value~string

::method storageDecode private
  use arg value
  if value == .nil then raise syntax 93.900 additional("Unexpected JSON null in accounting store")
  if value~isA(.Directory) then do
    target = .directory~new
    do key over value
      target[key] = self~storageDecode(value[key])
    end
    return target
  end
  if value~isA(.Array) then do
    target = .array~new
    do item over value
      target~append(self~storageDecode(item))
    end
    return target
  end
  text = value~string
  if text = "N:" then return .nil
  if text = "B:1" then return .json~true
  if text = "B:0" then return .json~false
  if text~length >= 2 & text~substr(1, 2) = "S:" then return text~substr(3)
  raise syntax 93.900 additional("Invalid accounting store scalar encoding")

::method encodeAmount private
  use arg amount
  return "I:" || .AccountingUtil~requireWholeNonNegative(amount, "stored monetary amount")

::method decodeAmount private
  use arg encoded
  text = encoded~string
  if text~length < 3 | text~substr(1, 2) \= "I:" then raise syntax 93.900 additional("Invalid stored monetary amount encoding")
  return .AccountingUtil~requireWholeNonNegative(text~substr(3), "stored monetary amount")

::method required private
  use arg source, key
  if \source~hasIndex(key) | source[key] == .nil then raise syntax 93.900 additional("Missing accounting store field: " || key)
  return source[key]~string

::method optional private
  use arg source, key
  if \source~hasIndex(key) | source[key] == .nil then return ""
  return source[key]~string

::method arrayValue private
  use arg source, key
  if \source~hasIndex(key) | source[key] == .nil then return .array~new
  if \source[key]~isA(.Array) then raise syntax 93.900 additional(key || " must be an Array")
  return source[key]

::method directoryValue private
  use arg source, key
  if \source~hasIndex(key) | source[key] == .nil then return .directory~new
  if \source[key]~isA(.Directory) then raise syntax 93.900 additional(key || " must be a Directory")
  return source[key]

::method assertBook private
  use arg book
  if book == .nil | \book~isA(.AccountingBook) then raise syntax 93.900 additional("AccountingBook required")
  return .true

::method requireBook private
  use arg book
  if book == .nil then raise syntax 93.900 additional("Accounting store missing BOOK_CREATED record")
  return .true

::requires "AccountingCore.cls"
::requires "json.cls"
