/*
 * Accounting Core v0.10
 *
 * Reusable legal-entity accounting mechanics for demo companies.
 * Operational engines remain authoritative for their own economic events.
 * Each legal entity owns an independent AccountingBook.
 */

::options digits 50

::class AccountingBuild public
::constant VERSION "0.10"
::constant CORE_API "accounting.core/0.1"
::constant POSTING_API "accounting.posting/0.2"
::constant EVENT_API "accounting.event/0.1"
::constant TRANSACTION_API "accounting.transaction/0.1"
::constant ASSESSMENT_API "accounting.assessment/0.2"
::constant STORE_API "accounting.store/0.1"
::constant SCOPE_API "accounting.scope/0.1"
::constant REPORTING_API "accounting.reporting/0.1"
::constant REPORTING_SNAPSHOT_API "accounting.reporting.snapshot/0.1"
::constant REPORTING_ATTESTATION_API "accounting.reporting.attestation/0.1"
::constant REPORTING_SUBMISSION_API "accounting.reporting.submission/0.1"
::constant REPORTING_FILING_API "accounting.reporting.filing/0.1"
::constant REPORTING_LIFECYCLE_API "accounting.reporting.lifecycle/0.1"
::constant TAX_API "accounting.tax/0.1"
::constant TAX_REQUEST_API "accounting.tax.request/0.1"
::constant TAX_DETERMINATION_API "accounting.tax.determination/0.1"
::constant SETTLEMENT_API "accounting.settlement/0.1"
::constant SETTLEMENT_REQUEST_API "accounting.settlement.request/0.1"
::constant SETTLEMENT_DETERMINATION_API "accounting.settlement.determination/0.1"
::constant ARITHMETIC_PROFILE "accounting.integer-minor-unit.numeric-digits-50/0.1"
::constant NUMERIC_DIGITS 50

::class AccountingUtil public
::method requireText class
  use arg value, label
  text = value~string~strip
  if text = "" then raise syntax 93.900 additional(label || " is required")
  return text

::method requireDate class
  use arg value, label
  text = self~requireText(value, label)
  if text~length \= 10 | text~substr(5,1) \= "-" | text~substr(8,1) \= "-" then -
    raise syntax 93.900 additional(label || " must be YYYY-MM-DD")
  return text

::method requireWholeNonNegative class
  use arg value, label
  numeric digits 50
  text = value~string~strip
  if \datatype(text, "W") then raise syntax 93.900 additional(label || " must be a whole-number minor-unit amount")
  if text < 0 then raise syntax 93.900 additional(label || " must not be negative")
  if text~substr(1, 1) = "+" then text = text~substr(2)
  do while text~length > 1 & text~substr(1, 1) = "0"
    text = text~substr(2)
  end
  if text = "-0" then text = "0"
  if text~length > 50 then raise syntax 93.900 additional(label || " exceeds accounting numeric digits 50")
  /* Keep amounts as exact canonical integer strings. Arithmetic methods
   * explicitly enter NUMERIC DIGITS 50 before operating on them. */
  return text

::method requireWholeSigned class
  use arg value, label
  numeric digits 50
  text = value~string~strip
  if \datatype(text, "W") then raise syntax 93.900 additional(label || " must be a whole-number amount")
  sign = ""
  if text~substr(1, 1) = "+" then text = text~substr(2)
  else if text~substr(1, 1) = "-" then do
    sign = "-"
    text = text~substr(2)
  end
  do while text~length > 1 & text~substr(1, 1) = "0"
    text = text~substr(2)
  end
  if text = "0" then sign = ""
  if text~length > 50 then raise syntax 93.900 additional(label || " exceeds accounting numeric digits 50")
  return sign || text

::method arithmeticProfile class
  return .AccountingBuild~ARITHMETIC_PROFILE

::method arithmeticDigits class
  return .AccountingBuild~NUMERIC_DIGITS

::method copyDirectory class
  use arg source
  target = .directory~new
  if source == .nil then return target
  if \source~isA(.Directory) then raise syntax 93.900 additional("Directory required")
  do key over source
    target[key] = self~copyValue(source[key])
  end
  return target

::method copyArray class
  use arg source
  target = .array~new
  if source == .nil then return target
  if \source~isA(.Array) then raise syntax 93.900 additional("Array required")
  do item over source
    target~append(self~copyValue(item))
  end
  return target

::method copyValue class
  use arg value
  if value == .nil then return .nil
  if value~isA(.Directory) then return self~copyDirectory(value)
  if value~isA(.Array) then return self~copyArray(value)
  return value

::method canonicalDirectory class
  use arg source
  if source == .nil | source~items = 0 then return "D{}"
  names = source~allIndexes
  names~sort
  text = "D{"
  do name over names
    text = text || self~escape(name) || "=" || self~canonicalValue(source[name]) || ";"
  end
  return text || "}"

::method canonicalArray class
  use arg source
  if source == .nil | source~items = 0 then return "A[]"
  text = "A["
  do item over source
    text = text || self~canonicalValue(item) || ";"
  end
  return text || "]"

/* Fingerprints must include nested imported evidence, not object display
 * strings such as "an Array". JSONBoolean is handled without creating a
 * runtime dependency on json.cls. */
::method canonicalValue class
  use arg value
  if value == .nil then return "N:"
  if value~isA(.Directory) then return self~canonicalDirectory(value)
  if value~isA(.Array) then return self~canonicalArray(value)
  if value~class~id = "JSONBoolean" then return "B:" || value~value
  return "S:" || self~escape(value)

::method escape class private
  use arg value
  text = value~string
  text = text~changestr("\", "\\")
  text = text~changestr("|", "\|")
  text = text~changestr(";", "\;")
  text = text~changestr("=", "\=")
  return text

::class AccountingAccount public
::attribute accountId get
::attribute name get
::attribute accountType get
::attribute normalSide get
::attribute currencyMode get
::attribute accountCurrency get
::attribute active get
::method init
  expose accountId name accountType normalSide currencyMode accountCurrency active
  use arg idArg, nameArg, typeArg, normalArg = "AUTO", currencyModeArg = "MULTI", activeArg = .true, accountCurrencyArg = ""
  accountId = .AccountingUtil~requireText(idArg, "accountId")
  name = .AccountingUtil~requireText(nameArg, "account name")
  accountType = typeArg~string~strip~upper
  if wordpos(accountType, "ASSET LIABILITY EQUITY REVENUE EXPENSE MEMO") = 0 then -
    raise syntax 93.900 additional("Unsupported account type: " || accountType)
  normalSide = normalArg~string~strip~upper
  if normalSide = "AUTO" then do
    if wordpos(accountType, "ASSET EXPENSE") > 0 then normalSide = "DEBIT"
    else normalSide = "CREDIT"
  end
  if wordpos(normalSide, "DEBIT CREDIT") = 0 then raise syntax 93.900 additional("normalSide must be DEBIT or CREDIT")
  currencyMode = currencyModeArg~string~strip~upper
  if wordpos(currencyMode, "MULTI SINGLE NONE") = 0 then raise syntax 93.900 additional("currencyMode must be MULTI, SINGLE or NONE")
  accountCurrency = accountCurrencyArg~string~strip~upper
  if currencyMode = "SINGLE" then accountCurrency = .AccountingUtil~requireText(accountCurrency, "single-currency account currency")~upper
  else if accountCurrency \= "" then raise syntax 93.900 additional("accountCurrency is valid only for SINGLE currencyMode")
  active = activeArg

::class AccountingChartOfAccounts public
::method init
  expose accounts sealed ownerBook
  use arg ownerArg = .nil
  accounts = .directory~new
  sealed = .false
  ownerBook = ownerArg

::method add
  expose accounts sealed ownerBook
  use arg account
  if sealed then raise syntax 93.900 additional("Chart of accounts is sealed")
  if account == .nil | \account~isA(.AccountingAccount) then raise syntax 93.900 additional("AccountingAccount required")
  id = account~accountId
  if accounts~hasIndex(id) then raise syntax 93.900 additional("Duplicate account: " || id)
  if ownerBook \== .nil then ownerBook~beforeAccountAdd(account)
  accounts[id] = account
  return account

::method get
  expose accounts
  use arg accountId
  return accounts[accountId~string]

::method contains
  expose accounts
  use arg accountId
  return accounts~hasIndex(accountId~string)

::method seal
  expose sealed ownerBook
  if sealed then return self
  if ownerBook \== .nil then ownerBook~beforeChartSeal
  sealed = .true
  return self

::method isSealed
  expose sealed
  return sealed

::method accountIds
  expose accounts
  ids = accounts~allIndexes
  ids~sort
  return ids

::class AccountingPeriod public
::attribute periodId get
::attribute startDate get
::attribute endDate get
::attribute state get
::method init
  expose periodId startDate endDate state ownerBook
  use arg idArg, startArg, endArg, stateArg = "OPEN"
  ownerBook = .nil
  periodId = .AccountingUtil~requireText(idArg, "periodId")
  startDate = .AccountingUtil~requireDate(startArg, "period start")
  endDate = .AccountingUtil~requireDate(endArg, "period end")
  if endDate < startDate then raise syntax 93.900 additional("period end precedes period start")
  state = stateArg~string~strip~upper
  if wordpos(state, "OPEN CLOSED LOCKED") = 0 then raise syntax 93.900 additional("period state must be OPEN, CLOSED or LOCKED")

::method containsDate
  expose startDate endDate
  use arg postingDate
  d = .AccountingUtil~requireDate(postingDate, "postingDate")
  return d >= startDate & d <= endDate

::method attachBook
  expose ownerBook
  use arg ownerArg
  if ownerArg == .nil | \ownerArg~isA(.AccountingBook) then raise syntax 93.900 additional("AccountingBook required for period attachment")
  if ownerBook \== .nil & ownerBook \== ownerArg then raise syntax 93.900 additional("Accounting period is already attached to another book")
  ownerBook = ownerArg
  return self

::method close
  expose state ownerBook
  use arg actorRef = "", reason = "", evidenceArg = .nil, occurredAt = ""
  if ownerBook \== .nil then return ownerBook~transitionPeriod(self~periodId, "CLOSED", actorRef, reason, evidenceArg, occurredAt)
  if state = "LOCKED" then raise syntax 93.900 additional("Locked period cannot be reopened or closed")
  state = "CLOSED"
  return self

::method open
  expose state ownerBook
  use arg actorRef = "", reason = "", evidenceArg = .nil, occurredAt = ""
  if ownerBook \== .nil then return ownerBook~transitionPeriod(self~periodId, "OPEN", actorRef, reason, evidenceArg, occurredAt)
  if state = "LOCKED" then raise syntax 93.900 additional("Locked period cannot be reopened")
  state = "OPEN"
  return self

::method lock
  expose state ownerBook
  use arg actorRef = "", reason = "", evidenceArg = .nil, occurredAt = ""
  if ownerBook \== .nil then return ownerBook~transitionPeriod(self~periodId, "LOCKED", actorRef, reason, evidenceArg, occurredAt)
  state = "LOCKED"
  return self

::method applyState
  expose state ownerBook
  use arg newState, authority = .nil
  if ownerBook \== .nil & authority \== ownerBook then raise syntax 93.900 additional("Accounting period state may only be applied by its owning book")
  state = newState~string~strip~upper
  return self

::class AccountingJournalLine public
::attribute accountId get
::attribute currency get
::attribute debitMinor get
::attribute creditMinor get
::attribute narrative get
::method init
  expose accountId currency debitMinor creditMinor narrative dimensions
  use arg accountArg, currencyArg, debitArg = 0, creditArg = 0, narrativeArg = "", dimensionsArg = .nil
  numeric digits 50
  accountId = .AccountingUtil~requireText(accountArg, "journal line accountId")
  currency = .AccountingUtil~requireText(currencyArg, "journal line currency")~upper
  debitMinor = .AccountingUtil~requireWholeNonNegative(debitArg, "debitMinor")
  creditMinor = .AccountingUtil~requireWholeNonNegative(creditArg, "creditMinor")
  if debitMinor = 0 & creditMinor = 0 then raise syntax 93.900 additional("Journal line requires a debit or credit amount")
  if debitMinor > 0 & creditMinor > 0 then raise syntax 93.900 additional("Journal line cannot contain both debit and credit")
  narrative = narrativeArg~string
  dimensions = .AccountingUtil~copyDirectory(dimensionsArg)

::method dimensions
  expose dimensions
  return .AccountingUtil~copyDirectory(dimensions)

::method fingerprint
  expose accountId currency debitMinor creditMinor narrative dimensions
  return accountId || "|" || currency || "|" || debitMinor || "|" || creditMinor || "|" || narrative || "|" || .AccountingUtil~canonicalDirectory(dimensions)

::class AccountingJournalDraft public
::attribute sourceEventRef get
::attribute correlationRef get
::attribute postingDate get
::attribute periodId get
::attribute policyRef get
::attribute narrative get
::attribute reversalOf get
::attribute policyIdentity get
::attribute sourceEventFingerprint get
::attribute eventType get
::attribute counterpartyEntityId get
::method init
  expose sourceEventRef correlationRef postingDate periodId policyRef narrative reversalOf policyIdentity sourceEventFingerprint eventType counterpartyEntityId lines evidenceRefs metadata
  use arg sourceArg, dateArg, periodArg, policyArg, narrativeArg = "", correlationArg = "", evidenceArg = .nil, metadataArg = .nil, reversalArg = "", policyIdentityArg = "", sourceEventFingerprintArg = "", eventTypeArg = "", counterpartyEntityIdArg = ""
  sourceEventRef = .AccountingUtil~requireText(sourceArg, "sourceEventRef")
  postingDate = .AccountingUtil~requireDate(dateArg, "postingDate")
  periodId = .AccountingUtil~requireText(periodArg, "periodId")
  policyRef = .AccountingUtil~requireText(policyArg, "policyRef")
  narrative = narrativeArg~string
  correlationRef = correlationArg~string
  reversalOf = reversalArg~string
  policyIdentity = policyIdentityArg~string
  sourceEventFingerprint = sourceEventFingerprintArg~string
  eventType = eventTypeArg~string~strip~upper
  counterpartyEntityId = counterpartyEntityIdArg~string~strip
  lines = .array~new
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  metadata = .AccountingUtil~copyDirectory(metadataArg)

::method addLine
  expose lines
  use arg line
  if line == .nil | \line~isA(.AccountingJournalLine) then raise syntax 93.900 additional("AccountingJournalLine required")
  lines~append(line)
  return self

::method lineCount
  expose lines
  return lines~items

::method lines
  expose lines
  return .AccountingUtil~copyArray(lines)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::method fingerprint
  expose sourceEventRef correlationRef postingDate periodId policyRef narrative reversalOf policyIdentity sourceEventFingerprint eventType counterpartyEntityId lines evidenceRefs metadata
  text = sourceEventRef || "|" || correlationRef || "|" || postingDate || "|" || periodId || "|" || policyRef || "|" || policyIdentity || "|" || sourceEventFingerprint || "|" || eventType || "|" || counterpartyEntityId || "|" || narrative || "|" || reversalOf || "|"
  do line over lines
    text = text || line~fingerprint || "||"
  end
  text = text || .AccountingUtil~canonicalArray(evidenceRefs) || "|" || .AccountingUtil~canonicalDirectory(metadata)
  return text

::class AccountingJournalEntry public
::attribute entryId get
::attribute legalEntityId get
::attribute sourceEventRef get
::attribute correlationRef get
::attribute postingDate get
::attribute periodId get
::attribute policyRef get
::attribute narrative get
::attribute reversalOf get
::attribute fingerprint get
::attribute policyIdentity get
::attribute sourceEventFingerprint get
::attribute eventType get
::attribute counterpartyEntityId get
::method init
  expose entryId legalEntityId sourceEventRef correlationRef postingDate periodId policyRef narrative reversalOf fingerprint policyIdentity sourceEventFingerprint eventType counterpartyEntityId lines evidenceRefs metadata
  use arg entryIdArg, entityArg, draft
  entryId = entryIdArg~string
  legalEntityId = entityArg~string
  sourceEventRef = draft~sourceEventRef
  correlationRef = draft~correlationRef
  postingDate = draft~postingDate
  periodId = draft~periodId
  policyRef = draft~policyRef
  narrative = draft~narrative
  reversalOf = draft~reversalOf
  fingerprint = draft~fingerprint
  policyIdentity = draft~policyIdentity
  sourceEventFingerprint = draft~sourceEventFingerprint
  eventType = draft~eventType
  counterpartyEntityId = draft~counterpartyEntityId
  lines = draft~lines
  evidenceRefs = draft~evidenceRefs
  metadata = draft~metadata

::method lines
  expose lines
  return .AccountingUtil~copyArray(lines)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::class AccountingPostingResult public
::attribute ok get
::attribute status get
::attribute entry get
::attribute errorCode get
::attribute message get
::method success class
  use arg statusArg, entryArg
  return self~new(.true, statusArg, entryArg, "", "")
::method failure class
  use arg codeArg, messageArg
  return self~new(.false, "REJECTED", .nil, codeArg, messageArg)
::method init
  expose ok status entry errorCode message
  use arg okArg, statusArg, entryArg, codeArg, messageArg
  ok = okArg; status = statusArg; entry = entryArg; errorCode = codeArg; message = messageArg

::class AccountingPeriodTransition public
::attribute sequence get
::attribute periodId get
::attribute fromState get
::attribute toState get
::attribute actorRef get
::attribute reason get
::attribute occurredAt get
::method init
  expose sequence periodId fromState toState actorRef reason occurredAt evidenceRefs
  use arg sequenceArg, periodArg, fromArg, toArg, actorArg = "", reasonArg = "", evidenceArg = .nil, occurredArg = ""
  sequence = sequenceArg
  periodId = periodArg~string
  fromState = fromArg~string~upper
  toState = toArg~string~upper
  actorRef = actorArg~string
  reason = reasonArg~string
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  occurredAt = occurredArg~string

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::class AccountingTrialBalanceRow public
::attribute accountId get
::attribute currency get
::attribute debitMinor get
::attribute creditMinor get
::attribute netDebitMinor get
::method init
  expose accountId currency debitMinor creditMinor netDebitMinor
  use arg accountArg, currencyArg, debitArg, creditArg
  numeric digits 50
  accountId = accountArg; currency = currencyArg; debitMinor = debitArg + 0; creditMinor = creditArg + 0
  netDebitMinor = debitMinor - creditMinor

::class AccountingBook public
::attribute legalEntityId get
::attribute bookId get
::attribute reportingBasis get
::attribute arithmeticProfile get
::method init
  expose legalEntityId bookId reportingBasis arithmeticProfile chart periods entries sourceIndex balances nextEntryNumber store periodTransitions nextTransitionSequence
  use arg entityArg, bookArg, basisArg = "ENTITY_GAAP", storeArg = .nil
  legalEntityId = .AccountingUtil~requireText(entityArg, "legalEntityId")
  bookId = .AccountingUtil~requireText(bookArg, "bookId")
  reportingBasis = .AccountingUtil~requireText(basisArg, "reportingBasis")
  arithmeticProfile = .AccountingBuild~ARITHMETIC_PROFILE
  chart = .AccountingChartOfAccounts~new(self)
  periods = .directory~new
  entries = .array~new
  sourceIndex = .directory~new
  balances = .directory~new
  periodTransitions = .array~new
  nextEntryNumber = 1
  nextTransitionSequence = 1
  store = storeArg

::method attachStore
  expose store
  use arg storeArg
  if storeArg == .nil then raise syntax 93.900 additional("Accounting store attachment cannot be removed")
  if store \== .nil & store \== storeArg then raise syntax 93.900 additional("Accounting book is already attached to a different store")
  store = storeArg
  return self

::method store
  expose store
  return store

::method chart
  expose chart
  return chart

::method beforeAccountAdd
  expose store
  use arg account
  if store \== .nil then store~appendAccount(self, account)
  return .true

::method beforeChartSeal
  expose store
  if store \== .nil then store~appendChartSeal(self)
  return .true

::method addAccount
  use arg account
  return self~chart~add(account)

::method sealChart
  return self~chart~seal

::method addPeriod
  expose periods store
  use arg period
  if period == .nil | \period~isA(.AccountingPeriod) then raise syntax 93.900 additional("AccountingPeriod required")
  if periods~hasIndex(period~periodId) then raise syntax 93.900 additional("Duplicate period: " || period~periodId)
  if store \== .nil then store~appendPeriod(self, period)
  periods[period~periodId] = period
  period~attachBook(self)
  return period

::method transitionPeriod
  expose periods store periodTransitions nextTransitionSequence
  use arg periodId, targetState, actorRef = "", reason = "", evidenceArg = .nil, occurredAt = ""
  p = periods[periodId~string]
  if p == .nil then raise syntax 93.900 additional("Unknown accounting period: " || periodId)
  target = targetState~string~strip~upper
  if wordpos(target, "OPEN CLOSED LOCKED") = 0 then raise syntax 93.900 additional("period state must be OPEN, CLOSED or LOCKED")
  old = p~state
  if old = target then return p
  if old = "LOCKED" then raise syntax 93.900 additional("Locked period cannot change state")
  if store \== .nil then store~appendPeriodTransition(self, nextTransitionSequence, p~periodId, old, target, actorRef, reason, evidenceArg, occurredAt)
  tr = .AccountingPeriodTransition~new(nextTransitionSequence, p~periodId, old, target, actorRef, reason, evidenceArg, occurredAt)
  nextTransitionSequence += 1
  periodTransitions~append(tr)
  p~applyState(target, self)
  return p

::method periodTransitions
  expose periodTransitions
  return .AccountingUtil~copyArray(periodTransitions)

::method period
  expose periods
  use arg periodId
  return periods[periodId~string]

::method periodForDate
  expose periods
  use arg postingDate, requireOpen = .true
  match = .nil
  count = 0
  do periodId over periods
    p = periods[periodId]
    if \p~containsDate(postingDate) then iterate
    if requireOpen & p~state \= "OPEN" then iterate
    match = p
    count += 1
  end
  if count > 1 then raise syntax 93.900 additional("Ambiguous accounting periods for date: " || postingDate)
  return match

::method post
  expose legalEntityId bookId chart periods entries sourceIndex balances nextEntryNumber store
  use arg draft
  numeric digits 50
  if draft == .nil | \draft~isA(.AccountingJournalDraft) then return .AccountingPostingResult~failure("DRAFT_REQUIRED", "AccountingJournalDraft required")
  if draft~lineCount < 2 then return .AccountingPostingResult~failure("TOO_FEW_LINES", "A posted journal requires at least two lines")
  period = periods[draft~periodId]
  if period == .nil then return .AccountingPostingResult~failure("PERIOD_UNKNOWN", draft~periodId)
  if period~state \= "OPEN" then return .AccountingPostingResult~failure("PERIOD_NOT_OPEN", draft~periodId || ":" || period~state)
  if \period~containsDate(draft~postingDate) then return .AccountingPostingResult~failure("DATE_OUTSIDE_PERIOD", draft~postingDate)

  existing = sourceIndex[draft~sourceEventRef]
  if existing \== .nil then do
    if existing~fingerprint == draft~fingerprint then return .AccountingPostingResult~success("DUPLICATE", existing)
    return .AccountingPostingResult~failure("SOURCE_EVENT_CONFLICT", draft~sourceEventRef)
  end

  currencyDebits = .directory~new
  currencyCredits = .directory~new
  do line over draft~lines
    account = chart~get(line~accountId)
    if account == .nil then return .AccountingPostingResult~failure("ACCOUNT_UNKNOWN", line~accountId)
    if \account~active then return .AccountingPostingResult~failure("ACCOUNT_INACTIVE", line~accountId)
    if account~currencyMode = "NONE" then return .AccountingPostingResult~failure("ACCOUNT_NONMONETARY", line~accountId)
    if account~currencyMode = "SINGLE" & line~currency \= account~accountCurrency then return .AccountingPostingResult~failure("ACCOUNT_CURRENCY_MISMATCH", line~accountId || ": expected=" || account~accountCurrency || " actual=" || line~currency)
    ccy = line~currency
    d = currencyDebits[ccy]; if d == .nil then d = 0
    c = currencyCredits[ccy]; if c == .nil then c = 0
    currencyDebits[ccy] = d + line~debitMinor
    currencyCredits[ccy] = c + line~creditMinor
  end

  currencies = currencyDebits~allIndexes
  do ccy over currencyCredits
    if \currencyDebits~hasIndex(ccy) then currencies~append(ccy)
  end
  currencies~sort
  last = ""
  do ccy over currencies
    if ccy = last then iterate
    last = ccy
    d = currencyDebits[ccy]; if d == .nil then d = 0
    c = currencyCredits[ccy]; if c == .nil then c = 0
    if d \= c then return .AccountingPostingResult~failure("UNBALANCED_CURRENCY", ccy || ": debit=" || d || " credit=" || c)
  end

  entryId = bookId || "-J" || nextEntryNumber~right(10, "0")
  if store \== .nil then store~appendJournal(self, entryId, draft)
  nextEntryNumber += 1
  entry = .AccountingJournalEntry~new(entryId, legalEntityId, draft)
  entries~append(entry)
  sourceIndex[draft~sourceEventRef] = entry

  do line over entry~lines
    key = line~accountId || "|" || line~currency
    pair = balances[key]
    if pair == .nil then pair = .array~of(0, 0)
    pair[1] = pair[1] + line~debitMinor
    pair[2] = pair[2] + line~creditMinor
    balances[key] = pair
  end
  return .AccountingPostingResult~success("POSTED", entry)

::method reverse
  expose entries
  use arg entryId, sourceEventRef, postingDate, periodId, policyRef, narrative = "Reversal", policyIdentity = ""
  target = self~entry(entryId)
  if target == .nil then return .AccountingPostingResult~failure("ENTRY_UNKNOWN", entryId)
  draft = .AccountingJournalDraft~new(sourceEventRef, postingDate, periodId, policyRef, narrative, target~correlationRef, target~evidenceRefs, target~metadata, target~entryId, policyIdentity, "", "REVERSAL", target~counterpartyEntityId)
  do line over target~lines
    dimensions = line~dimensions
    dimensions["reversalOf"] = target~entryId
    draft~addLine(.AccountingJournalLine~new(line~accountId, line~currency, line~creditMinor, line~debitMinor, "Reverse: " || line~narrative, dimensions))
  end
  return self~post(draft)

::method entry
  expose entries
  use arg entryId
  do e over entries
    if e~entryId = entryId then return e
  end
  return .nil

::method entries
  expose entries
  return .AccountingUtil~copyArray(entries)

::method entryCount
  expose entries
  return entries~items

::method trialBalance
  expose balances
  numeric digits 50
  rows = .array~new
  keys = balances~allIndexes
  keys~sort
  do key over keys
    p = key~lastpos("|")
    accountId = key~substr(1, p - 1)
    currency = key~substr(p + 1)
    pair = balances[key]
    rows~append(.AccountingTrialBalanceRow~new(accountId, currency, pair[1], pair[2]))
  end
  return rows

::method balance
  expose balances
  use arg accountId, currency
  numeric digits 50
  key = accountId~string || "|" || currency~string~upper
  pair = balances[key]
  if pair == .nil then return .AccountingTrialBalanceRow~new(accountId, currency~string~upper, 0, 0)
  return .AccountingTrialBalanceRow~new(accountId, currency~string~upper, pair[1], pair[2])

::method entriesByCorrelation
  expose entries
  use arg correlationRef
  matches = .array~new
  target = correlationRef~string
  do e over entries
    if e~correlationRef = target then matches~append(e)
  end
  return matches

::method entriesByEventType
  expose entries
  use arg eventType
  matches = .array~new
  target = eventType~string~strip~upper
  do e over entries
    if e~eventType = target then matches~append(e)
  end
  return matches

::method sourceEntry
  expose sourceIndex
  use arg sourceEventRef
  return sourceIndex[sourceEventRef~string]
