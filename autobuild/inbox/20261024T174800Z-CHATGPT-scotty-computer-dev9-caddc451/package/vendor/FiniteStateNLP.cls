/* FiniteStateNLP.cls
   Ninth swappable NLP strategy (engine FST / WFST / AUTOMATON).

   University-archive paradigm: deterministic Finite-State Acceptors /
   Transducers compiled from the registered surface forms
   (AT&T Research / Xerox PARC lineage — Mohri, Pereira, Riley et al.,
   1990s weighted finite-state transducer pipeline).  Academia largely
   abandoned pure FSTs for deep learning; the representation remains
   ideal for a small, closed, high-precision domain.

   The engine compiles every approved phrase and distinctive term into a
   single trie-like state machine:

     state 0 (start)
       --token--> state
         --token--> ...
           --FINAL--> intent

   Classification is pure state-transition pointer walking over the
   tokenised utterance.  No floating-point arithmetic, no similarity
   scores, no generative model, no rule ranking.  If the walk ends in a
   final state the associated intent is emitted; otherwise UNKNOWN.

   Learning (addApprovedPhrase) simply adds a new path through the
   automaton.  The machine stays deterministic; conflicting finals are
   resolved by keeping the first-registered intent (conservative).

   Pure ooRexx, deterministic, same registration surface and route
   envelope.  Select with VIRTUAL_REP_NLP_ENGINE=FST
   (or WFST or AUTOMATON).
*/

::class FiniteStateNLPParser public

::method init
  expose intentTable intentOrder conceptTable conceptOrder -
         threshold ambiguityMargin activeMode activeLanguage activeApplication -
         transitions finals stateCount modelDirty
  intentTable = .Directory~new
  intentOrder = .Array~new
  conceptTable = .Directory~new
  conceptOrder = .Array~new
  threshold = 1
  ambiguityMargin = 0
  activeMode = "ANY"
  activeLanguage = "ANY"
  activeApplication = "ANY"
  transitions = .Directory~new   /* key = "state|token" -> nextState */
  finals = .Directory~new       /* state -> intentId */
  stateCount = 1                /* state 0 is the start state */
  modelDirty = 1

::method version
  return "0.1-dev1-finitestate"

::method strategyName
  return "FINITE_STATE_TRANSDUCER"

::method configure
  expose threshold ambiguityMargin
  use arg newThreshold, newAmbiguityMargin
  if arg(1, "O") = 0 then threshold = newThreshold
  if arg(2, "O") = 0 then ambiguityMargin = newAmbiguityMargin
  return self

::method setContext
  expose activeMode activeLanguage activeApplication
  use arg mode, language, application
  activeMode = self~normalizeContextValue(mode)
  activeLanguage = self~normalizeContextValue(language)
  activeApplication = self~normalizeContextValue(application)
  if activeMode == "OS" then do
    activeLanguage = ""
    activeApplication = ""
  end
  else if activeMode == "CODING" then activeApplication = ""
  else if activeMode == "CUSTOMER_SERVICE" then activeLanguage = ""
  return self

::method activeContext
  expose activeMode activeLanguage activeApplication
  context = .Directory~new
  context~put("symbolic.nlp.context/0.1", "SCHEMA")
  context~put(activeMode, "MODE")
  context~put(activeLanguage, "LANGUAGE")
  context~put(activeApplication, "APPLICATION")
  return context

::method registerConcept
  expose conceptTable conceptOrder modelDirty
  use arg id, role, terms
  id = translate(strip(id))
  role = translate(strip(role))
  if id == "" then raise syntax 93.900 array("Concept id must not be empty")
  if conceptTable~hasIndex(id) = 0 then do
    spec = .Directory~new
    spec~put(id, "ID")
    spec~put(role, "ROLE")
    spec~put(self~normalizeTerms(terms), "TERMS")
    conceptTable~put(spec, id)
    conceptOrder~append(id)
  end
  else do
    spec = conceptTable~at(id)
    old = spec~at("TERMS")
    if old == "" then spec~put(self~normalizeTerms(terms), "TERMS")
    else spec~put(old || "|" || self~normalizeTerms(terms), "TERMS")
  end
  modelDirty = 1
  return self

::method registerSemanticIntent
  expose intentTable intentOrder modelDirty
  use arg intentId, verbConcepts, nounConcepts, phraseTerms, priority
  if arg(4, "O") = 1 then phraseTerms = ""
  if arg(5, "O") = 1 then priority = 0
  intentId = translate(strip(intentId))
  if intentId == "" then raise syntax 93.900 array("Intent id must not be empty")
  verbs = self~expandConceptTerms(self~normalizeConceptIds(verbConcepts), "VERB")
  nouns = self~expandConceptTerms(self~normalizeConceptIds(nounConcepts), "NOUN")
  self~registerIntent(intentId, verbs, nouns, phraseTerms, priority)
  return self

::method registerIntent
  expose intentTable intentOrder modelDirty
  use arg intentId, verbs, nouns, phrases, priority
  intentId = translate(strip(intentId))
  if intentId == "" then raise syntax 93.900 array("Intent id must not be empty")
  if intentTable~hasIndex(intentId) = 0 then do
    spec = .Directory~new
    spec~put(intentId, "ID")
    spec~put(self~normalizeTerms(verbs), "VERBS")
    spec~put(self~normalizeTerms(nouns), "NOUNS")
    spec~put(self~normalizeTerms(phrases), "PHRASES")
    spec~put("", "LEARNED_PHRASES")
    spec~put(.Array~new, "EXEMPLARS")
    spec~put(priority, "PRIORITY")
    provenance = .Directory~new
    provenance~put("PROPOSED", "REVIEW_STATE")
    provenance~put("", "SOURCE")
    provenance~put("", "PRODUCER")
    spec~put(provenance, "PROVENANCE")
    referral = .Directory~new
    spec~put(referral, "REFERRAL")
    intentTable~put(spec, intentId)
    intentOrder~append(intentId)
  end
  else do
    spec = intentTable~at(intentId)
    if verbs \== "" then spec~put(self~mergeTerms(spec~at("VERBS"), verbs), "VERBS")
    if nouns \== "" then spec~put(self~mergeTerms(spec~at("NOUNS"), nouns), "NOUNS")
    if phrases \== "" then spec~put(self~mergeTerms(spec~at("PHRASES"), phrases), "PHRASES")
  end
  if phrases \== "" then do
    exemplars = spec~at("EXEMPLARS")
    exemplars~append(phrases)
  end
  modelDirty = 1
  return self

::method registerReferral
  expose intentTable
  use arg intentId, owner, targetKind, targetId, mode, language, application, responseOwner, responseProfile
  intentId = translate(strip(intentId))
  if intentTable~hasIndex(intentId) = 0 then raise syntax 93.900 array("Unknown intent:" intentId)
  if arg(5, "O") = 1 then mode = "ANY"
  if arg(6, "O") = 1 then language = "ANY"
  if arg(7, "O") = 1 then application = "ANY"
  if arg(8, "O") = 1 then responseOwner = ""
  if arg(9, "O") = 1 then responseProfile = ""
  ref = .Directory~new
  ref~put(owner, "OWNER")
  ref~put(targetKind, "TARGET_KIND")
  ref~put(targetId, "TARGET_ID")
  ctx = .Directory~new
  ctx~put(self~normalizeContextValue(mode), "MODE")
  ctx~put(self~normalizeContextValue(language), "LANGUAGE")
  ctx~put(self~normalizeContextValue(application), "APPLICATION")
  ref~put(ctx, "CONTEXT")
  ref~put(responseOwner, "RESPONSE_OWNER")
  ref~put(responseProfile, "RESPONSE_PROFILE")
  intentTable~at(intentId)~put(ref, "REFERRAL")
  return self

::method setIntentProvenance
  expose intentTable
  use arg intentId, source, producer, reviewState
  intentId = translate(strip(intentId))
  if intentTable~hasIndex(intentId) = 0 then raise syntax 93.900 array("Unknown intent:" intentId)
  if arg(4, "O") = 1 then reviewState = "PROPOSED"
  reviewState = translate(strip(reviewState))
  provenance = .Directory~new
  provenance~put(strip(source), "SOURCE")
  provenance~put(strip(producer), "PRODUCER")
  provenance~put(reviewState, "REVIEW_STATE")
  intentTable~at(intentId)~put(provenance, "PROVENANCE")
  return self

::method addApprovedPhrase
  expose intentTable modelDirty
  use arg intentId, phraseTerms
  intentId = translate(strip(intentId))
  if intentTable~hasIndex(intentId) = 0 then raise syntax 93.900 array("Unknown intent:" intentId)
  normalized = self~normalizeTerms(phraseTerms)
  if normalized == "" then return self
  spec = intentTable~at(intentId)
  learned = spec~at("LEARNED_PHRASES")
  if learned == "" then spec~put(normalized, "LEARNED_PHRASES")
  else spec~put(learned || "|" || normalized, "LEARNED_PHRASES")
  exemplars = spec~at("EXEMPLARS")
  exemplars~append(phraseTerms)
  /* Each learned surface form is preserved as one path.  The earlier code
     collapsed several phrases into one token stream, making an exact alias
     impossible to accept after more than one form had been registered. */
  if modelDirty = 0 then self~addPath(normalized, intentId)
  return self

::method registerSlot
  return self

::method intentIds
  expose intentOrder
  return intentOrder~copy

::method conceptIds
  expose conceptOrder
  return conceptOrder~copy

::method examine
  use arg text
  return self~route(text)

::method parse
  use arg text
  return self~route(text)

/* ------------------------------------------------------------ automaton construction */

::method buildModel
  expose intentTable intentOrder transitions finals stateCount modelDirty
  if modelDirty = 0 then return
  transitions = .Directory~new
  finals = .Directory~new
  stateCount = 1
  do i = 1 to intentOrder~items
    id = intentOrder[i]
    spec = intentTable~at(id)
    exemplars = spec~at("EXEMPLARS")
    do exemplarIndex = 1 to exemplars~items
      self~addPath(self~normalizeTerms(exemplars~at(exemplarIndex)), id)
    end
    /* Distinctive single terms also become single-token paths. */
    self~addTermPaths(spec~at("VERBS"), id)
    self~addTermPaths(spec~at("NOUNS"), id)
  end
  modelDirty = 0

::method addPathsFrom
  use arg termString, intentId
  if termString == "" | termString == .nil then return
  s = translate(termString, " ", "|")
  /* multi-word phrase as one path */
  if words(s) > 1 then self~addPath(s, intentId)
  /* each individual token as a short path (if not broad) */
  do position = 1 to words(s)
    t = subword(s, position, 1)
    if t \== "" then if self~isBroad(t) = 0 then self~addPath(t, intentId)
  end

::method addTermPaths
  use arg termString, intentId
  if termString == "" | termString == .nil then return
  s = translate(termString, " ", "|")
  do position = 1 to words(s)
    t = subword(s, position, 1)
    if t \== "" then if self~isBroad(t) = 0 then self~addPath(t, intentId)
  end

::method addPath
  /* Walk / extend the trie for the space-or-pipe separated token sequence. */
  expose transitions finals stateCount
  use arg tokenString, intentId
  s = translate(tokenString, " ", "|")
  state = 0
  do position = 1 to words(s)
    tok = subword(s, position, 1)
    if tok == "" then iterate
    key = state || "|" || tok
    if transitions~hasIndex(key) = 1 then do
      state = transitions~at(key)
    end
    else do
      newState = stateCount
      stateCount = stateCount + 1
      transitions~put(newState, key)
      state = newState
    end
  end
  /* Mark final state → intent (first registration wins on conflict). */
  if finals~hasIndex(state) = 0 then finals~put(intentId, state)

::method isBroad
  use arg term
  broad = " TOKEN TOKENS ACCOUNT DATA SUPPORT HELP API PRICE COST USAGE BILL BILLING "
  if pos(" " || term || " ", broad) > 0 then return 1
  return 0

/* ------------------------------------------------------------ routing (pure state walk) */

::method route
  expose intentTable transitions finals modelDirty
  use arg text
  self~buildModel

  tokens = self~tokensOf(text)
  content = self~contentTokens(tokens)

  /* Walk the automaton with the content tokens. */
  state = 0
  path = "0"
  accepted = 1
  do i = 1 to content~items
    tok = content~at(i)
    key = state || "|" || tok
    if transitions~hasIndex(key) = 0 then do
      accepted = 0
      leave
    end
    state = transitions~at(key)
    path = path || "->" || state
  end

  routeRecord = .Directory~new
  routeRecord~put("symbolic.nlp.route/0.1", "SCHEMA")
  routeRecord~put("FINITE_STATE_TRANSDUCER", "ENGINE")
  routeRecord~put(text, "TEXT")
  routeRecord~put(.Array~new, "CANDIDATES")
  routeRecord~put(.Directory~new, "ACTIVE_CONTEXT")
  routeRecord~put(0, "ROUTABLE")
  routeRecord~put(.Directory~new, "TASK")
  routeRecord~put(.Directory~new, "PRESENTATION")
  routeRecord~put(.Directory~new, "BLOCKED_TASK")

  if accepted = 0 | finals~hasIndex(state) = 0 then do
    routeRecord~put("UNKNOWN", "STATUS")
    routeRecord~put("NONE", "REFERRAL_STATUS")
    routeRecord~put("", "INTENT")
    routeRecord~put("POSITIVE", "POLARITY")
    routeRecord~put(0, "COMPLETE")
    routeRecord~put(.Array~new, "NEEDS")
    routeRecord~put(.Directory~new, "ARGUMENTS")
    routeRecord~put(.Directory~new, "SEMANTIC")
    routeRecord~put("fst: no accepting path (" || path || ")", "EVIDENCE")
    routeRecord~put(0, "SCORE")
    routeRecord~put(0, "MARGIN")
    return routeRecord
  end

  winner = finals~at(state)

  /* Approval check. */
  if intentTable~hasIndex(winner) = 0 then do
    routeRecord~put("UNKNOWN", "STATUS")
    routeRecord~put("NONE", "REFERRAL_STATUS")
    routeRecord~put("", "INTENT")
    routeRecord~put("fst: unknown intent", "EVIDENCE")
    routeRecord~put(0, "SCORE")
    routeRecord~put(0, "MARGIN")
    return routeRecord
  end
  spec = intentTable~at(winner)
  provenance = spec~at("PROVENANCE")
  if provenance~at("REVIEW_STATE") \== "APPROVED" then do
    routeRecord~put("UNKNOWN", "STATUS")
    routeRecord~put("NONE", "REFERRAL_STATUS")
    routeRecord~put("", "INTENT")
    routeRecord~put("fst: intent not APPROVED", "EVIDENCE")
    routeRecord~put(0, "SCORE")
    routeRecord~put(0, "MARGIN")
    return routeRecord
  end

  evidence = "FST path=" || path || " final=" || state
  routeRecord~put("MATCHED", "STATUS")
  routeRecord~put(winner, "INTENT")
  routeRecord~put(100, "SCORE")
  routeRecord~put(100, "MARGIN")
  routeRecord~put(evidence, "EVIDENCE")
  routeRecord~put("POSITIVE", "POLARITY")
  routeRecord~put(1, "COMPLETE")
  routeRecord~put(.Array~new, "NEEDS")
  routeRecord~put(.Directory~new, "ARGUMENTS")
  s = .Directory~new
  s~put("finitestate.nlp.semantic/0.1", "SCHEMA")
  s~put("FINITE_STATE_TRANSDUCER", "ENGINE")
  s~put(winner, "INTENT")
  s~put(evidence, "EVIDENCE")
  s~put(.Array~new, "RELATIONS")
  s~put("FST(" || winner || ")", "FORM")
  routeRecord~put(s, "SEMANTIC")

  ref = spec~at("REFERRAL")
  if ref \== .nil then if ref~items > 0 then do
    routeRecord~put("READY", "REFERRAL_STATUS")
    task = .Directory~new
    task~put(ref~at("OWNER"), "OWNER")
    task~put(ref~at("TARGET_KIND"), "TARGET_KIND")
    task~put(ref~at("TARGET_ID"), "TARGET_ID")
    task~put(ref~at("CONTEXT"), "CONTEXT")
    task~put(.Directory~new, "ARGUMENTS")
    task~put("POSITIVE", "POLARITY")
    task~put(1, "COMPLETE")
    task~put(.Array~new, "NEEDS")
    routeRecord~put(task, "TASK")
    routeRecord~put(.Directory~new, "PRESENTATION")
    routeRecord~put(1, "ROUTABLE")
  end
  else do
    routeRecord~put("NONE", "REFERRAL_STATUS")
  end
  return routeRecord

/* ------------------------------------------------------------ utilities */

::method tokensOf
  use arg text
  tokens = .Array~new
  do position = 1 to words(text)
    raw = subword(text, position, 1)
    clean = self~cleanWord(raw)
    if clean == "" then iterate
    t = .Directory~new
    t~put(raw, "RAW")
    t~put(clean, "CLEAN")
    t~put(self~stem(clean), "CANONICAL")
    tokens~append(t)
  end
  return tokens

::method contentTokens
  use arg tokens
  out = .Array~new
  do i = 1 to tokens~items
    term = tokens~at(i)~at("CANONICAL")
    if term == "" then iterate
    if self~isStopword(term) = 1 then iterate
    out~append(term)
  end
  if out~items = 0 then do i = 1 to tokens~items
    term = tokens~at(i)~at("CANONICAL")
    if term \== "" then out~append(term)
  end
  return out

::method cleanWord
  use arg word
  upper = translate(word)
  clean = ""
  do i = 1 to length(upper)
    ch = substr(upper, i, 1)
    if pos(ch, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_") > 0 then clean = clean || ch
  end
  return clean

::method stem
  use arg word
  w = translate(strip(word))
  if w == "" then return ""
  l = length(w)
  if l > 5 then if right(w, 3) == "IES" then w = left(w, l - 3) || "Y"
  else if l > 5 & right(w, 3) == "ING" then w = left(w, l - 3)
  else if l > 5 & right(w, 2) == "ED" then w = left(w, l - 2)
  else if l > 5 & right(w, 2) == "ES" then w = left(w, l - 2)
  else if l > 4 & right(w, 1) == "S" & right(w, 2) \== "SS" then w = left(w, l - 1)
  if length(w) > 4 then if right(w, 1) == "E" then w = left(w, length(w) - 1)
  return w

::method isStopword
  use arg term
  stop = " A AN THE ME MY I YOU YOUR OUR WE US PLEASE CAN COULD WOULD SHOULD DO DOES DID IS ARE AM TO OF FOR IN ON WITH AND OR IT THIS THAT BE BEEN ABOUT HOW WHAT WHY WHICH WHEN WHERE WHO MORE MUCH MANY HAVE HAS HAD FROM AS AT BY INTO THAN THEN JUST STILL REALLY VERY FULL EXACT WILL IF SO BUT "
  if pos(" " || term || " ", stop) > 0 then return 1
  return 0

::method normalizeTerms
  use arg terms
  if terms == .nil then return ""
  s = translate(terms, " ", "|")
  out = ""
  do position = 1 to words(s)
    t = self~stem(self~cleanWord(subword(s, position, 1)))
    if t == "" then iterate
    if out == "" then out = t
    else out = out || "|" || t
  end
  return out

::method normalizeConceptIds
  use arg ids
  if ids == .nil then return ""
  s = translate(ids, " ", "|")
  out = ""
  do position = 1 to words(s)
    t = translate(strip(subword(s, position, 1)))
    if t == "" then iterate
    if out == "" then out = t
    else out = out || "|" || t
  end
  return out

::method expandConceptTerms
  expose conceptTable
  use arg conceptIds, role
  if conceptIds == "" then return ""
  out = ""
  s = translate(conceptIds, " ", "|")
  do position = 1 to words(s)
    cid = translate(strip(subword(s, position, 1)))
    if conceptTable~hasIndex(cid) = 0 then iterate
    terms = conceptTable~at(cid)~at("TERMS")
    if terms == "" then iterate
    if out == "" then out = terms
    else out = out || "|" || terms
  end
  return out

::method mergeTerms
  use arg old, new
  if old == "" then return self~normalizeTerms(new)
  if new == "" then return old
  return old || "|" || self~normalizeTerms(new)

::method normalizeContextValue
  use arg v
  if v == .nil | v == "" then return "ANY"
  return translate(strip(v))
