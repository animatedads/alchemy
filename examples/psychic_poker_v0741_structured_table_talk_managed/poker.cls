::class PokerAlchemyObject public subclass AlchemyObject
::constant COMPONENT "psychic_poker"
::constant COMPONENT_VERSION "0.7.41"
::constant ALCHEMY_OBJECTS_VERSION "0.7"

::method initPokerAlchemy protected
  use arg role = "DOMAIN_OBJECT", purpose = "Psychic Poker domain object"
  meta = .directory~new
  meta["purpose"] = purpose
  meta["package_version"] = self~COMPONENT_VERSION
  meta["component"] = self~COMPONENT
  meta["role"] = role
  meta["authorship"] = "PSYCHIC_POKER"
  meta["standards"] = "ALCHEMY-HOUSE-OBJECT-0.7"
  meta["design_limitations"] = "Poker capability rules remain the authority boundary; Alchemy evidence does not grant game information."
  /* Alchemy Objects >=0.5 requires new descendants to enter through INIT:SUPER
     so construction provenance cannot be silently virtual-dispatched. */
  self~init:super(meta)
  self~registerExternalRequirement("library", "alchemy_objects", self~ALCHEMY_OBJECTS_VERSION, .true)
  return self

::method instrumentPokerMethod protected
  use arg methodName, enforceResult = .false
  check = self~instrumentMethod(methodName, enforceResult)
  if \check~ok then raise syntax 93.900 array("Cannot instrument poker method " || methodName || ": " || check~code)
  return check

::class PokerPromptEnvelope public subclass PokerAlchemyObject
::attribute viewer get
::method init
  expose viewer chunks fieldManifest coreManifest socialManifest fieldCount publicCount customerCount rejectedCount historyCount socialCount finalized
  use arg viewer
  chunks = .array~new
  fieldManifest = .array~new
  coreManifest = .array~new
  socialManifest = .array~new
  fieldCount = 0
  publicCount = 0
  customerCount = 0
  rejectedCount = 0
  historyCount = 0
  socialCount = 0
  finalized = .false
  self~initPokerAlchemy("AI_PROMPT_BOUNDARY", "Fail-closed disclosure and provenance boundary for one live AI prompt")
  self~registerStateVariable("viewer", "CUSTOMER", "intended live AI prompt recipient")
  self~registerMethodContract("APPEND", "Append one provenance-labelled prompt field", .array~of("SOURCE", "DISCLOSURE", "TEXT"), "ANY", .false, "AUTO", "INTERNAL", "SECURITY_BOUNDARY", "MUTATE", "NONE")
  self~describeMethodData("APPEND", "INPUT", "source", "STRING", .true, "semantic provenance label", "PUBLIC")
  self~describeMethodData("APPEND", "INPUT", "disclosure", "STRING", .true, "PUBLIC or viewer-owned CUSTOMER data only", "PUBLIC")
  self~describeMethodData("APPEND", "INPUT", "text", "STRING", .true, "prompt material; never persisted by the audit layer", "CUSTOMER")
  self~registerMethodContract("FINALIZE", "Close the boundary and return the complete prompt", .array~new, "STRING", .false, "AUTO", "INTERNAL", "SECURITY_BOUNDARY", "READ", "NONE")
  self~registerMethodContract("AUDITSUMMARY", "Return non-content prompt boundary evidence", .array~new, "DIRECTORY", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerInstrumentationPoint("PROMPT.FIELD.ACCEPTED", "Prompt field admitted by disclosure boundary", .true, "COLLAPSE", "INTERNAL")
  self~registerInstrumentationPoint("PROMPT.FIELD.REJECTED", "Prompt field rejected by disclosure/provenance boundary", .true, "ALL", "INTERNAL")
  self~registerInstrumentationPoint("PROMPT.FINALIZED", "Prompt boundary finalized without forbidden state", .true, "ALL", "INTERNAL")
  self~instrumentPokerMethod("FINALIZE", .true)

::method append
  expose chunks fieldManifest coreManifest socialManifest fieldCount publicCount customerCount rejectedCount historyCount socialCount finalized
  use strict arg source, disclosure, text
  if finalized then raise syntax 93.900 array("Cannot append to finalized AI prompt boundary")
  source = source~string~strip~translate
  disclosure = disclosure~string~strip~translate
  reason = self~rejectionReason(source, disclosure, text~string)
  if reason \= "" then do
    rejectedCount += 1
    ev = .directory~new
    ev["source"] = source
    ev["disclosure"] = disclosure
    ev["reason"] = reason
    self~alchemyInstrument("PROMPT.FIELD.REJECTED", ev)
    raise syntax 93.900 array("AI prompt boundary rejected " || source || ": " || reason)
  end
  chunks~append(text~string)
  manifestEntry = source || "|" || disclosure
  fieldManifest~append(manifestEntry)
  if source~left(7) = "SOCIAL." then socialManifest~append(manifestEntry)
  else coreManifest~append(manifestEntry)
  fieldCount += 1
  if disclosure = "PUBLIC" then publicCount += 1
  else customerCount += 1
  if source~left(14) = "PUBLIC.HISTORY" then historyCount += 1
  if source~left(7) = "SOCIAL." then socialCount += 1
  ev = .directory~new
  ev["source"] = source
  ev["disclosure"] = disclosure
  self~alchemyInstrument("PROMPT.FIELD.ACCEPTED", ev)
  return self

::method finalize
  expose finalized rejectedCount
  if rejectedCount > 0 then raise syntax 93.900 array("Cannot finalize AI prompt after rejected fields")
  finalized = .true
  self~alchemyTouch("PROMPT_FINALIZE")
  ev = self~auditSummary
  self~alchemyInstrument("PROMPT.FINALIZED", ev)
  return self~text

::method text
  expose chunks
  out = ""
  do chunk over chunks
    out ||= chunk
  end
  return out

::method auditSummary
  expose viewer fieldManifest coreManifest socialManifest fieldCount publicCount customerCount rejectedCount historyCount socialCount finalized
  d = .directory~new
  d["viewer"] = viewer~string
  d["boundary_status"] = "PASS"
  if rejectedCount > 0 then d["boundary_status"] = "FAIL"
  d["field_count"] = fieldCount
  d["public_fields"] = publicCount
  d["customer_fields"] = customerCount
  d["self_private_fields"] = customerCount
  d["history_fields"] = historyCount
  d["social_fields"] = socialCount
  d["rejected_fields"] = rejectedCount
  d["finalized"] = finalized
  d["prompt_length"] = self~text~length
  d["manifest_version"] = .PokerPromptManifestVerifier~MANIFEST_VERSION
  d["field_manifest"] = self~joinManifest(fieldManifest)
  d["core_manifest"] = self~joinManifest(coreManifest)
  d["social_manifest"] = self~joinManifest(socialManifest)
  d["core_field_count"] = coreManifest~items
  d["social_manifest_fields"] = socialManifest~items
  return d

::method joinManifest private
  use strict arg entries
  out = ""
  do entry over entries
    if out \= "" then out ||= ">"
    out ||= entry
  end
  return out

::method rejectionReason private
  use strict arg source, disclosure, text
  if disclosure = "INTERNAL" then return "INTERNAL disclosure is not admissible to a live AI prompt"
  if disclosure = "SECRET" then return "SECRET disclosure is not admissible to a live AI prompt"
  if disclosure \= "PUBLIC" then do
    if disclosure \= "CUSTOMER" then return "unsupported disclosure " || disclosure
  end
  if disclosure = "CUSTOMER" then do
    if source~left(5) \= "SELF." then return "CUSTOMER data must be explicitly viewer-owned SELF provenance"
  end
  forbidden = .array~of("OBSERVER.", "ENGINE.", "RNG.", "OTHER_PRIVATE.", "STRATEGY_INTERNAL.", "API_SECRET.")
  do prefix over forbidden
    if source~left(prefix~length) = prefix then return "forbidden provenance " || prefix
  end
  if source~left(14) = "PUBLIC.HISTORY" then do
    if text~caselessPos("cards=") > 0 then return "observer-style cards= material is forbidden in public history"
    if text~caselessPos("  seat") > 0 then return "observer seat narration is forbidden in public history"
  end
  return ""

::class PokerPromptManifestVerifier public subclass PokerAlchemyObject
::constant MANIFEST_VERSION "PSYCHIC_POKER_PROMPT_FIELD_MANIFEST_V1"

::method init
  self~initPokerAlchemy("AI_PROMPT_MANIFEST_VERIFIER", "Structural verifier for live and counterfactual AI prompt provenance")
  self~registerMethodContract("VERIFY", "Verify one prompt audit carries the current structural manifest contract", .array~of("AUDIT"), "STRING", .false, "AUTO", "INTERNAL", "SECURITY_BOUNDARY", "READ", "NONE")
  self~registerMethodContract("VERIFYCOUNTERFACTUAL", "Require MAIN and NO_SOCIAL prompts to differ only in SOCIAL provenance fields", .array~of("MAIN_AUDIT", "COUNTERFACTUAL_AUDIT"), "STRING", .false, "AUTO", "INTERNAL", "SECURITY_BOUNDARY", "READ", "NONE")
  self~registerInstrumentationPoint("PROMPT.MANIFEST.VERIFIED", "Prompt structural manifest verified", .true, "COLLAPSE", "INTERNAL")
  self~registerInstrumentationPoint("PROMPT.MANIFEST.DRIFT", "Counterfactual prompt changed non-social structural provenance", .true, "ALL", "INTERNAL")

::method verify
  use strict arg audit
  if audit == .nil then raise syntax 93.900 array("Missing prompt audit for manifest verification")
  if audit["manifest_version"] \= self~MANIFEST_VERSION then
    raise syntax 93.900 array("Unsupported AI prompt manifest version " || audit["manifest_version"])
  if audit["boundary_status"] \= "PASS" then raise syntax 93.900 array("Cannot verify failed AI prompt boundary")
  if audit["field_manifest"] = "" then raise syntax 93.900 array("AI prompt field manifest is empty")
  if audit["core_manifest"] = "" then raise syntax 93.900 array("AI prompt core manifest is empty")
  if audit["customer_fields"] \= 1 then raise syntax 93.900 array("AI prompt manifest requires exactly one viewer-private field")
  if audit["core_manifest"]~caselessPos("SELF.HOLE_CARDS|CUSTOMER") = 0 then
    raise syntax 93.900 array("AI prompt manifest is missing viewer-owned hole-card provenance")
  ev = .directory~new
  ev["manifest_version"] = audit["manifest_version"]
  ev["core_field_count"] = audit["core_field_count"]
  self~alchemyInstrument("PROMPT.MANIFEST.VERIFIED", ev)
  return "VERIFIED"

::method verifyCounterfactual
  use strict arg mainAudit, counterfactualAudit
  ignore = self~verify(mainAudit)
  ignore = self~verify(counterfactualAudit)
  if mainAudit["core_manifest"] \= counterfactualAudit["core_manifest"] then do
    ev = .directory~new
    ev["main_core_fields"] = mainAudit["core_field_count"]
    ev["counterfactual_core_fields"] = counterfactualAudit["core_field_count"]
    self~alchemyInstrument("PROMPT.MANIFEST.DRIFT", ev)
    raise syntax 93.900 array("AI counterfactual prompt core manifest drift: only SOCIAL provenance may differ")
  end
  if mainAudit["field_manifest"] = counterfactualAudit["field_manifest"] then
    raise syntax 93.900 array("AI counterfactual prompt manifest did not encode a social-policy difference")
  return "MATCH"

::class CasinoSeed public
::constant MAXSEED 999999999
::method fresh class
  numeric digits 20
  seedText = date("S") || time("L")
  seed = 0
  do i = 1 to seedText~length
    seed = (seed * 131 + c2d(seedText~substr(i, 1))) // self~MAXSEED
  end
  seed += 1
  return seed

::method normalize class
  numeric digits 20
  use arg value
  if \datatype(value, "W") then raise syntax 93.900 array("Casino seed must be a positive whole number")
  if value < 1 | value > self~MAXSEED then
    raise syntax 93.900 array("Casino seed must be between 1 and " || self~MAXSEED || " for NoSQLServer INTEGER compatibility")
  return value

::class GameConfig public subclass PokerAlchemyObject
::attribute smallBlind
::attribute bigBlind
::attribute startingStack
::attribute equitySamples
::attribute seed
::method init
  expose smallBlind bigBlind startingStack equitySamples seed
  use arg smallBlind, bigBlind, startingStack, equitySamples, seed = 20260819
  if smallBlind <= 0 | bigBlind <= 0 then raise syntax 93.900 array("Blinds must be positive")
  if bigBlind < smallBlind then raise syntax 93.900 array("Big blind must be >= small blind")
  if startingStack <= bigBlind then raise syntax 93.900 array("Starting stack must exceed big blind")
  if equitySamples < 10 then equitySamples = 10
  self~initPokerAlchemy("GAME_CONFIG", "Validated public casino configuration")
  self~registerStateVariable("smallBlind", "CUSTOMER", "small blind")
  self~registerStateVariable("bigBlind", "CUSTOMER", "big blind")
  self~registerStateVariable("startingStack", "CUSTOMER", "starting stack")
  self~registerStateVariable("equitySamples", "CUSTOMER", "equity simulation sample count")
  self~registerStateVariable("seed", "INTERNAL", "deterministic casino seed")

::class PokerRandom public subclass PokerAlchemyObject
::method init
  expose state
  use arg seed = 20260819
  numeric digits 20
  state = seed // 2147483647
  if state <= 0 then state = 1
  self~initPokerAlchemy("RANDOM_STREAM", "Deterministic casino random stream")
  self~registerStateVariable("state", "SECRET", "future-card-sensitive PRNG state")
  self~registerMethodContract("NEXTINT", "Return deterministic bounded random integer", .array~of("LO", "HI"), "INTEGER", .false)
::method nextInt
  expose state
  use arg lo, hi
  numeric digits 20
  /* Park-Miller minimal standard using Schrage's method: deterministic and
     independent of ooRexx's process-global RANDOM() state. */
  q = 127773
  r = 2836
  k = state % q
  state = 16807 * (state - k * q) - r * k
  if state <= 0 then state += 2147483647
  span = hi - lo + 1
  return lo + (state // span)

::class Casino public subclass PokerAlchemyObject
::attribute name get
::method init
  expose name tables
  use arg name
  tables = .array~new
  self~initPokerAlchemy("CASINO", "Casino container and table relationship root")
  self~registerStateVariable("name", "CUSTOMER", "casino name")
  self~registerMethodContract("ADDTABLE", "Attach a poker table to this casino", .array~of("TABLE"), "ANY", .false, "AUTO", "CUSTOMER", "NORMAL", "MUTATE", "NONE")
::method addTable
  expose tables
  use arg table
  tables~append(table)
  self~alchemyTouch("ADD_TABLE")
  self~recordRelationship("TABLE", table, "casino membership", "INTERNAL")
::method tables
  expose tables
  return tables

::class Card public
::attribute rank get
::attribute suit get
::method init
  expose rank suit
  use arg rank, suit
::method key
  expose rank suit
  return rank || suit
::method string
  expose rank suit
  select
    when rank = 14 then r = "A"
    when rank = 13 then r = "K"
    when rank = 12 then r = "Q"
    when rank = 11 then r = "J"
    when rank = 10 then r = "T"
    otherwise r = rank
  end
  return r || suit

::class Deck public
::method init
  expose cards pos rng
  use arg rng = .nil
  if rng == .nil then rng = .PokerRandom~new
  cards = .array~new(52)
  pos = 1
  i = 0
  suits = "S H D C"
  do s = 1 to words(suits)
    suit = word(suits, s)
    do rank = 2 to 14
      i += 1
      cards[i] = .Card~new(rank, suit)
    end
  end
  self~shuffle
::method shuffle
  expose cards pos rng
  do i = cards~items to 2 by -1
    j = rng~nextInt(1, i)
    tmp = cards[i]
    cards[i] = cards[j]
    cards[j] = tmp
  end
  pos = 1
::method deal
  expose cards pos
  if pos > cards~items then raise syntax 93.900 array("Deck exhausted")
  c = cards[pos]
  pos += 1
  return c


::class PokerTableTalkEntry public
::attribute token get
::attribute phrase get
::attribute talkClass get
::attribute pressureDelta get
::attribute provocationDelta get
::method init
  expose token phrase talkClass pressureDelta provocationDelta
  use arg token, phrase, talkClass, pressureDelta, provocationDelta

::class PokerTableTalkChoice public
::attribute entry get
::attribute target get
::method init
  expose entry target
  use arg entry, target = .nil

::class PokerTableTalkLibrarian public subclass PokerAlchemyObject
::attribute entries get
::method init
  expose entries tokens
  entries = .directory~new
  tokens = .array~new
  self~add("HARD_WORD", "You sure about that?", "PRESSURE", 0.12, 0.02)
  self~add("CALL_OUT", "I don't believe you.", "CHALLENGE", 0.10, 0.10)
  self~add("YOUR_MOVE", "Your move.", "PRESSURE", 0.08, 0.01)
  self~add("BIG_POT", "That's a lot of chips.", "INTIMIDATE", 0.13, 0.03)
  self~add("NERVOUS", "You look nervous.", "INTIMIDATE", 0.16, 0.06)
  self~add("TAKE_TIME", "Take your time.", "NEEDLE", 0.07, 0.08)
  self~add("ALL_DAY", "I've got all day.", "NEEDLE", 0.08, 0.07)
  self~add("GOOD_FOLD", "Good fold.", "NEEDLE", 0.05, 0.12)
  self~add("LIKE_HAND", "I like my hand.", "CLAIM", 0.09, 0.05)
  self~add("NOT_SCARED", "I'm not scared of that.", "CHALLENGE", 0.08, 0.12)
  self~add("NICE_HAND", "Nice hand.", "RESPECT", -0.08, -0.05)
  self~add("FAIR_ENOUGH", "Fair enough.", "RESPECT", -0.05, -0.04)
  self~initPokerAlchemy("TABLE_TALK_LIBRARIAN", "Frozen dictionary authority for table-talk tokens")
  self~registerMethodContract("CLASSIFY", "Resolve a frozen table-talk token", .array~of("TOKEN"), "ANY", .false)
  self~registerMethodContract("DICTIONARYTEXT", "Return the frozen public table-talk dictionary", .array~new, "STRING", .false)

::method add private
  expose entries tokens
  use arg token, phrase, talkClass, pressureDelta, provocationDelta
  e = .PokerTableTalkEntry~new(token, phrase, talkClass, pressureDelta, provocationDelta)
  entries[token] = e
  tokens~append(token)

::method classify
  expose entries
  use arg token
  token = translate(strip(token))
  if entries~hasIndex(token) then return entries[token]
  return .nil

::method tokenAt
  expose tokens
  use arg index
  if index < 1 then return .nil
  if index > tokens~items then return .nil
  return tokens[index]

::method entryAt
  expose tokens entries
  use arg index
  if index < 1 then return .nil
  if index > tokens~items then return .nil
  return entries[tokens[index]]

::method tokenCount
  expose tokens
  return tokens~items

::method dictionaryText
  expose tokens entries
  txt = ""
  do i = 1 to tokens~items
    token = tokens[i]
    e = entries[token]
    if txt <> "" then txt ||= "0a"x
    txt ||= token || "|" || e~talkClass || "|" || e~phrase
  end
  return txt


::class PokerStructuredTalkFactory public subclass PokerAlchemyObject
::constant SCHEMA "PSYCHIC_POKER_STRUCTURED_TALK_V1"

::method init
  self~initPokerAlchemy("STRUCTURED_TABLE_TALK_FACTORY", "Pre-flattening structured evidence for constrained poker speech")
  self~registerExternalRequirement("library", "structured_utterance", "0.3", .true)
  self~registerMethodContract("BUILD", "Build and seal one dictionary-constrained public poker utterance", .array~of("UTTERANCE_ID","SPEAKER","TARGET","ENTRY"), "STRUCTUREDUTTERANCE", .false, "FALSE", "INTERNAL", "SENSITIVE", "READ", "NONE")

::method build
  use strict arg utteranceId, speaker, target, entry
  if entry == .nil then raise syntax 93.900 array("Structured table talk requires a Librarian entry")
  if speaker == .nil | target == .nil then raise syntax 93.900 array("Structured table talk requires speaker and target")

  u = .StructuredUtterance~new(utteranceId, "PLAYER", "POKER_TABLE", target~name)

  segmentId = utteranceId || "-SEG1"
  segment = .StructuredUtteranceSegment~new(segmentId, entry~phrase, entry~talkClass, "NONE", "DERIVED_NONCUSTOMER")
  segment~putMetadata("dictionary_token", entry~token)
  segment~putMetadata("speaker", speaker~name)
  segment~putMetadata("target", target~name)
  segment~putMetadata("pressure_delta", entry~pressureDelta)
  segment~putMetadata("provocation_delta", entry~provocationDelta)
  segmentSealed = segment~seal
  if \segmentSealed~ok then raise syntax 93.900 array("Cannot seal structured table-talk segment: " || segmentSealed~code)
  if \u~addSegment(segment) then raise syntax 93.900 array("Cannot add structured table-talk segment")

  actId = utteranceId || "-ACT1"
  act = .UtteranceCommunicativeAct~new(actId, entry~talkClass, "RULE_ENGINE", "POKER_TABLE_TALK_LIBRARIAN", 100)
  act~addSegmentId(segmentId)
  actSealed = act~seal
  if \actSealed~ok then raise syntax 93.900 array("Cannot seal structured table-talk communicative act: " || actSealed~code)
  if \u~addAct(act) then raise syntax 93.900 array("Cannot add structured table-talk communicative act")

  intentId = utteranceId || "-INTENT1"
  intent = .UtteranceGenerationIntent~new(intentId, actId, entry~token, "TABLE_TALK", entry~talkClass, "RULE_ENGINE", "POKER_TABLE_TALK_LIBRARIAN", 100)
  intent~addConstraint("FROZEN_DICTIONARY")
  intent~addConstraint("PUBLIC_SPEECH")
  intent~addConstraint("NO_FREE_TEXT")
  intentSealed = intent~seal
  if \intentSealed~ok then raise syntax 93.900 array("Cannot seal structured table-talk generation intent: " || intentSealed~code)
  if \u~addGenerationIntent(intent) then raise syntax 93.900 array("Cannot add structured table-talk generation intent")

  u~addSpeechAct(entry~talkClass)
  u~addContextTag(entry~token)
  u~addContextTag("POKER_TABLE_TALK")
  u~addCorrelation("SPEAKER=" || speaker~name)
  u~addCorrelation("TARGET=" || target~name)

  sealed = u~seal
  if \sealed~ok then raise syntax 93.900 array("Structured table-talk seal failed: " || sealed~code)
  return u

::method summary
  use strict arg utterance, entry
  d = .directory~new
  d["schema"] = self~SCHEMA
  d["utterance_id"] = utterance~utteranceId
  d["token"] = entry~token
  d["talk_class"] = entry~talkClass
  d["communicative_act"] = entry~talkClass
  d["intended_act"] = entry~token
  d["intended_outcome"] = entry~talkClass
  d["authority_kind"] = "RULE_ENGINE"
  d["authority_id"] = "POKER_TABLE_TALK_LIBRARIAN"
  d["sealed"] = utterance~sealed
  return d

::class PlayerStrategy public subclass PokerAlchemyObject
::attribute label get
::attribute risk get
::attribute bluff get
::attribute aggression get
::method init
  expose label risk bluff aggression
  use arg label, risk, bluff, aggression
  risk = self~clamp(risk, 0, 1)
  bluff = self~clamp(bluff, 0, 0.60)
  aggression = self~clamp(aggression, 0.25, 2.0)
  self~initPokerAlchemy("PLAYER_STRATEGY", "Poker decision strategy with explicit risk/bluff/aggression contract")
  self~registerMethodContract("DECIDE", "Choose a legal poker action from the supplied public state", .array~of("PLAYER", "TABLE", "TO_CALL", "MIN_RAISE", "CAN_RAISE"), "DECISION", .false)
  self~registerMethodContract("CHOOSETALK", "Optionally choose a frozen table-talk entry", .array~of("PLAYER", "TABLE", "TO_CALL"), "ANY", .false)
::method clamp private
  use arg n, lo, hi
  if n < lo then return lo
  if n > hi then return hi
  return n
::method description
  expose label risk bluff aggression
  return label "risk="format(risk,1,2) "bluff="format(bluff,1,2) "aggression="format(aggression,1,2)
::method strategyType
  return "STANDARD"
::method handlesTableTalkPsychology
  return .false
::method chooseTalk
  use arg player, table, toCall = 0
  chance = trunc(8 + self~aggression * 7 + self~bluff * 18)
  if toCall > 0 then chance += 4
  if chance > 35 then chance = 35
  if table~randomInt(1,100) > chance then return ""
  librarian = table~talkLibrarian
  idx = table~randomInt(1,librarian~tokenCount)
  entry = librarian~entryAt(idx)
  if entry == .nil then return ""
  return entry

::method objective
  return "INDIVIDUAL_BANKROLL"
::method foldProbability
  expose risk bluff
  use arg equity, potOdds
  margin = (0.10 - risk * 0.08)
  if equity + margin < potOdds then return 1.0 - bluff
  return 0
::method decide
  expose risk bluff aggression
  use arg player, table, toCall, minRaise, canRaise = .true

  equity = table~estimateEquity(player)
  pot = table~pot
  if toCall = 0 then potOdds = 0
  else potOdds = toCall / (pot + toCall)

  /* Risk tolerance changes the safety margin; bluffing is deliberately stochastic. */
  margin = (0.10 - risk * 0.08)
  bluffNow = table~randomInt(1, 10000) <= trunc(bluff * 10000)

  if toCall > 0 then do
    if equity + margin < potOdds then do
      if \bluffNow then return .Decision~new("FOLD", 0, equity, potOdds)
    end
  end

  /* Raise strong equity and occasional bluff spots. */
  raiseGate = 0.70 - (risk * 0.12)
  if canRaise & (equity >= raiseGate | (bluffNow & equity >= 0.22)) then do
    target = trunc((table~pot + toCall) * 0.45 * aggression)
    if target < minRaise then target = minRaise
    return .Decision~new("RAISE", target, equity, potOdds)
  end

  if toCall = 0 then return .Decision~new("CHECK", 0, equity, potOdds)
  return .Decision~new("CALL", toCall, equity, potOdds)






::class OracleHistoryModel public subclass PokerAlchemyObject
::attribute completedHands get
::attribute learnedActions get
::attribute sourceExperiments get
::attribute modelVersion get

::method init
  expose store currentExperiment completedHands learnedActions sourceExperiments rows modelVersion
  use arg store, currentExperiment
  modelVersion = "ORACLE_ACTION_VALUE_V2"
  completedHands = 0
  learnedActions = 0
  sourceExperiments = .directory~new
  rows = .array~new
  self~initPokerAlchemy("ORACLE_HISTORY_MODEL", "Public-history action-value model for The Oracle")
  self~registerStateVariable("modelVersion", "CUSTOMER", "oracle model version")
  self~registerStateVariable("completedHands", "CUSTOMER", "completed ordinary-player hands learned")
  self~registerStateVariable("learnedActions", "CUSTOMER", "public actions learned")
  self~registerMethodContract("REFRESH", "Rebuild Oracle evidence from persisted public completed-hand history", .array~new, "ANY", .false)
  if store \== .nil then self~recordRelationship("STORE", store, "public action history source", "INTERNAL")
  self~refresh
  self~instrumentPokerMethod("REFRESH", .false)

::method refresh
  expose store currentExperiment completedHands learnedActions sourceExperiments rows

  completedHands = 0
  learnedActions = 0
  sourceExperiments = .directory~new
  rows = .array~new

  results = .directory~new
  maxSeq = .directory~new

  /* Include completed hands from the current experiment.  The unfinished hand
     is absent from hand_result, so this is adaptive without peeking forward. */
  q = "SELECT experiment_id,hand_no,player_name,psychic,start_stack,profit FROM hand_result WHERE experiment_id<=" || currentExperiment
  r = store~execute(q)
  if r~status \= "SUCCESS" then return 0

  do i = 1 to r~rows~items
    row = r~rows[i]
    psychicValue = translate(strip("" || row["psychic"]))
    if psychicValue = "TRUE" then iterate
    if psychicValue = "1" then iterate

    key = row["experiment_id"] || "|" || row["hand_no"] || "|" || row["player_name"]
    handOutcome = .directory~new
    handOutcome["profit"] = row["profit"]
    handOutcome["start_stack"] = row["start_stack"]
    results[key] = handOutcome

    completedHands += 1
    sourceExperiments[row["experiment_id"]] = 1
  end

  if completedHands = 0 then return 0

  q = "SELECT experiment_id,hand_no,seq,player_name,street,action,equity,pot_odds,to_call,amount,psychic FROM action_log WHERE experiment_id<=" || currentExperiment
  r = store~execute(q)
  if r~status \= "SUCCESS" then return 0

  /* First pass: identify the final decision sequence in each completed hand. */
  do i = 1 to r~rows~items
    row = r~rows[i]
    psychicValue = translate(strip("" || row["psychic"]))
    if psychicValue = "TRUE" then iterate
    if psychicValue = "1" then iterate
    key = row["experiment_id"] || "|" || row["hand_no"] || "|" || row["player_name"]
    if \results~hasIndex(key) then iterate
    seq = row["seq"]
    if \maxSeq~hasIndex(key) then maxSeq[key] = seq
    else if seq > maxSeq[key] then maxSeq[key] = seq
  end

  /* Second pass: signed action-level attribution.
     Calls/raises inherit both profit and loss.
     Checks get weaker attribution.
     Folds are scored as damage limitation instead of being punished merely
     because a folded hand necessarily finished with <= 0 profit. */
  do i = 1 to r~rows~items
    row = r~rows[i]
    psychicValue = translate(strip("" || row["psychic"]))
    if psychicValue = "TRUE" then iterate
    if psychicValue = "1" then iterate
    key = row["experiment_id"] || "|" || row["hand_no"] || "|" || row["player_name"]
    if \results~hasIndex(key) then iterate

    handOutcome = results[key]
    startStack = handOutcome["start_stack"]
    if startStack <= 0 then startStack = 1000
    profit = handOutcome["profit"]

    normalized = profit / startStack
    if normalized > 1 then normalized = 1
    if normalized < -1 then normalized = -1

    last = maxSeq[key]
    if last <= 0 then last = 1
    position = row["seq"] / last
    attribution = 0.30 + 0.70 * position

    committed = row["to_call"] + row["amount"]
    riskFactor = 1.0 + committed / startStack
    if riskFactor > 2.0 then riskFactor = 2.0

    action = row["action"]
    if action = "FOLD" then do
      lossFraction = 0
      if profit < 0 then lossFraction = (-profit) / startStack
      if lossFraction > 1 then lossFraction = 1
      /* Small-loss folds receive modest positive credit; expensive folds
         receive little credit, but never become "bad because the hand lost". */
      actionValue = 0.18 * (1.0 - lossFraction)
    end
    else if action = "CHECK" then actionValue = normalized * attribution * 0.35
    else actionValue = normalized * attribution * riskFactor

    h = .directory~new
    h["street"] = row["street"]
    h["action"] = action
    h["equity"] = row["equity"]
    h["pot_odds"] = row["pot_odds"]
    h["to_call"] = row["to_call"]
    h["amount"] = row["amount"]
    h["value"] = actionValue
    rows~append(h)
    learnedActions += 1
  end

  return learnedActions

::method experimentCount
  expose sourceExperiments
  return sourceExperiments~items

::method actionEvidence
  expose rows
  use arg street, equity, potOdds, toCall, canRaise = .true

  totals = .directory~new
  evidence = .directory~new
  do action over .array~of("FOLD","CHECK","CALL","RAISE")
    totals[action] = 0
    evidence[action] = 0
  end

  facing = toCall > 0

  do i = 1 to rows~items
    h = rows[i]
    if h["street"] \= street then iterate

    histFacing = h["to_call"] > 0
    if histFacing \= facing then iterate

    action = h["action"]
    legal = .false
    if facing then do
      if action = "FOLD" then legal = .true
      else if action = "CALL" then legal = .true
      else if action = "RAISE" then do
        if canRaise then legal = .true
      end
    end
    else do
      if action = "CHECK" then legal = .true
      else if action = "RAISE" then do
        if canRaise then legal = .true
      end
    end
    if \legal then iterate

    similarity = 1.0

    histEq = h["equity"]
    if histEq > 0 then do
      d = abs(equity - histEq)
      if d <= 0.04 then similarity *= 5.0
      else if d <= 0.10 then similarity *= 3.0
      else if d <= 0.18 then similarity *= 1.5
      else if d <= 0.28 then similarity *= 0.60
      else similarity *= 0.15
    end

    histOdds = h["pot_odds"]
    d = abs(potOdds - histOdds)
    if d <= 0.04 then similarity *= 2.0
    else if d <= 0.10 then similarity *= 1.25
    else if d > 0.20 then similarity *= 0.40

    totals[action] += similarity * h["value"]
    evidence[action] += similarity
  end

  answer = .directory~new
  answer["totals"] = totals
  answer["evidence"] = evidence
  return answer


::class OracleStrategy public subclass PlayerStrategy
::attribute historyModel

::method strategyType
  return "THE_ORACLE"

::method init
  expose historyModel
  use arg historyModel = .nil
  forward class (super) array("the-oracle", 0.48, 0.08, 1.15) continue

::method description
  expose historyModel
  if historyModel == .nil then return "the-oracle history=unavailable"
  return "the-oracle model=" || historyModel~modelVersion || " completed_hands=" || historyModel~completedHands || " learned_actions=" || historyModel~learnedActions || " source_experiments=" || historyModel~experimentCount

::method decide
  expose historyModel
  use arg player, table, toCall, minRaise, canRaise = .true

  equity = table~estimateEquity(player)
  if toCall = 0 then potOdds = 0
  else potOdds = toCall / (table~pot + toCall)

  if historyModel == .nil then
    return self~fallbackDecision(player, table, toCall, minRaise, canRaise, equity, potOdds)

  /* Learn newly completed hands before every Oracle decision. */
  historyModel~refresh

  model = historyModel~actionEvidence(table~street, equity, potOdds, toCall, canRaise)
  totals = model["totals"]
  evidence = model["evidence"]

  bestAction = ""
  bestUtility = -999999

  do action over .array~of("FOLD","CHECK","CALL","RAISE")
    legal = .false
    if toCall > 0 then do
      if action = "FOLD" then legal = .true
      else if action = "CALL" then legal = .true
      else if action = "RAISE" then do
        if canRaise then legal = .true
      end
    end
    else do
      if action = "CHECK" then legal = .true
      else if action = "RAISE" then do
        if canRaise then legal = .true
      end
    end
    if \legal then iterate

    ev = evidence[action]
    empirical = 0
    if ev > 0 then empirical = totals[action] / ev

    /* Shrink sparse historical evidence toward a conservative ordinary prior. */
    confidence = ev / (ev + 8.0)

    prior = 0
    if action = "FOLD" then prior = 0.04
    else if action = "CHECK" then prior = 0.03
    else if action = "CALL" then do
      prior = equity - potOdds - 0.03
    end
    else if action = "RAISE" then do
      prior = equity - 0.62
    end

    utility = confidence * empirical + (1.0 - confidence) * prior

    /* Current-state safety matters even if history contains reckless winners. */
    if action = "CALL" then do
      if toCall > 0 then do
        if equity < potOdds then utility -= 0.30
        if toCall >= table~pot * 0.55 then do
          if equity < 0.58 then utility -= 0.35
        end
      end
    end
    else if action = "RAISE" then do
      if equity < 0.35 then utility -= 0.25
    end

    if utility > bestUtility then do
      bestUtility = utility
      bestAction = action
    end
  end

  if bestAction = "" then
    return self~fallbackDecision(player, table, toCall, minRaise, canRaise, equity, potOdds)

  if bestAction = "FOLD" then return .Decision~new("FOLD",0,equity,potOdds)
  if bestAction = "CHECK" then return .Decision~new("CHECK",0,equity,potOdds)
  if bestAction = "CALL" then return .Decision~new("CALL",toCall,equity,potOdds)

  target = trunc((table~pot + toCall) * 0.52 * self~aggression)
  if equity >= 0.75 then target = trunc((table~pot + toCall) * 0.72 * self~aggression)
  if target < minRaise then target = minRaise
  return .Decision~new("RAISE",target,equity,potOdds)

::method fallbackDecision private
  use arg player, table, toCall, minRaise, canRaise, equity, potOdds

  if toCall > 0 then do
    if equity < potOdds + 0.04 then return .Decision~new("FOLD",0,equity,potOdds)
    if toCall >= table~pot * 0.55 then do
      if equity < 0.58 then return .Decision~new("FOLD",0,equity,potOdds)
    end
  end

  if canRaise then do
    if equity >= 0.68 then do
      target = trunc((table~pot + toCall) * 0.55 * self~aggression)
      if target < minRaise then target = minRaise
      return .Decision~new("RAISE",target,equity,potOdds)
    end
  end

  if toCall = 0 then return .Decision~new("CHECK",0,equity,potOdds)
  return .Decision~new("CALL",toCall,equity,potOdds)

::class ApexStrategy public subclass PlayerStrategy
::method strategyType
  return "APEX"

::method handlesTableTalkPsychology
  /* Apex consumes the same bounded psychology state itself so the generic
     postprocessor must not apply a second pressure/provocation adjustment. */
  return .true

::method init
  forward class (super) array("apex-v2", 0.45, 0.15, 1.40)

::method chooseTalk
  use arg player, table, toCall = 0
  recent = player~lastTalkEntry
  offender = player~lastTalkSpeaker

  if recent == .nil then forward class (super)
  if player~lastTalkAnswered then forward class (super)

  /* Consume each incoming utterance at most once as a retaliation trigger. */
  player~lastTalkAnswered = .true
  talkClass = recent~talkClass
  chance = 0
  token = ""

  select
    when talkClass = "NEEDLE" then do
      chance = 55 + trunc(player~provocation * 15)
      token = "NOT_SCARED"
    end
    when talkClass = "CHALLENGE" then do
      chance = 55 + trunc(player~provocation * 15)
      token = "HARD_WORD"
    end
    when talkClass = "PRESSURE" then do
      chance = 38 + trunc(player~psychologicalPressure * 12)
      token = "NOT_SCARED"
    end
    when talkClass = "INTIMIDATE" then do
      chance = 45 + trunc(player~psychologicalPressure * 12)
      token = "NOT_SCARED"
    end
    when talkClass = "CLAIM" then do
      chance = 30
      token = "CALL_OUT"
    end
    when talkClass = "RESPECT" then do
      chance = 30
      token = "FAIR_ENOUGH"
    end
    otherwise nop
  end

  if chance > 70 then chance = 70
  if token = "" then forward class (super)
  if table~randomInt(1, 100) > chance then forward class (super)

  response = table~talkLibrarian~classify(token)
  if response == .nil then forward class (super)
  return .PokerTableTalkChoice~new(response, offender)

::method decide
  use arg player, table, toCall, minRaise, canRaise = .true

  equity = table~estimateEquity(player)
  pot = table~pot
  street = table~street
  if toCall = 0 then potOdds = 0
  else potOdds = toCall / (pot + toCall)

  /* Apex v2 uses the real bounded Player psychology state.  It never mutates
     measured equity to simulate emotion; talk only moves decision thresholds. */
  pressure = player~psychologicalPressure
  provocation = player~provocation
  talkClass = ""
  recent = player~lastTalkEntry
  if recent \== .nil then talkClass = recent~talkClass

  margin = 0.12
  raiseThreshold = 0.68

  /* Wet boards require more actual equity before Apex escalates. */
  wetness = self~boardWetness(table~board)
  raiseThreshold += wetness * 0.08

  /* Needles and challenges can provoke bounded counter-aggression.  Pressure
     and intimidation do not make Apex invent equity or fold from fear. */
  if talkClass = "NEEDLE" then do
    counter = provocation * 0.20
    if counter > 0.05 then counter = 0.05
    raiseThreshold -= counter
  end
  else if talkClass = "CHALLENGE" then do
    counter = provocation * 0.20
    if counter > 0.05 then counter = 0.05
    raiseThreshold -= counter
  end

  /* Anti-calling-station gate: heavy turn/river action requires at least
     coin-flip equity before Apex is willing to continue. */
  if toCall > 0 then do
    heavyAction = .false
    if pot > 0 then do
      if toCall >= pot * 0.55 then heavyAction = .true
    end
    if heavyAction then do
      if street = "TURN" then do
        if equity < 0.50 then return .Decision~new("FOLD", 0, equity, potOdds)
      end
      else if street = "RIVER" then do
        if equity < 0.50 then return .Decision~new("FOLD", 0, equity, potOdds)
      end
    end

    if equity + margin < potOdds then
      return .Decision~new("FOLD", 0, equity, potOdds)
  end

  /* Very strong holdings remain proactive rather than becoming traps by
     default.  Board texture slightly tightens the threshold, not the truth. */
  if canRaise then do
    if equity >= 0.82 then do
      mult = 0.70
      if street = "TURN" then mult = 0.78
      else if street = "RIVER" then mult = 0.82
      target = trunc((pot + toCall) * mult * self~aggression)
      if target < minRaise then target = minRaise
      return .Decision~new("RAISE", target, equity, potOdds)
    end

    if equity >= raiseThreshold then do
      mult = 0.58
      if street = "TURN" then mult = 0.66
      else if street = "RIVER" then mult = 0.70
      target = trunc((pot + toCall) * mult * self~aggression)
      if target < minRaise then target = minRaise
      return .Decision~new("RAISE", target, equity, potOdds)
    end
  end

  if toCall = 0 then return .Decision~new("CHECK", 0, equity, potOdds)
  return .Decision~new("CALL", toCall, equity, potOdds)

::method boardWetness private
  use arg board
  if board == .nil then return 0
  if board~items < 3 then return 0

  suits = .directory~new
  ranks = .directory~new
  minRank = 99
  maxRank = 0
  paired = .false
  maxSuit = 0

  do i = 1 to board~items
    card = board[i]
    suit = card~suit
    rank = card~rank

    if suits~hasIndex(suit) then suits[suit] += 1
    else suits[suit] = 1
    if suits[suit] > maxSuit then maxSuit = suits[suit]

    rankKey = rank~string
    if ranks~hasIndex(rankKey) then paired = .true
    else ranks[rankKey] = 1
    if rank < minRank then minRank = rank
    if rank > maxRank then maxRank = rank
  end

  wet = 0
  if maxSuit >= 3 then wet += 0.22
  else if maxSuit = 2 then wet += 0.08

  spread = maxRank - minRank
  if spread <= 4 then wet += 0.18
  else if spread <= 6 then wet += 0.08

  if paired then wet += 0.05
  if wet > 0.40 then wet = 0.40
  return wet

::class GeminiEmulatedStrategy public subclass PlayerStrategy
::method strategyType
  return "AI_GEMINI_EMULATED"

::method init
  forward class (super) array("gemini-analytical", 0.45, 0.15, 1.40)

::method decide
  use arg player, table, toCall, minRaise, canRaise = .true

  equity = table~estimateEquity(player)
  pot = table~pot
  if toCall = 0 then potOdds = 0
  else potOdds = toCall / (pot + toCall)

  /* This is Gemini's own proposed deterministic "semi-optimal" policy.
     It is intentionally kept separate from the blind live GEMINI agent.
     The original proposal described this as a more conservative policy
     for an adversarial-information environment. */
  margin = 0.15 - self~risk * 0.05

  if toCall > 0 then do
    /* Require equity to clear pot odds plus the safety margin. */
    if equity < potOdds + margin then
      return .Decision~new("FOLD", 0, equity, potOdds)
  end

  if canRaise & equity >= 0.60 then do
    target = trunc((pot + toCall) * 0.75 * self~aggression)
    if target < minRaise then target = minRaise
    return .Decision~new("RAISE", target, equity, potOdds)
  end

  if toCall = 0 then return .Decision~new("CHECK", 0, equity, potOdds)
  return .Decision~new("CALL", toCall, equity, potOdds)

::class ResourceAwareStrategy public subclass PlayerStrategy
::method strategyType
  return "RESOURCE_AWARE"
::method init
  forward class (super) array("resource-aware", 0.50, 0.25, 1.10)
::method decide
  use arg player, table, toCall, minRaise, canRaise = .true

  equity = table~estimateEquity(player)
  pot = table~pot

  opponentsStackSum = 0
  activeOpponents = 0
  minOpponentStack = 9999999

  do i = 1 to table~players~items
    p = table~players[i]
    if p == player then iterate
    if p~folded then iterate
    if p~stack = 0 then iterate
    opponentsStackSum += p~stack
    activeOpponents += 1
    if p~stack < minOpponentStack then minOpponentStack = p~stack
  end

  if activeOpponents = 0 then avgOpponentStack = 0
  else avgOpponentStack = opponentsStackSum / activeOpponents

  if toCall = 0 then potOdds = 0
  else potOdds = toCall / (pot + toCall)

  margin = 0.10 - self~risk * 0.08
  if minOpponentStack < pot then do
    if minOpponentStack > 0 then margin += 0.05
  end

  bluffNow = table~randomInt(1, 10000) <= trunc(self~bluff * 10000)

  if toCall > 0 then do
    if equity + margin < potOdds then do
      if \bluffNow then return .Decision~new("FOLD", 0, equity, potOdds)
    end
  end

  raiseGate = 0.65 - self~risk * 0.10
  if avgOpponentStack > pot * 2 then aggressionMod = self~aggression * 1.5
  else aggressionMod = self~aggression * 0.8

  if canRaise & (equity >= raiseGate | (bluffNow & equity >= 0.25)) then do
    target = trunc((pot + toCall) * 0.50 * aggressionMod)
    if target < minRaise then target = minRaise
    if minOpponentStack > 0 then do
      if target > minOpponentStack then target = minOpponentStack
    end
    return .Decision~new("RAISE", target, equity, potOdds)
  end

  if toCall = 0 then return .Decision~new("CHECK", 0, equity, potOdds)
  return .Decision~new("CALL", toCall, equity, potOdds)

::class AggressiveStrategy public subclass PlayerStrategy
::method strategyType
  return "AGGRESSIVE"
::method init
  forward class (super) array("AGGRESSIVE", 0.72, 0.38, 1.65)
::method decide
  use arg player, table, toCall, minRaise, canRaise = .true

  equity = table~estimateEquity(player)
  pot = table~pot
  if toCall = 0 then potOdds = 0
  else potOdds = toCall / (pot + toCall)

  risk = self~risk
  bluff = self~bluff
  aggression = self~aggression

  margin = (0.10 - risk * 0.08)
  bluffNow = table~randomInt(1, 10000) <= trunc(bluff * 10000)

  if toCall > 0 then do
    if equity + margin < potOdds then do
      if \bluffNow then return .Decision~new("FOLD", 0, equity, potOdds)
    end
  end

  raiseGate = 0.58 - (risk * 0.10)
  bluffEquityFloor = 0.16

  if canRaise & (equity >= raiseGate | (bluffNow & equity >= bluffEquityFloor)) then do
    target = trunc((table~pot + toCall) * 0.60 * aggression)
    if target < minRaise then target = minRaise
    return .Decision~new("RAISE", target, equity, potOdds)
  end

  if toCall = 0 then return .Decision~new("CHECK", 0, equity, potOdds)
  return .Decision~new("CALL", toCall, equity, potOdds)


::class PaladinStrategy public subclass PlayerStrategy
::method strategyType
  return "PALADIN"

::method handlesTableTalkPsychology
  /* Paladin reasons about the shared public pressure state itself.  Returning
     true prevents the generic psychology postprocessor from applying a second,
     context-blind fold/raise adjustment after this strategy has already priced
     bet size, street trend and pressure into the decision. */
  return .true

::method init
  expose lastHandNumber lastStreetSeen streetEquity
  forward class (super) array("paladin", 0.62, 0.09, 1.55)
  lastHandNumber = -1
  lastStreetSeen = ""
  streetEquity = 0

::method decide
  /* PALADIN is honest: it reads only table~estimateEquity, its own player
     object, other players' public stack/folded state, and its own seeded
     randomInt draws.  It never touches a privileged card- or strategy-
     inspection surface. */
  expose lastHandNumber lastStreetSeen streetEquity
  use arg player, table, toCall, minRaise, canRaise = .true

  equity = table~estimateEquity(player)
  pot = table~pot
  street = table~street
  handNumber = table~handNumber

  /* Fresh hand: reset the equity-trend memory used to spot a busted draw. */
  if handNumber <> lastHandNumber then do
    lastHandNumber = handNumber
    lastStreetSeen = ""
    streetEquity = equity
  end

  declining = .false
  if street <> lastStreetSeen then do
    if lastStreetSeen <> "" then do
      if equity < streetEquity - 0.12 then declining = .true
    end
    lastStreetSeen = street
    streetEquity = equity
  end

  if toCall = 0 then potOdds = 0
  else potOdds = toCall / (pot + toCall)

  betRatio = 0
  if pot > 0 then betRatio = toCall / pot

  risk = self~risk
  bluff = self~bluff
  aggression = self~aggression

  /* Table talk is public state on Player.  Paladin notices hostile pressure,
     but refuses to let provocation buy extra aggression.  Pressure therefore
     narrows the ordinary forgiveness margin; it never changes measured equity. */
  pressure = player~psychologicalPressure
  pressureMargin = pressure * 0.05

  /* Bounded per-decision jitter.  PSYCHIC_EXPLOIT/PSYCHIC_TEAM can read
     this object's fixed risk/bluff/aggression fields directly, so a purely
     deterministic formula is exploitable by exactly the opponents this
     strategy exists to beat.  A small seeded wobble on the thresholds
     keeps actual behaviour non-obvious from the object alone, without
     turning decisions into a coinflip: it stays inside the risk-scaled
     band already set by init. */
  jitter = (table~randomInt(1, 200) - 100) / 4000

  /* Bet-size-aware defence.  A bet that is large relative to the pot has
     to clear a bigger equity bar than raw pot odds would demand, because
     large bets skew toward value on later streets. */
  sizeMargin = betRatio * 0.12
  if sizeMargin > 0.18 then sizeMargin = 0.18

  declineMargin = 0
  if declining then declineMargin = 0.10

  margin = 0.11 - risk * 0.05
  margin = margin + sizeMargin
  margin = margin + declineMargin
  margin = margin - pressureMargin
  margin = margin + jitter

  bluffRoll = table~randomInt(1, 10000)
  bluffNow = .false
  if bluffRoll <= trunc(bluff * 10000) then bluffNow = .true

  if toCall > 0 then do
    if equity + margin < potOdds then do
      if \bluffNow then return .Decision~new("FOLD", 0, equity, potOdds)
    end
  end

  /* Stack-to-pot pressure: with a shallow effective stack behind, prefer
     to get the money in now with real equity rather than leaving several
     more decisions on the table at worse implied prices later.  Decision
     amount is the raise increment ABOVE the call, so effectiveBehind is
     expressed in exactly that convention. */
  cheapestOpponentStack = 9999999
  do i = 1 to table~players~items
    p = table~players[i]
    if p == player then iterate
    if p~folded then iterate
    if p~stack = 0 then iterate
    if p~stack < cheapestOpponentStack then cheapestOpponentStack = p~stack
  end

  heroBehind = player~stack - toCall
  if heroBehind < 0 then heroBehind = 0
  if cheapestOpponentStack = 9999999 then cheapestOpponentStack = heroBehind
  effectiveBehind = heroBehind
  if cheapestOpponentStack < effectiveBehind then effectiveBehind = cheapestOpponentStack

  spr = 999
  if pot > 0 then spr = effectiveBehind / pot

  raiseGate = 0.66 - risk * 0.14
  raiseGate = raiseGate + jitter
  if spr <= 1.5 then raiseGate = raiseGate - 0.10

  semiBluffOk = .false
  if \declining then do
    if bluffNow then do
      if equity >= 0.30 then do
        if street = "FLOP" then semiBluffOk = .true
        else if street = "TURN" then semiBluffOk = .true
      end
    end
  end

  wantsToRaise = .false
  if equity >= raiseGate then wantsToRaise = .true
  if semiBluffOk then wantsToRaise = .true

  if canRaise then do
    if wantsToRaise then do
      shoveMode = .false
      if spr <= 1.5 then do
        if equity >= 0.60 then shoveMode = .true
      end

      if shoveMode then target = effectiveBehind
      else do
        mult = 0.65
        if street = "TURN" then mult = 0.80
        else if street = "RIVER" then mult = 0.95
        if equity >= 0.85 then mult = mult + 0.25
        target = trunc((pot + toCall) * mult * aggression)
      end

      if target < minRaise then target = minRaise
      maxRaise = player~stack - toCall
      if maxRaise < 0 then maxRaise = 0
      if target > maxRaise then target = maxRaise
      if target > 0 then return .Decision~new("RAISE", target, equity, potOdds)
    end
  end

  if toCall = 0 then return .Decision~new("CHECK", 0, equity, potOdds)
  return .Decision~new("CALL", toCall, equity, potOdds)


::class BlindPsychicStrategy public subclass PlayerStrategy
::method strategyType
  return "BLIND_PSYCHIC"

::method init
  forward class (super) array("blind-benny", 0.58, 0.22, 1.30)

::method decide
  use arg player, table, toCall, minRaise, canRaise = .true

  /* Deliberately does not inspect Benny's dealt-card attributes. */
  equity = table~estimateBlindPsychicEquity(player, 96)
  pot = table~pot
  if toCall = 0 then potOdds = 0
  else potOdds = toCall / (pot + toCall)

  risk = self~risk
  bluff = self~bluff
  aggression = self~aggression

  /* Benny can see everyone else's cards, so exploit clearly weak fields. */
  fieldWeakness = table~blindPsychicFieldWeakness(player)
  bluffChance = bluff + fieldWeakness * 0.45
  if bluffChance > 0.70 then bluffChance = 0.70
  bluffNow = table~randomInt(1,10000) <= trunc(bluffChance * 10000)

  if toCall > 0 then do
    margin = 0.06 - risk * 0.03
    if equity + margin < potOdds then do
      if \bluffNow then return .Decision~new("FOLD",0,equity,potOdds)
    end
  end

  raiseGate = 0.60 - risk * 0.08
  if canRaise then do
    if equity >= raiseGate then do
      target = trunc((pot + toCall) * 0.55 * aggression)
      if target < minRaise then target = minRaise
      return .Decision~new("RAISE",target,equity,potOdds)
    end
    if bluffNow then do
      target = trunc((pot + toCall) * 0.45 * aggression)
      if target < minRaise then target = minRaise
      return .Decision~new("RAISE",target,equity,potOdds)
    end
  end

  if toCall = 0 then return .Decision~new("CHECK",0,equity,potOdds)
  return .Decision~new("CALL",toCall,equity,potOdds)

::class PsychicEquityStrategy public subclass PlayerStrategy
::method strategyType
  return "PSYCHIC_EQUITY"

::class PsychicExploitStrategy public subclass PlayerStrategy
::method strategyType
  return "PSYCHIC_EXPLOIT"
::method decide
  use arg player, table, toCall, minRaise, canRaise = .true

  equity = table~estimateEquity(player)
  pot = table~pot
  if toCall = 0 then potOdds = 0
  else potOdds = toCall / (pot + toCall)

  risk = self~risk
  bluff = self~bluff
  aggression = self~aggression
  margin = (0.10 - risk * 0.08)
  bluffNow = table~randomInt(1, 10000) <= trunc(bluff * 10000)

  if toCall > 0 then do
    if equity + margin < potOdds then do
      if \bluffNow then return .Decision~new("FOLD", 0, equity, potOdds)
    end
  end

  target = trunc((pot + toCall) * 0.45 * aggression)
  if target < minRaise then target = minRaise
  leverage = table~psychicFoldLeverage(player, target)

  /* Exact opponent cards + readable strategy parameters create exploitable
     fold equity.  This is not a bonus: leverage is derived only from
     information available through PsychicPlayer privileges. */
  raiseGate = 0.70 - (risk * 0.12) - (leverage * 0.18)
  exploitBluff = .false
  if leverage >= 0.55 then do
    if equity >= 0.12 then exploitBluff = .true
  end
  if canRaise & (equity >= raiseGate | exploitBluff | (bluffNow & equity >= 0.18)) then
    return .Decision~new("RAISE", target, equity, potOdds, leverage)

  if toCall = 0 then return .Decision~new("CHECK", 0, equity, potOdds)
  return .Decision~new("CALL", toCall, equity, potOdds)

::class PsychicAggressiveStrategy public subclass PsychicExploitStrategy
::method strategyType
  return "PSYCHIC_AGGRESSIVE"
::method init
  forward class (super) array("psychic-aggressive", 0.68, 0.30, 1.55)
::method decide
  use arg player, table, toCall, minRaise, canRaise = .true

  equity = table~estimateEquity(player)
  pot = table~pot
  if toCall = 0 then potOdds = 0
  else potOdds = toCall / (pot + toCall)

  risk = self~risk
  bluff = self~bluff
  aggression = self~aggression
  foldLeverage = table~psychicFoldLeverage(player, max(minRaise, trunc((pot + toCall) * 0.55 * aggression)))
  representation = table~psychicRepresentationLeverage(player, 28)

  /* The bluff probability rises when the exact opponent cards are weak enough
     that the public board credibly supports many stronger unseen holdings. */
  bluffChance = bluff + representation * 0.48 + foldLeverage * 0.18
  if bluffChance > 0.82 then bluffChance = 0.82
  bluffNow = table~randomInt(1,10000) <= trunc(bluffChance * 10000)

  margin = 0.055 - risk * 0.035
  if toCall > 0 then do
    if equity + margin < potOdds then do
      if \bluffNow then return .Decision~new("FOLD", 0, equity, potOdds, representation)
    end
  end

  target = trunc((pot + toCall) * 0.58 * aggression)
  if target < minRaise then target = minRaise
  raiseGate = 0.61 - risk * 0.10 - representation * 0.20 - foldLeverage * 0.12

  representedBluff = .false
  if representation >= 0.30 & equity >= 0.06 & bluffNow then representedBluff = .true
  if canRaise & (equity >= raiseGate | representedBluff) then
    return .Decision~new("RAISE", target, equity, potOdds, representation)

  if toCall = 0 then return .Decision~new("CHECK", 0, equity, potOdds, representation)
  return .Decision~new("CALL", toCall, equity, potOdds, representation)

::class PsychicTeamStrategy public subclass PsychicExploitStrategy
::method strategyType
  return "PSYCHIC_TEAM"
::method objective
  return "TEAM_BANKROLL"
::method decide
  use arg player, table, toCall, minRaise, canRaise = .true
  if toCall > 0 then do
    equity = table~estimateEquity(player)
    if table~teamMatePressure(player) then do
      if equity < 0.72 then do
        potOdds = toCall / (table~pot + toCall)
        return .Decision~new("FOLD", 0, equity, potOdds)
      end
    end
  end
  forward class (super)



::class GrokFallbackStrategy public subclass PlayerStrategy
::method strategyType
  return "GROK_FALLBACK"

::method init
  forward class (super) array("grok-fallback", 0.22, 0.03, 1.15)

::method decide
  use arg player, table, toCall, minRaise, canRaise = .true

  equity = table~estimateEquity(player)
  pot = table~pot
  street = table~street
  if toCall = 0 then potOdds = 0
  else potOdds = toCall / (pot + toCall)

  risk = self~risk
  bluff = self~bluff
  aggression = self~aggression
  margin = 0.16 - risk * 0.03

  /* Emergency fallback: preserve capital.  Nested tests are intentional;
     ooRexx boolean conjunction/disjunction operators are not short-circuit. */
  if toCall > 0 then do
    if equity + margin < potOdds then do
      bluffNow = table~randomInt(1,10000) <= trunc(bluff * 10000)
      if \bluffNow then return .Decision~new("FOLD",0,equity,potOdds)
    end
  end

  /* Large-bet protection: this closes the experiment-23 KQo leak. */
  if toCall > 0 then do
    if toCall >= pot * 0.55 then do
      if equity < 0.58 then return .Decision~new("FOLD",0,equity,potOdds)
    end
  end

  if equity >= 0.78 then do
    if canRaise then do
      mult = 0.65
      if street = "TURN" then mult = 0.80
      else if street = "RIVER" then mult = 0.80
      target = trunc((pot + toCall) * mult * aggression)
      if target < minRaise then target = minRaise
      return .Decision~new("RAISE",target,equity,potOdds)
    end
  end

  if canRaise then do
    if equity >= 0.62 then do
      target = trunc((pot + toCall) * 0.55 * aggression)
      if target < minRaise then target = minRaise
      return .Decision~new("RAISE",target,equity,potOdds)
    end
  end

  if toCall = 0 then return .Decision~new("CHECK",0,equity,potOdds)

  if equity + margin >= potOdds then do
    if toCall < pot * 0.45 then return .Decision~new("CALL",toCall,equity,potOdds)
  end

  return .Decision~new("FOLD",0,equity,potOdds)

::class GrokPokerStrategy public subclass PlayerStrategy
::attribute client get
::attribute fallback get
::method init
  expose client fallback
  use arg client, fallback
  forward class (super) array("grok-agent", 0.50, 0.00, 1.00) continue
  self~recordRelationship("AI_CLIENT", client, "Grok decision provider", "INTERNAL")
  self~recordRelationship("FALLBACK_STRATEGY", fallback, "deterministic fallback", "INTERNAL")
::method strategyType
  return "AI_GROK"
::method description
  expose client
  return "AI agent provider=xAI model=" || client~model || " information=ordinary-player-view"
::method decide
  expose client fallback
  use arg player, table, toCall, minRaise, canRaise = .true
  prompt = table~agentPrompt(player, toCall, minRaise, canRaise)
  shadowMode = value("POKER_SOCIAL_SHADOW",, "ENVIRONMENT")
  probeMode = 0
  if shadowMode = "1" then probeMode = 1
  else if shadowMode = "2" then probeMode = 2
  probeEnabled = .false
  if probeMode > 0 then do
    if client~hasMethod("DECIDEWITHTEMPERATURE") then probeEnabled = .true
  end
  if probeEnabled then reply = client~decideWithTemperature(prompt, 0)
  else reply = client~decide(prompt)
  if reply == .nil then do
    say "GROK FALLBACK active"
    return fallback~decide(player, table, toCall, minRaise, canRaise)
  end
  action = reply["action"]~upper
  amount = reply["amount"]
  if action = "FOLD" & toCall = 0 then action = "CHECK"
  if action = "CHECK" & toCall > 0 then action = "FOLD"
  if action = "CALL" & toCall = 0 then action = "CHECK"
  if action = "RAISE" & \canRaise then do
    if toCall > 0 then action = "CALL"
    else action = "CHECK"
  end
  if action = "RAISE" then do
    if \datatype(amount, "W") then amount = minRaise
    if amount < minRaise then amount = minRaise
  end
  else amount = 0
  /* AI decisions do not receive hidden equity from the engine.  Zero here
     means "not supplied", not zero poker equity. */
  if toCall = 0 then potOdds = 0
  else potOdds = toCall / (table~pot + toCall)
  talkToken = ""
  talkTarget = ""
  socialEvidenceId = "NONE"
  if reply~hasIndex("talk") then talkToken = reply["talk"]~strip~upper
  if reply~hasIndex("talk_target") then talkTarget = reply["talk_target"]~strip
  if reply~hasIndex("social_evidence") then socialEvidenceId = reply["social_evidence"]~strip~upper

  controlAction = ""
  controlAmount = 0
  if probeEnabled then do
    if probeMode = 2 then do
      controlReply = client~decideWithTemperature(prompt, 0)
      controlDecision = self~normalizeProbeReply(controlReply, toCall, minRaise, canRaise)
      if controlDecision \= .nil then do
        controlAction = controlDecision["action"]
        controlAmount = controlDecision["amount"]
      end
    end
  end

  shadowAction = ""
  shadowAmount = 0
  if probeEnabled then do
    shadowPrompt = table~agentPrompt(player, toCall, minRaise, canRaise, .false)
    shadowReply = client~decideWithTemperature(shadowPrompt, 0)
    shadowDecision = self~normalizeProbeReply(shadowReply, toCall, minRaise, canRaise)
    if shadowDecision \= .nil then do
      shadowAction = shadowDecision["action"]
      shadowAmount = shadowDecision["amount"]
    end
  end
  return .Decision~new(action, amount, 0, potOdds, 0, talkToken, talkTarget, socialEvidenceId, shadowAction, shadowAmount, controlAction, controlAmount)

::method normalizeProbeReply private
  use arg reply, toCall, minRaise, canRaise
  if reply == .nil then return .nil
  d = .directory~new
  probeAction = reply["action"]~upper
  probeAmount = reply["amount"]
  if probeAction = "FOLD" then do
    if toCall = 0 then probeAction = "CHECK"
  end
  if probeAction = "CHECK" then do
    if toCall > 0 then probeAction = "FOLD"
  end
  if probeAction = "CALL" then do
    if toCall = 0 then probeAction = "CHECK"
  end
  if probeAction = "RAISE" then do
    if \canRaise then do
      if toCall > 0 then probeAction = "CALL"
      else probeAction = "CHECK"
      probeAmount = 0
    end
    else do
      if \datatype(probeAmount, "W") then probeAmount = minRaise
      if probeAmount < minRaise then probeAmount = minRaise
    end
  end
  else probeAmount = 0
  d["action"] = probeAction
  d["amount"] = probeAmount
  return d

::class Decision public
::attribute action get
::attribute amount get
::attribute equity get
::attribute potOdds get
::attribute exploitLeverage get
::attribute talkToken get
::attribute talkTarget get
::attribute socialEvidenceId get
::attribute shadowAction get
::attribute shadowAmount get
::attribute controlAction get
::attribute controlAmount get
::method init
  expose action amount equity potOdds exploitLeverage talkToken talkTarget socialEvidenceId shadowAction shadowAmount controlAction controlAmount
  use arg action, amount, equity, potOdds, exploitLeverage = 0, talkToken = "", talkTarget = "", socialEvidenceId = "NONE", shadowAction = "", shadowAmount = 0, controlAction = "", controlAmount = 0

::class Player public subclass PokerAlchemyObject
::attribute name get
::attribute stack
::attribute strategy get
::attribute hole get
::attribute folded
::attribute allIn
::attribute roundBet
::attribute totalBet
::attribute psychologicalPressure get
::attribute provocation get
::attribute lastTalkEntry get
::attribute lastTalkSpeaker get
::attribute lastTalkAnswered
::method init
  expose name stack strategy hole folded allIn roundBet totalBet psychologicalPressure provocation lastTalkEntry lastTalkSpeaker lastTalkAnswered
  use arg name, stack, strategy
  hole = .array~new
  folded = .false
  allIn = .false
  roundBet = 0
  totalBet = 0
  psychologicalPressure = 0
  provocation = 0
  lastTalkEntry = .nil
  lastTalkSpeaker = .nil
  lastTalkAnswered = .true
  self~initPokerAlchemy("PLAYER", "Poker seat state and action boundary")
  self~registerMethodContract("ACT", "Delegate one legal betting decision to the strategy", .array~of("TABLE", "TO_CALL", "MIN_RAISE", "CAN_RAISE"), "DECISION", .false)
  self~registerMethodContract("RECEIVETABLETALK", "Apply one classified public table-talk event", .array~of("ENTRY", "SPEAKER"), "ANY", .false)
  self~recordRelationship("STRATEGY", strategy, "player decision strategy", "INTERNAL")
::method isPsychic
  return .false
::method team
  return ""
::method resetForHand
  expose hole folded allIn roundBet totalBet psychologicalPressure provocation lastTalkEntry lastTalkSpeaker lastTalkAnswered
  hole = .array~new
  folded = .false
  allIn = .false
  roundBet = 0
  totalBet = 0
  psychologicalPressure *= 0.50
  provocation *= 0.50
  lastTalkEntry = .nil
  lastTalkSpeaker = .nil
  lastTalkAnswered = .true
::method receiveCard
  expose hole
  use arg card
  hole~append(card)
::method clearRoundBet
  expose roundBet
  roundBet = 0
::method commit
  expose stack roundBet totalBet allIn
  use arg amount
  if amount < 0 then amount = 0
  if amount > stack then amount = stack
  stack -= amount
  roundBet += amount
  totalBet += amount
  if stack = 0 then allIn = .true
  return amount
::method act
  expose strategy
  use arg table, toCall, minRaise, canRaise = .true
  self~alchemyTouch("ACT")
  d = strategy~decide(self, table, toCall, minRaise, canRaise)
  /* Live API agents already receive public table talk in their prompt.
     Do not double-apply the deterministic psychology postprocessor. */
  st = strategy~strategyType
  if st~left(3) = "AI_" then return d
  if strategy~handlesTableTalkPsychology then do
    self~decayPsychology
    return d
  end
  return table~applyTableTalkPsychology(self, d, toCall, minRaise, canRaise)

::method chooseTalk
  expose strategy
  use arg table, toCall = 0
  return strategy~chooseTalk(self, table, toCall)

::method receiveTableTalk
  expose psychologicalPressure provocation lastTalkEntry lastTalkSpeaker lastTalkAnswered
  use arg entry, speaker = .nil
  self~alchemyTouch("RECEIVE_TABLE_TALK")
  lastTalkEntry = entry
  lastTalkSpeaker = speaker
  lastTalkAnswered = .false
  psychologicalPressure += entry~pressureDelta
  provocation += entry~provocationDelta
  if psychologicalPressure < 0 then psychologicalPressure = 0
  if psychologicalPressure > 1 then psychologicalPressure = 1
  if provocation < 0 then provocation = 0
  if provocation > 1 then provocation = 1

::method decayPsychology
  expose psychologicalPressure provocation
  psychologicalPressure *= 0.92
  provocation *= 0.90
::method strategyType
  expose strategy
  return strategy~strategyType
::method strategyObjective
  expose strategy
  return strategy~objective
::method knownStrategyObjectFor
  use arg target
  return .nil
::method holeString
  expose hole
  if hole~items = 0 then return "--"
  txt = ""
  do i = 1 to hole~items
    if txt <> "" then txt ||= " "
    txt ||= hole[i]~string
  end
  return txt
::method knownCardsFor
  use arg target
  return .nil
::method inspectStrategy
  use arg target
  return .nil

::class PsychicPlayer public subclass Player
::attribute psychicTeam get
::method init
  expose psychicTeam intel
  use arg name, stack, strategy, psychicTeam
  forward class (super) continue
  intel = .directory~new
::method isPsychic
  return .true
::method team
  expose psychicTeam
  return psychicTeam
::method resetForHand
  expose intel
  forward class (super) continue
  intel = .directory~new
::method receiveTeamIntel
  expose intel
  use arg teammate
  copy = .array~new
  h = teammate~hole
  do i = 1 to h~items
    copy~append(h[i])
  end
  intel[teammate~name] = copy
::method knownCardsFor
  expose intel psychicTeam
  use arg target
  if \target~isPsychic then return target~hole
  if target~team = psychicTeam then do
    if intel~hasIndex(target~name) then return intel[target~name]
  end
  return .nil
::method inspectStrategy
  use arg target
  if target~isPsychic then return .nil
  return target~strategy~description
::method knownStrategyObjectFor
  use arg target
  if target~isPsychic then return .nil
  return target~strategy

::class PotSlice public
::attribute amount get
::attribute cap get
::attribute contributors get
::attribute eligible get
::attribute potType get
::method init
  expose amount cap contributors eligible potType
  use arg amount, cap, contributors, eligible, potType

::class PotBuilder public
::method build class
  use arg players
  thresholds = .array~new
  do i = 1 to players~items
    bet = players[i]~totalBet
    if bet <= 0 then iterate
    found = .false
    do j = 1 to thresholds~items
      if thresholds[j] = bet then do; found = .true; leave; end
    end
    if \found then thresholds~append(bet)
  end

  /* Tiny arrays: simple ascending sort keeps the ooRexx implementation boring. */
  do i = 1 to thresholds~items - 1
    do j = i + 1 to thresholds~items
      if thresholds[j] < thresholds[i] then do
        t = thresholds[i]; thresholds[i] = thresholds[j]; thresholds[j] = t
      end
    end
  end

  slices = .array~new
  previous = 0
  contestedNo = 0
  do t = 1 to thresholds~items
    cap = thresholds[t]
    contributors = .array~new
    eligible = .array~new
    do i = 1 to players~items
      p = players[i]
      if p~totalBet >= cap then do
        contributors~append(p)
        if \p~folded then eligible~append(p)
      end
    end
    amount = (cap - previous) * contributors~items
    previous = cap
    if amount <= 0 then iterate
    if contributors~items = 1 then kind = "RETURN"
    else do
      contestedNo += 1
      if contestedNo = 1 then kind = "MAIN"
      else kind = "SIDE"
    end
    slices~append(.PotSlice~new(amount, cap, contributors, eligible, kind))
  end
  return slices

::class PokerTable public subclass PokerAlchemyObject
::attribute name get
::attribute config get
::attribute pot get
::attribute board get
::attribute handNumber get
::attribute street get
::attribute talkLibrarian get
::attribute structuredTalkFactory get
::attribute verbose
::method init
  expose name config players dealerIndex pot board deck currentBet minRaiseAmount observer handNumber street lastAggressor consumptionSeen equityCache verbose rng handLog talkLibrarian lastPromptAudits lastPromptTexts structuredTalkFactory talkSequence
  use arg name, config
  players = .array~new
  dealerIndex = 0
  pot = 0
  board = .array~new
  deck = .nil
  currentBet = 0
  minRaiseAmount = config~bigBlind
  observer = .nil
  handNumber = 0
  street = "IDLE"
  lastAggressor = .nil
  consumptionSeen = .directory~new
  equityCache = .directory~new
  verbose = .true
  rng = .PokerRandom~new(config~seed)
  handLog = .array~new
  talkLibrarian = .PokerTableTalkLibrarian~new
  structuredTalkFactory = .PokerStructuredTalkFactory~new
  talkSequence = 0
  lastPromptAudits = .directory~new
  lastPromptTexts = .directory~new
  self~initPokerAlchemy("POKER_TABLE", "Public poker table state, betting engine and privacy boundary")
  self~registerStateVariable("name", "CUSTOMER", "table name")
  self~registerStateVariable("pot", "CUSTOMER", "current public pot")
  self~registerStateVariable("handNumber", "CUSTOMER", "current hand number")
  self~registerStateVariable("street", "CUSTOMER", "current public street")
  self~registerMethodContract("ADDPLAYER", "Seat a player at the table", .array~of("PLAYER"), "ANY", .false, "AUTO", "CUSTOMER", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("PLAYHAND", "Execute one complete poker hand", .array~new, "ANY", .false, "AUTO", "CUSTOMER", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("AGENTPROMPT", "Build one provenance-audited ordinary-player-view AI prompt", .array~of("PLAYER", "TO_CALL", "MIN_RAISE", "CAN_RAISE", "INCLUDE_SOCIAL"), "STRING", .false, "AUTO", "INTERNAL", "SECURITY_BOUNDARY", "READ", "NONE")
  self~describeMethodData("AGENTPROMPT", "OUTPUT", "prompt", "STRING", .true, "PUBLIC table state plus viewer-owned hole cards; observer/engine/secret state forbidden", "CUSTOMER")
  self~registerMethodContract("PROMPTAUDITFOR", "Return non-content boundary evidence for the last prompt variant", .array~of("VIEWER_NAME", "INCLUDE_SOCIAL"), "ANY", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("PROMPTSTRONGDIGESTFOR", "Return SHA-512 identity of the last prompt without disclosing its content", .array~of("VIEWER_NAME", "INCLUDE_SOCIAL"), "STRING", .false, "AUTO", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~recordRelationship("CONFIG", config, "table game configuration", "INTERNAL")
  self~recordRelationship("RNG", rng, "table deterministic random stream", "SECRET")
  self~recordRelationship("TABLE_TALK_LIBRARIAN", talkLibrarian, "frozen speech dictionary", "INTERNAL")
  self~recordRelationship("STRUCTURED_TALK_FACTORY", structuredTalkFactory, "pre-flattening constrained speech evidence", "INTERNAL")
  self~instrumentPokerMethod("AGENTPROMPT", .true)
::method randomInt
  expose rng
  use arg lo, hi
  return rng~nextInt(lo, hi)
::method observer
  expose observer
  use arg newObserver = .nil
  if arg() > 0 then observer = newObserver
  return observer
::method promptAuditFor
  expose lastPromptAudits
  use arg viewerName, includeSocial = .true
  key = translate(viewerName~string) || "|SOCIAL"
  if includeSocial \= .true then key = translate(viewerName~string) || "|NO_SOCIAL"
  if \lastPromptAudits~hasIndex(key) then return .nil
  source = lastPromptAudits[key]
  copy = .directory~new
  do k over source~allIndexes
    copy[k] = source[k]
  end
  return copy

::method promptStrongDigestFor
  expose lastPromptTexts
  use arg viewerName, includeSocial = .true
  key = translate(viewerName~string) || "|SOCIAL"
  if includeSocial \= .true then key = translate(viewerName~string) || "|NO_SOCIAL"
  if \lastPromptTexts~hasIndex(key) then return ""
  return .SHA512~new(lastPromptTexts[key])~digest

::method seatPlayersRandomized
  expose players
  use arg candidates
  if players~items > 0 then raise syntax 93.900 array("Cannot randomize seating after players are already seated")
  order = .array~new
  do p over candidates
    order~append(p)
  end
  do i = order~items to 2 by -1
    j = self~randomInt(1, i)
    temp = order[i]
    order[i] = order[j]
    order[j] = temp
  end
  do p over order
    self~addPlayer(p)
  end
  return order

::method addPlayer
  expose players
  use arg player
  players~append(player)
  self~alchemyTouch("ADD_PLAYER")
  self~recordRelationship("PLAYER", player, "table seat", "INTERNAL")
::method players
  expose players
  return players
::method resetTournament
  expose players config
  do i = 1 to players~items
    players[i]~stack = config~startingStack
    players[i]~resetForHand
  end
::method buildStructuredTableTalk private
  expose handNumber talkSequence structuredTalkFactory
  use strict arg speaker, target, entry
  talkSequence += 1
  uid = "PP-TALK-" || handNumber || "-" || talkSequence || "-" || speaker~name || "-" || target~name
  utterance = structuredTalkFactory~build(uid, speaker, target, entry)
  summary = structuredTalkFactory~summary(utterance, entry)
  return .array~of(utterance, summary)

::method maybeTableTalk private
  expose players observer street handNumber talkLibrarian
  use arg speaker, toCall

  talk = speaker~chooseTalk(self, toCall)
  if talk == .nil then return
  if talk = "" then return

  entry = talk
  preferredTarget = .nil
  if talk~hasMethod("ENTRY") then do
    if talk~hasMethod("TARGET") then do
      entry = talk~entry
      preferredTarget = talk~target
    end
  end
  if entry == .nil then return

  candidates = .array~new
  do i = 1 to players~items
    target = players[i]
    if target == speaker then iterate
    if target~folded then iterate
    if target~stack <= 0 then iterate
    candidates~append(target)
  end
  if candidates~items = 0 then return

  target = .nil
  if preferredTarget \== .nil then do
    do i = 1 to candidates~items
      if candidates[i] == preferredTarget then do
        target = preferredTarget
        leave
      end
    end
  end
  if target == .nil then target = candidates[self~randomInt(1,candidates~items)]
  target~receiveTableTalk(entry, speaker)
  structured = self~buildStructuredTableTalk(speaker, target, entry)
  utterance = structured[1]
  structuredSummary = structured[2]

  self~log("TALK" speaker~name "->" target~name "[" || entry~talkClass || "]" '"' || entry~phrase || '"')
  if observer <> .nil then do
    if observer~hasMethod("TABLETALK") then observer~tableTalk(self, speaker, target, entry, utterance, structuredSummary)
  end

::method maybeAIDecisionTalk private
  expose players observer talkLibrarian
  use arg speaker, decision

  token = decision~talkToken~strip~upper
  targetName = decision~talkTarget~strip
  if token = "" then return
  if token = "NONE" then return
  if targetName = "" then return
  if translate(targetName) = "NONE" then return

  /* The model chooses only a frozen semantic token.  Free-form text and
     unknown tokens never reach public history. */
  entry = talkLibrarian~classify(token)
  if entry == .nil then return

  target = .nil
  do i = 1 to players~items
    candidate = players[i]
    if candidate == speaker then iterate
    if candidate~folded then iterate
    if candidate~stack <= 0 then iterate
    if translate(candidate~name) = translate(targetName) then do
      target = candidate
      leave
    end
  end
  if target == .nil then return

  target~receiveTableTalk(entry, speaker)
  structured = self~buildStructuredTableTalk(speaker, target, entry)
  utterance = structured[1]
  structuredSummary = structured[2]
  self~log("TALK" speaker~name "->" target~name "[" || entry~talkClass || "]" '"' || entry~phrase || '"')
  if observer <> .nil then do
    if observer~hasMethod("TABLETALK") then observer~tableTalk(self, speaker, target, entry, utterance, structuredSummary)
  end

::method applyTableTalkPsychology
  use arg player, decision, toCall, minRaise, canRaise = .true

  pressure = player~psychologicalPressure
  provocation = player~provocation
  action = decision~action

  /* Pressure can turn only a marginal deterministic call into a fold. */
  if action = "CALL" then do
    if toCall > 0 then do
      threshold = decision~potOdds + pressure * 0.10
      if decision~equity < threshold then do
        player~decayPsychology
        return .Decision~new("FOLD",0,decision~equity,decision~potOdds,decision~exploitLeverage)
      end
    end
  end

  /* Provocation can make an otherwise passive borderline player push back.
     It is bounded, seeded and requires non-trivial equity. */
  if canRaise then do
    if provocation >= 0.35 then do
      if action = "CHECK" | action = "CALL" then do
        if decision~equity >= 0.45 then do
          chance = trunc(provocation * 22)
          if self~randomInt(1,100) <= chance then do
            amount = minRaise
            if amount < 1 then amount = 1
            player~decayPsychology
            return .Decision~new("RAISE",amount,decision~equity,decision~potOdds,decision~exploitLeverage)
          end
        end
      end
    end
  end

  player~decayPsychology
  return decision

::method playHand
  expose players dealerIndex pot board deck currentBet minRaiseAmount config observer handNumber street lastAggressor consumptionSeen equityCache rng handLog
  self~alchemyTouch("PLAY_HAND")
  if players~items < 2 then return

  handNumber += 1
  street = "PREFLOP"
  if observer <> .nil then observer~handStarted(self)

  do i = 1 to players~items
    players[i]~resetForHand
  end
  board = .array~new
  pot = 0
  currentBet = 0
  minRaiseAmount = config~bigBlind
  lastAggressor = .nil
  consumptionSeen = .directory~new
  equityCache = .directory~new
  handLog = .array~new
  deck = .Deck~new(rng)
  dealerIndex = self~nextLiveSeat(dealerIndex)

  /* Deal two hole cards, one card at a time. */
  do round = 1 to 2
    idx = dealerIndex
    do dealt = 1 to players~items
      idx = self~nextSeat(idx)
      if players[idx]~stack > 0 then players[idx]~receiveCard(deck~deal)
    end
  end

  self~exchangePsychicIntel
  if observer <> .nil then observer~capabilitiesCaptured(self)

  sb = self~nextLiveSeat(dealerIndex)
  bb = self~nextLiveSeat(sb)
  self~postBlind(sb, config~smallBlind, "SB")
  self~postBlind(bb, config~bigBlind, "BB")
  currentBet = players[bb]~roundBet
  minRaiseAmount = config~bigBlind

  self~log("dealer="players[dealerIndex]~name " board=[ ]")
  do i = 1 to players~items
    p = players[i]
    self~observerLog("  seat" i || ":" p~name "stack=" || p~stack "cards=" || p~holeString)
  end
  self~bettingRound(self~nextLiveSeat(bb))
  self~refundUncalledBet
  if self~activeCount <= 1 then do; self~awardUncontested; return; end

  self~clearRoundBets
  street = "FLOP"
  self~burn
  board~append(deck~deal); board~append(deck~deal); board~append(deck~deal)
  self~log("flop:" self~boardString)
  self~bettingRound(self~nextLiveSeat(dealerIndex))
  self~refundUncalledBet
  if self~activeCount <= 1 then do; self~awardUncontested; return; end

  self~clearRoundBets
  street = "TURN"
  self~burn
  board~append(deck~deal)
  self~log("turn:" self~boardString)
  self~bettingRound(self~nextLiveSeat(dealerIndex))
  self~refundUncalledBet
  if self~activeCount <= 1 then do; self~awardUncontested; return; end

  self~clearRoundBets
  street = "RIVER"
  self~burn
  board~append(deck~deal)
  self~log("river:" self~boardString)
  self~bettingRound(self~nextLiveSeat(dealerIndex))
  self~refundUncalledBet
  if self~activeCount <= 1 then do; self~awardUncontested; return; end

  self~showdown
::method postBlind private
  expose players pot
  use arg idx, amount, label
  paid = players[idx]~commit(amount)
  pot += paid
  self~log(label players[idx]~name "posts" paid)
::method bettingRound private
  expose players currentBet minRaiseAmount pot config observer lastAggressor
  use arg startIdx
  if self~actableCount = 0 then return
  if self~actableCount = 1 & self~allBetsMatched then return

  pending = .directory~new
  actedSinceFullRaise = .directory~new
  do i = 1 to players~items
    p = players[i]
    if \p~folded & \p~allIn & p~stack > 0 then do
      pending[p~name] = 1
      actedSinceFullRaise[p~name] = 0
    end
  end

  idx = self~prevSeat(startIdx)
  safety = 0
  do while pending~items > 0 & safety < players~items * 30
    safety += 1
    idx = self~nextSeat(idx)
    p = players[idx]
    if \pending~hasIndex(p~name) then iterate
    if p~stack = 0 | p~folded | p~allIn then do
      pending~remove(p~name)
      iterate
    end

    toCall = currentBet - p~roundBet
    if toCall < 0 then toCall = 0
    canRaise = .true
    if actedSinceFullRaise~hasIndex(p~name) then do
      if actedSinceFullRaise[p~name] = 1 then canRaise = .false
    end

    strategyType = p~strategyType
    if strategyType~left(3) \= "AI_" then self~maybeTableTalk(p, toCall)
    d = p~act(self, toCall, minRaiseAmount, canRaise)
    if strategyType~left(3) = "AI_" then self~maybeAIDecisionTalk(p, d)
    action = d~action
    if action = "RAISE" & \canRaise then do
      if toCall > 0 then action = "CALL"
      else action = "CHECK"
      d = .Decision~new(action, toCall, d~equity, d~potOdds, d~exploitLeverage)
    end

    pending~remove(p~name)
    actedSinceFullRaise[p~name] = 1

    if action = "FOLD" then do
      p~folded = .true
      self~log(p~name "folds" self~decisionTail(d))
    end
    else if action = "RAISE" then do
      /* Decision amount is the requested raise increment above the call. */
      desired = toCall + d~amount
      paid = p~commit(desired)
      pot += paid
      if p~roundBet > currentBet then do
        actualRaise = p~roundBet - currentBet
        currentBet = p~roundBet
        lastAggressor = p
        if actualRaise >= minRaiseAmount then do
          /* A full raise reopens betting for every other actable player. */
          minRaiseAmount = actualRaise
          pending = .directory~new
          do j = 1 to players~items
            other = players[j]
            if other == p then iterate
            if \other~folded & \other~allIn & other~stack > 0 then do
              pending[other~name] = 1
              actedSinceFullRaise[other~name] = 0
            end
          end
          self~log(p~name "raises to" currentBet self~decisionTail(d))
        end
        else do
          /* A short all-in changes the call amount but does not reopen raising
             for players who have already acted since the last full raise. */
          do j = 1 to players~items
            other = players[j]
            if other == p then iterate
            if \other~folded & \other~allIn & other~stack > 0 then do
              if other~roundBet < currentBet then pending[other~name] = 1
            end
          end
          self~log(p~name "raises all-in to" currentBet self~decisionTail(d))
        end
      end
      else do
        self~log(p~name "calls all-in" paid self~decisionTail(d))
      end
    end
    else if action = "CALL" then do
      paid = p~commit(toCall)
      pot += paid
      if p~allIn & paid < toCall then self~log(p~name "calls all-in" paid self~decisionTail(d))
      else self~log(p~name "calls" paid self~decisionTail(d))
    end
    else do
      self~log(p~name "checks" self~decisionTail(d))
    end

    if observer <> .nil then observer~actionTaken(self, p, d, toCall)
    if self~activeCount <= 1 then return
    if self~actableCount = 0 then return
    if pending~items = 0 & self~allBetsMatched then return
  end
::method refundUncalledBet private
  expose players pot observer street
  highest = -1
  second = -1
  highPlayer = .nil
  tiesAtHigh = 0
  do i = 1 to players~items
    bet = players[i]~roundBet
    if bet > highest then do
      second = highest
      highest = bet
      highPlayer = players[i]
      tiesAtHigh = 1
    end
    else if bet = highest then tiesAtHigh += 1
    else if bet > second then second = bet
  end
  if highest <= 0 | highPlayer == .nil | tiesAtHigh > 1 then return
  if second < 0 then second = 0
  refund = highest - second
  if refund <= 0 then return
  highPlayer~stack += refund
  highPlayer~roundBet -= refund
  highPlayer~totalBet -= refund
  if highPlayer~stack > 0 then highPlayer~allIn = .false
  pot -= refund
  self~log(highPlayer~name "uncalled bet returned" refund)
  if observer <> .nil then observer~uncalledReturned(self, highPlayer, refund)
::method decisionTail private
  use arg d
  return "(eq="format(d~equity,1,2) "odds="format(d~potOdds,1,2)")"
::method clearRoundBets private
  expose players currentBet minRaiseAmount config lastAggressor
  do i = 1 to players~items
    players[i]~clearRoundBet
  end
  currentBet = 0
  minRaiseAmount = config~bigBlind
  lastAggressor = .nil
::method activeCount private
  expose players
  n = 0
  do i = 1 to players~items
    if players[i]~stack > 0 | players[i]~totalBet > 0 then do
      if \players[i]~folded then n += 1
    end
  end
  return n
::method actableCount private
  expose players
  n = 0
  do i = 1 to players~items
    if \players[i]~folded & \players[i]~allIn & players[i]~stack > 0 then n += 1
  end
  return n
::method allBetsMatched private
  expose players currentBet
  do i = 1 to players~items
    p = players[i]
    if \p~folded & \p~allIn & p~stack > 0 then do
      if p~roundBet <> currentBet then return .false
    end
  end
  return .true
::method nextSeat private
  expose players
  use arg idx
  idx += 1
  if idx > players~items then idx = 1
  return idx
::method prevSeat private
  expose players
  use arg idx
  idx -= 1
  if idx < 1 then idx = players~items
  return idx
::method nextLiveSeat private
  expose players
  use arg idx
  do k = 1 to players~items
    idx = self~nextSeat(idx)
    if players[idx]~stack > 0 then return idx
  end
  return 1
::method burn private
  expose deck
  x = deck~deal
::method exchangePsychicIntel private
  expose players
  do i = 1 to players~items
    receiver = players[i]
    if \receiver~isPsychic then iterate
    do j = 1 to players~items
      sender = players[j]
      if i = j then iterate
      if sender~isPsychic then do
        if sender~team = receiver~team then receiver~receiveTeamIntel(sender)
      end
    end
  end
::method boardString
  expose board
  txt = ""
  do i = 1 to board~items
    if txt <> "" then txt ||= " "
    txt ||= board[i]~string
  end
  return txt
::method awardUncontested private
  expose players pot observer street
  do i = 1 to players~items
    if \players[i]~folded & players[i]~totalBet > 0 then do
      players[i]~stack += pot
      self~log(players[i]~name "wins uncontested pot" pot)
      if observer <> .nil then observer~potSettled(self, 1, "UNCONTESTED", pot, players[i]~totalBet, players[i], pot, 1)
      pot = 0
      street = "COMPLETE"
      if observer <> .nil then observer~handCompleted(self, "UNCONTESTED")
      return
    end
  end
::method showdown private
  expose players pot board observer street dealerIndex
  scores = .directory~new
  do i = 1 to players~items
    p = players[i]
    if p~folded | p~totalBet = 0 then iterate
    cards = .array~new
    h = p~hole
    cards~append(h[1]); cards~append(h[2])
    do b = 1 to board~items; cards~append(board[b]); end
    score = .HandEvaluator~bestScore(cards)
    scores[p~name] = score
    self~log(p~name "shows" p~holeString "score="score)
  end

  slices = .PotBuilder~build(players)
  contestedIndex = 0
  distributed = 0
  do sidx = 1 to slices~items
    slice = slices[sidx]
    amount = slice~amount
    if slice~potType = "RETURN" then do
      receiver = slice~contributors[1]
      receiver~stack += amount
      distributed += amount
      self~log(receiver~name "receives uncalled excess" amount)
      if observer <> .nil then observer~potSettled(self, sidx, "RETURN", amount, slice~cap, receiver, amount, slice~eligible~items)
      iterate
    end

    contestedIndex += 1
    eligible = slice~eligible
    if eligible~items = 0 then iterate
    best = -1
    winners = .array~new
    do i = 1 to eligible~items
      p = eligible[i]
      score = scores[p~name]
      if score > best then do
        best = score
        winners = .array~new
        winners~append(p)
      end
      else if score = best then winners~append(p)
    end

    share = amount % winners~items
    remainder = amount // winners~items
    label = "side pot" contestedIndex - 1
    if contestedIndex = 1 then label = "main pot"
    do i = 1 to winners~items
      gain = share
      if i <= remainder then gain += 1
      winners[i]~stack += gain
      distributed += gain
      self~log(winners[i]~name "wins" label gain)
      if observer <> .nil then observer~potSettled(self, contestedIndex, slice~potType, amount, slice~cap, winners[i], gain, eligible~items)
    end
  end
  if distributed \= pot then do
    self~log("WARNING pot settlement mismatch pot="pot "distributed="distributed)
  end
  pot = 0
  street = "COMPLETE"
  if observer <> .nil then observer~handCompleted(self, "SHOWDOWN")
::method showStacks
  expose players
  do i = 1 to players~items
    p = players[i]
    kind = p~strategyType
    if p~isPsychic then kind ||= "/" || p~team
    self~log(right(p~name, 8) right(p~stack, 5) kind "cards=" || p~holeString)
  end
::method observerLog private
  expose verbose
  use arg text
  if verbose then say text

::method log private
  expose verbose handLog
  use arg text
  handLog~append(text)
  if verbose then say text

::method agentPrompt
  expose players dealerIndex handLog config observer lastPromptAudits lastPromptTexts
  use arg player, toCall, minRaise, canRaise, includeSocial = .true
  nl = "0a"x
  envelope = .PokerPromptEnvelope~new(player~name)
  envelope~append("POLICY.IDENTITY", "PUBLIC", "You are " || player~name || ", a poker player seated in HardWorld Casino." || nl)
  envelope~append("POLICY.INFORMATION_BOUNDARY", "PUBLIC", "Play only from the information supplied below." || nl)
  envelope~append("POLICY.OBJECTIVE", "PUBLIC", "Your objective is to maximise your own long-run chip bankroll." || nl || nl)
  envelope~append("GAME.HEADER", "PUBLIC", "GAME" || nl)
  envelope~append("GAME.VARIANT", "PUBLIC", "variant: no-limit Texas Hold'em" || nl)
  envelope~append("GAME.SMALL_BLIND", "PUBLIC", "small blind: " || config~smallBlind || nl)
  envelope~append("GAME.BIG_BLIND", "PUBLIC", "big blind: " || config~bigBlind || nl)
  envelope~append("GAME.STREET", "PUBLIC", "street: " || self~street || nl)
  envelope~append("GAME.POT", "PUBLIC", "pot: " || self~pot || nl)
  if dealerIndex > 0 then envelope~append("GAME.DEALER", "PUBLIC", "dealer: " || players[dealerIndex]~name || nl)
  else envelope~append("GAME.DEALER", "PUBLIC", "dealer: not yet assigned" || nl)
  envelope~append("SELF.NAME", "PUBLIC", "your name: " || player~name || nl)
  envelope~append("SELF.STACK", "PUBLIC", "your stack: " || player~stack || nl)
  envelope~append("SELF.HOLE_CARDS", "CUSTOMER", "your cards: " || player~holeString || nl)
  envelope~append("GAME.BOARD", "PUBLIC", "board: " || self~boardString || nl)
  envelope~append("GAME.TO_CALL", "PUBLIC", "amount to call: " || toCall || nl)
  envelope~append("GAME.MIN_RAISE", "PUBLIC", "minimum legal raise increment: " || minRaise || nl)
  if canRaise then envelope~append("GAME.CAN_RAISE", "PUBLIC", "raising permitted: YES" || nl)
  else envelope~append("GAME.CAN_RAISE", "PUBLIC", "raising permitted: NO" || nl)
  envelope~append("PLAYERS.HEADER", "PUBLIC", nl || "PLAYERS" || nl)
  do i = 1 to players~items
    p = players[i]
    status = "ACTIVE"
    if p~folded then status = "FOLDED"
    else if p~allIn then status = "ALL-IN"
    line = p~name || ": stack=" || p~stack || " round_bet=" || p~roundBet || " status=" || status
    if p == player then line ||= " (YOU)"
    envelope~append("PLAYERS.PUBLIC_STATE", "PUBLIC", line || nl)
  end
  if includeSocial then do
    if observer \= .nil then do
      if observer~hasMethod("SOCIALEVIDENCEFOR") then do
        socialText = observer~socialEvidenceFor(self, player)
        if socialText \= "" then envelope~append("SOCIAL.EMPIRICAL_HISTORY", "PUBLIC", nl || socialText || nl)
      end
    end
  end
  else do
    envelope~append("SOCIAL.COUNTERFACTUAL_POLICY", "PUBLIC", nl || "SOCIAL EVIDENCE DISABLED FOR COUNTERFACTUAL PROBE" || nl)
    envelope~append("SOCIAL.COUNTERFACTUAL_POLICY", "PUBLIC", "Do not infer or reconstruct omitted social-history statistics from prior context." || nl)
  end
  envelope~append("PUBLIC.HISTORY.HEADER", "PUBLIC", nl || "PUBLIC HAND HISTORY" || nl)
  do i = 1 to handLog~items
    envelope~append("PUBLIC.HISTORY.EVENT", "PUBLIC", handLog[i] || nl)
  end
  envelope~append("POLICY.ACTION", "PUBLIC", nl || "Choose exactly one legal action." || nl)
  if toCall > 0 then legal = "Legal base actions: FOLD, CALL"
  else legal = "Legal base actions: CHECK"
  if canRaise then legal ||= ", RAISE"
  envelope~append("POLICY.LEGAL_ACTIONS", "PUBLIC", legal || nl)
  envelope~append("POLICY.RAISE_UNITS", "PUBLIC", "For RAISE, AMOUNT is the raise increment above the call, not the total bet." || nl)
  envelope~append("TALK.HEADER", "PUBLIC", nl || "OPTIONAL TABLE TALK" || nl)
  envelope~append("TALK.POLICY", "PUBLIC", "You may speak once on this decision, but only by selecting one frozen token below." || nl)
  envelope~append("TALK.POLICY", "PUBLIC", "The casino supplies the phrase; never invent table-talk prose." || nl)
  librarian = self~talkLibrarian
  do talkIndex = 1 to librarian~tokenCount
    talkEntry = librarian~entryAt(talkIndex)
    envelope~append("TALK.DICTIONARY", "PUBLIC", talkEntry~token || " [" || talkEntry~talkClass || "] " || '"' || talkEntry~phrase || '"' || nl)
  end
  envelope~append("TALK.TARGET_POLICY", "PUBLIC", "TALK_TARGET must be an active opponent name from PLAYERS, or NONE." || nl)
  if includeSocial then do
    envelope~append("SOCIAL.ATTRIBUTION_POLICY", "PUBLIC", "SOCIAL_EVIDENCE names the decision-local evidence ID (E1, E2, ...) that materially informed your betting decision, or NONE." || nl)
    envelope~append("SOCIAL.ATTRIBUTION_POLICY", "PUBLIC", "Do not claim an evidence ID merely because it is present; use NONE when social evidence did not affect the action or sizing." || nl)
  end
  else envelope~append("SOCIAL.ATTRIBUTION_POLICY", "PUBLIC", "SOCIAL_EVIDENCE must be NONE because social evidence is disabled in this counterfactual probe." || nl)
  envelope~append("OUTPUT.CONTRACT", "PUBLIC", "Reply with exactly five lines and no other text:" || nl)
  envelope~append("OUTPUT.CONTRACT", "PUBLIC", "ACTION=FOLD|CHECK|CALL|RAISE" || nl)
  envelope~append("OUTPUT.CONTRACT", "PUBLIC", "AMOUNT=<non-negative integer; 0 unless raising>" || nl)
  envelope~append("OUTPUT.CONTRACT", "PUBLIC", "TALK=NONE|<one frozen token above>" || nl)
  envelope~append("OUTPUT.CONTRACT", "PUBLIC", "TALK_TARGET=NONE|<active opponent name>" || nl)
  envelope~append("OUTPUT.CONTRACT", "PUBLIC", "SOCIAL_EVIDENCE=NONE|<one displayed E-id>" || nl)
  prompt = envelope~finalize
  key = translate(player~name) || "|SOCIAL"
  if includeSocial \= .true then key = translate(player~name) || "|NO_SOCIAL"
  lastPromptAudits[key] = envelope~auditSummary
  lastPromptTexts[key] = prompt
  return prompt
::method psychicFoldLeverage
  expose players pot currentBet
  use arg viewer, raiseIncrement
  if \viewer~isPsychic then return 0
  proposedBet = currentBet + raiseIncrement
  totalProbability = 0
  readable = 0
  do i = 1 to players~items
    target = players[i]
    if target == viewer | target~folded | target~allIn | target~stack = 0 then iterate
    knownHole = viewer~knownCardsFor(target)
    if knownHole == .nil then iterate
    self~recordPsychicConsumption(viewer, target, "CARD_READ", target~holeString)
    strategy = viewer~knownStrategyObjectFor(target)
    if strategy == .nil then iterate
    self~recordPsychicConsumption(viewer, target, "STRATEGY_READ", strategy~description)
    targetToCall = proposedBet - target~roundBet
    if targetToCall < 0 then targetToCall = 0
    if targetToCall = 0 then iterate
    odds = targetToCall / (pot + targetToCall)
    perceivedEquity = self~estimateEquity(target, 4)
    totalProbability += strategy~foldProbability(perceivedEquity, odds)
    readable += 1
  end
  if readable = 0 then return 0
  return totalProbability / readable

::method estimateBlindPsychicEquity
  expose players board
  use arg viewer, samples = 96
  if \viewer~isPsychic then return 0
  if samples < 8 then samples = 8

  /* Benny's own cards are intentionally NOT part of his information set. */
  known = .directory~new
  do i = 1 to board~items
    known[board[i]~key] = 1
  end

  opponents = .array~new
  do i = 1 to players~items
    target = players[i]
    if target == viewer then iterate
    if target~folded then iterate
    if target~hole~items \= 2 then iterate
    opponents~append(target)
    do k = 1 to target~hole~items
      known[target~hole[k]~key] = 1
    end
  end

  pool = self~unknownCardPool(known)
  if pool~items < 2 then return 0

  wins = 0
  ties = 0
  tested = 0

  do n = 1 to samples
    a = self~randomInt(1,pool~items)
    b = self~randomInt(1,pool~items - 1)
    if b >= a then b += 1
    candidate = .array~of(pool[a], pool[b])
    if \self~completeHoleCards(candidate) then iterate

    myScore = self~scoreForCards(candidate, board)
    bestOpp = 0
    do r = 1 to opponents~items
      target = opponents[r]
      oppScore = self~scoreForCards(target~hole, board)
      if oppScore > bestOpp then bestOpp = oppScore
    end

    if myScore > bestOpp then wins += 1
    else if myScore = bestOpp then ties += 1
    tested += 1
  end

  if tested = 0 then return 0
  return (wins + ties * 0.5) / tested

::method blindPsychicFieldWeakness
  expose players board
  use arg viewer

  active = 0
  weak = 0
  do i = 1 to players~items
    target = players[i]
    if target == viewer then iterate
    if target~folded then iterate
    if target~hole~items \= 2 then iterate
    active += 1

    /* Weakness is relative to plausible board-completing strength, not Benny's
       own unknown cards. */
    oppScore = self~scoreForCards(target~hole, board)
    known = .directory~new
    do b = 1 to board~items
      known[board[b]~key] = 1
    end
    do h = 1 to target~hole~items
      known[target~hole[h]~key] = 1
    end
    pool = self~unknownCardPool(known)
    if pool~items >= 2 then do
      better = 0
      trials = 0
      limit = 20
      do n = 1 to limit
        a = self~randomInt(1,pool~items)
        c = self~randomInt(1,pool~items - 1)
        if c >= a then c += 1
        candidate = .array~of(pool[a],pool[c])
        if \self~completeHoleCards(candidate) then iterate
        if self~scoreForCards(candidate,board) > oppScore then better += 1
        trials += 1
      end
      if trials > 0 then do
        if better / trials >= 0.55 then weak += 1
      end
    end
  end

  if active = 0 then return 0
  return weak / active

::method psychicRepresentationLeverage
  expose players board
  use arg viewer, samplePairs = 24
  if \viewer~isPsychic then return 0
  if board~items < 3 then return 0
  if samplePairs < 4 then samplePairs = 4

  /* Build the information set actually available to this psychic. */
  known = .directory~new
  vh = viewer~hole
  do i = 1 to vh~items; known[vh[i]~key] = 1; end
  do i = 1 to board~items; known[board[i]~key] = 1; end

  readable = .array~new
  do i = 1 to players~items
    target = players[i]
    if target == viewer | target~folded then iterate
    kh = viewer~knownCardsFor(target)
    if kh == .nil then iterate
    do k = 1 to kh~items; known[kh[k]~key] = 1; end
    if \target~isPsychic then readable~append(target)
  end
  if readable~items = 0 then return 0

  pool = self~unknownCardPool(known)
  if pool~items < 2 then return 0
  total = 0

  do r = 1 to readable~items
    target = readable[r]
    kh = viewer~knownCardsFor(target)
    if \self~completeHoleCards(kh) then iterate
    self~recordPsychicConsumption(viewer, target, "CARD_READ", target~holeString)
    targetScore = self~scoreForCards(kh, board)
    better = 0
    tested = 0

    /* Sample plausible unseen two-card holdings.  These are not predictions of
       the viewer's cards; they measure what stronger hand the public board can
       credibly represent to this exact opponent. */
    do n = 1 to samplePairs
      a = self~randomInt(1, pool~items)
      b = self~randomInt(1, pool~items - 1)
      if b >= a then b += 1
      candidate = .array~of(pool[a], pool[b])
      if \self~completeHoleCards(candidate) then iterate
      candidateScore = self~scoreForCards(candidate, board)
      if candidateScore > targetScore then better += 1
      tested += 1
    end
    if tested > 0 then total += better / tested
  end

  return total / readable~items

::method teamMatePressure
  expose lastAggressor
  use arg viewer
  if \viewer~isPsychic then return .false
  if lastAggressor == .nil then return .false
  if lastAggressor == viewer then return .false
  if \lastAggressor~isPsychic then return .false
  if lastAggressor~team \= viewer~team then return .false
  return .true
::method estimateEquity
  expose players board config equityCache handNumber street
  use arg viewer, sampleCount = 0
  if sampleCount <= 0 then sampleCount = config~equitySamples

  /* Equity depends on cards/board/live opponents, not bet sizing.  Reuse a
     Monte-Carlo result until one of those state dimensions changes. */
  cacheKey = viewer~name || "|" || sampleCount || "|" || street || "|" || self~boardString
  do ci = 1 to players~items
    cp = players[ci]
    if cp~hole~items >= 2 then cacheKey ||= "|" || cp~name || ":" || cp~folded
  end
  if equityCache~hasIndex(cacheKey) then return equityCache[cacheKey]

  /* Monte-Carlo equity from the viewer's legal/privileged information set. */
  known = .directory~new
  vh = viewer~hole
  known[vh[1]~key] = 1; known[vh[2]~key] = 1
  do b = 1 to board~items; known[board[b]~key] = 1; end

  opponents = .array~new
  fixed = .directory~new
  do i = 1 to players~items
    p = players[i]
    if p == viewer | p~folded then iterate
    if p~hole~items < 2 then iterate
    opponents~append(p)
    kh = viewer~knownCardsFor(p)
    if kh <> .nil then do
      detail = p~holeString
      obsType = "CARD_READ"
      if p~isPsychic then obsType = "TEAM_MESSAGE"
      self~recordPsychicConsumption(viewer, p, obsType, detail)
      fixed[p~name] = kh
      do k = 1 to kh~items; known[kh[k]~key] = 1; end
    end
  end
  if opponents~items = 0 then do
    equityCache[cacheKey] = 1.0
    return 1.0
  end

  wins = 0
  ties = 0
  do sample = 1 to sampleCount
    pool = self~unknownCardPool(known)
    self~shuffleArray(pool)
    pos = 1

    oppHoles = .directory~new
    do o = 1 to opponents~items
      op = opponents[o]
      if fixed~hasIndex(op~name) then oppHoles[op~name] = fixed[op~name]
      else do
        hh = .array~new
        hh~append(pool[pos]); pos += 1
        hh~append(pool[pos]); pos += 1
        oppHoles[op~name] = hh
      end
    end

    simBoard = .array~new
    do b = 1 to board~items; simBoard~append(board[b]); end
    do while simBoard~items < 5
      simBoard~append(pool[pos]); pos += 1
    end

    mine = self~scoreForCards(vh, simBoard)
    top = mine
    beaten = .false
    equalTop = .false
    do o = 1 to opponents~items
      op = opponents[o]
      os = self~scoreForCards(oppHoles[op~name], simBoard)
      if os > mine then do; beaten = .true; leave; end
      if os = mine then equalTop = .true
    end
    if \beaten then do
      if equalTop then ties += 1
      else wins += 1
    end
  end
  computedEquity = (wins + ties * 0.5) / sampleCount
  equityCache[cacheKey] = computedEquity
  return computedEquity
::method recordPsychicConsumption private
  expose observer consumptionSeen
  use arg viewer, target, observationType, detail
  if observer == .nil then return
  if \viewer~isPsychic then return
  key = viewer~name || "|" || target~name || "|" || observationType
  if consumptionSeen~hasIndex(key) then return
  consumptionSeen[key] = 1
  observer~psychicObservation(self, viewer, target, observationType, detail)
::method scoreForCards private
  use arg hole, simBoard
  all = .array~new
  all~append(hole[1]); all~append(hole[2])
  do i = 1 to simBoard~items; all~append(simBoard[i]); end
  return .HandEvaluator~bestScore(all)
::method completeHoleCards private
  use arg cards
  if cards == .nil then return .false
  if cards~items \= 2 then return .false
  if cards[1] == .nil then return .false
  if cards[2] == .nil then return .false
  return .true

::method unknownCardPool private
  use arg known
  pool = .array~new
  suits = "S H D C"
  do s = 1 to words(suits)
    suit = word(suits,s)
    do rank = 2 to 14
      key = rank || suit
      if \known~hasIndex(key) then pool~append(.Card~new(rank,suit))
    end
  end
  return pool
::method shuffleArray private
  expose rng
  use arg a
  do i = a~items to 2 by -1
    j = rng~nextInt(1, i)
    t = a[i]; a[i] = a[j]; a[j] = t
  end

::class HandEvaluator public
::method bestScore class
  use arg cards
  if cards~items < 5 then return 0
  best = -1
  n = cards~items
  do a = 1 to n-4
    do b = a+1 to n-3
      do c = b+1 to n-2
        do d = c+1 to n-1
          do e = d+1 to n
            five = .array~of(cards[a],cards[b],cards[c],cards[d],cards[e])
            s = self~scoreFive(five)
            if s > best then best = s
          end
        end
      end
    end
  end
  return best
::method scoreFive class private
  use arg cards
  ranks = .array~new(5)
  suits = .array~new(5)
  count. = 0
  do i = 1 to 5
    ranks[i] = cards[i]~rank
    suits[i] = cards[i]~suit
    r = cards[i]~rank
    count.r += 1
  end
  self~sortDesc(ranks)

  flush = .true
  do i = 2 to 5
    if suits[i] <> suits[1] then flush = .false
  end

  unique = .array~new
  last = -1
  do i = 1 to 5
    if ranks[i] <> last then do
      unique~append(ranks[i]); last = ranks[i]
    end
  end
  straightHigh = 0
  if unique~items = 5 then do
    if unique[1] - unique[5] = 4 then straightHigh = unique[1]
    else if unique[1]=14 & unique[2]=5 & unique[3]=4 & unique[4]=3 & unique[5]=2 then straightHigh=5
  end

  if flush & straightHigh > 0 then return self~encode(8, .array~of(straightHigh,0,0,0,0))

  four = 0; triple = 0; pair1 = 0; pair2 = 0
  singles = .array~new
  do r = 14 to 2 by -1
    select
      when count.r = 4 then four = r
      when count.r = 3 then triple = r
      when count.r = 2 then do
        if pair1 = 0 then pair1 = r
        else pair2 = r
      end
      when count.r = 1 then singles~append(r)
      otherwise nop
    end
  end
  if four > 0 then return self~encode(7, .array~of(four,singles[1],0,0,0))
  if triple > 0 & pair1 > 0 then return self~encode(6, .array~of(triple,pair1,0,0,0))
  if flush then return self~encode(5, ranks)
  if straightHigh > 0 then return self~encode(4, .array~of(straightHigh,0,0,0,0))
  if triple > 0 then return self~encode(3, .array~of(triple,singles[1],singles[2],0,0))
  if pair1 > 0 & pair2 > 0 then return self~encode(2, .array~of(pair1,pair2,singles[1],0,0))
  if pair1 > 0 then return self~encode(1, .array~of(pair1,singles[1],singles[2],singles[3],0))
  return self~encode(0, ranks)
::method sortDesc class private
  use arg a
  do i = 1 to a~items-1
    do j = i+1 to a~items
      if a[j] > a[i] then do
        t=a[i]; a[i]=a[j]; a[j]=t
      end
    end
  end
::method encode class private
  use arg category, values
  score = category
  do i = 1 to 5
    v = 0
    if i <= values~items then v = values[i]
    score = score * 15 + v
  end
  return score

::requires "deps/alchemy_objects_v0.7/src/AlchemyObject.cls"

::requires 'deps/structured_utterance_v0.3/src/StructuredUtterance.cls'
