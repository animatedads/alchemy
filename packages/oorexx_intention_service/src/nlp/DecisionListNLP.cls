/* DecisionListNLP.cls
   Sixth swappable NLP strategy (engine DECISION / DL / YAROWSKY).

   University-archive paradigm: ordered Decision Lists
   (Rivest 1987; Yarowsky 1994 word-sense disambiguation decision lists;
   classic high-precision rule lists used throughout 1990s statistical NLP).

   From the registered concepts, phrases and learned phrases we generate
   a set of atomic tests:

     CONTAINS:term
     BIGRAM:term1_term2
     EXACT:full-phrase

   Each test is scored by a simple purity × coverage proxy:

     score = precision * log(1 + coverage)

   where precision is the fraction of intents that own the test that are
   the dominant intent, and coverage is how many times the test appears.
   Tests are sorted into a single ordered list (highest score first).
   At classification time the first matching test wins its intent.
   Exact learned / approved phrases are forced to the very top of the list
   so the existing teaching contract is preserved.

   Completely different inductive bias from generative LMs, contrastive
   exemplars, symbolic grammar scoring, ensembles and hyperdimensional
   vectors: pure ordered high-precision rules.  Highly interpretable
   (the winning rule is the explanation).

   Pure ooRexx, deterministic after ranking.  Same registration surface
   and route envelope.  Select with VIRTUAL_REP_NLP_ENGINE=DECISION
   (or DL or YAROWSKY).
*/

::class DecisionListNLPParser public

::method init
  expose intentTable intentOrder conceptTable conceptOrder -
         threshold ambiguityMargin activeMode activeLanguage activeApplication -
         ruleList modelDirty
  intentTable = .Directory~new
  intentOrder = .Array~new
  conceptTable = .Directory~new
  conceptOrder = .Array~new
  threshold = 50
  ambiguityMargin = 5
  activeMode = "ANY"
  activeLanguage = "ANY"
  activeApplication = "ANY"
  ruleList = .Array~new
  modelDirty = 1

::method version
  return "0.1-dev1-decisionlist"

::method strategyName
  return "DECISION_LIST"

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
  modelDirty = 1
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

/* ------------------------------------------------------------ decision list construction */

::method buildModel
  expose intentTable intentOrder ruleList modelDirty
  if modelDirty = 0 then return
  /* Collect raw evidence: test -> Directory(intent -> count) */
  evidence = .Directory~new
  do i = 1 to intentOrder~items
    id = intentOrder[i]
    spec = intentTable~at(id)
    self~addEvidence(evidence, id, spec~at("VERBS"), "CONTAINS")
    self~addEvidence(evidence, id, spec~at("NOUNS"), "CONTAINS")
    self~addEvidence(evidence, id, spec~at("PHRASES"), "PHRASE")
    self~addEvidence(evidence, id, spec~at("LEARNED_PHRASES"), "LEARNED")
  end

  /* Score every test and build candidate rules. */
  candidates = .Array~new
  tests = evidence~allIndexes
  do t = 1 to tests~items
    test = tests[t]
    counts = evidence~at(test)
    total = 0
    bestIntent = ""
    bestCount = 0
    intents = counts~allIndexes
    do j = 1 to intents~items
      c = counts~at(intents[j])
      total = total + c
      if c > bestCount then do
        bestCount = c
        bestIntent = intents[j]
      end
    end
    if total = 0 then iterate
    precision = bestCount / total
    /* Prefer pure tests; require at least modest purity. */
    if precision < 0.6 then iterate
    coverage = total
    /* score = precision * log(1+coverage)  (simple proxy, pure arithmetic) */
    score = precision * self~approxLog(1 + coverage)
    /* Exact / learned phrases get a large priority boost so they sit at the top. */
    kind = left(test, pos(":", test) - 1)
    if kind == "LEARNED" then score = score + 50
    else if kind == "PHRASE" then score = score + 20
    rule = .Directory~new
    rule~put(test, "TEST")
    rule~put(bestIntent, "INTENT")
    rule~put(score, "SCORE")
    rule~put(precision, "PRECISION")
    rule~put(coverage, "COVERAGE")
    rule~put(kind, "KIND")
    candidates~append(rule)
  end

  /* Sort descending by score (simple insertion / selection for small N). */
  n = candidates~items
  do i = 1 to n - 1
    maxIdx = i
    do j = i + 1 to n
      if candidates[j]~at("SCORE") > candidates[maxIdx]~at("SCORE") then maxIdx = j
    end
    if maxIdx \= i then do
      tmp = candidates[i]
      candidates[i] = candidates[maxIdx]
      candidates[maxIdx] = tmp
    end
  end
  ruleList = candidates
  modelDirty = 0

::method addEvidence
  use arg evidence, intentId, termString, kind
  if termString == "" | termString == .nil then return
  s = translate(termString, " ", "|")
  prev = ""
  do position = 1 to words(s)
    t = subword(s, position, 1)
    if t == "" then iterate
    /* CONTAINS / PHRASE / LEARNED atom */
    key = kind || ":" || t
    self~bump(evidence, key, intentId)
    /* Bigrams for consecutive content terms (only for CONTAINS). */
    if kind == "CONTAINS" then if prev \== "" then do
      bkey = "BIGRAM:" || prev || "_" || t
      self~bump(evidence, bkey, intentId)
    end
    prev = t
  end
  /* Also treat multi-word phrases as EXACT tests when they contain spaces. */
  if (kind == "PHRASE" | kind == "LEARNED") then if words(s) > 1 then do
    exact = "EXACT:" || translate(s, "_", " ")
    self~bump(evidence, exact, intentId)
  end

::method bump
  use arg evidence, key, intentId
  if evidence~hasIndex(key) = 0 then evidence~put(.Directory~new, key)
  counts = evidence~at(key)
  if counts~hasIndex(intentId) = 0 then counts~put(1, intentId)
  else counts~put(counts~at(intentId) + 1, intentId)

::method approxLog
  /* Crude but monotonic log2 approximation for ranking only. */
  use arg x
  if x <= 1 then return 0
  n = 0
  v = x
  do while v >= 2
    v = v / 2
    n = n + 1
  end
  /* fractional part rough */
  return n + (v - 1)

/* ------------------------------------------------------------ routing */

::method route
  expose intentTable intentOrder ruleList threshold modelDirty
  use arg text
  numeric digits 12
  self~buildModel

  tokens = self~tokensOf(text)
  content = self~contentTokens(tokens)
  qset = .Directory~new
  do i = 1 to content~items
    qset~put(1, content[i])
  end
  qnorm = self~normalizeTerms(text)
  qexact = translate(qnorm, "_", "|")

  /* Walk the ordered decision list; first match wins. */
  winner = .nil
  winningRule = .nil
  do i = 1 to ruleList~items
    rule = ruleList[i]
    test = rule~at("TEST")
    kind = rule~at("KIND")
    matched = 0
    if kind == "CONTAINS" | kind == "PHRASE" | kind == "LEARNED" then do
      term = substr(test, pos(":", test) + 1)
      if qset~hasIndex(term) = 1 then matched = 1
    end
    else if kind == "BIGRAM" then do
      pair = substr(test, pos(":", test) + 1)
      parse var pair t1 "_" t2
      /* consecutive content tokens */
      do j = 1 to content~items - 1
        if content[j] == t1 then if content[j + 1] == t2 then do
          matched = 1
          leave
        end
      end
    end
    else if kind == "EXACT" then do
      phrase = substr(test, pos(":", test) + 1)
      if qexact == phrase then matched = 1
    end
    if matched = 1 then do
      winner = rule~at("INTENT")
      winningRule = rule
      leave
    end
  end

  routeRecord = .Directory~new
  routeRecord~put("symbolic.nlp.route/0.1", "SCHEMA")
  routeRecord~put("DECISION_LIST", "ENGINE")
  routeRecord~put(text, "TEXT")
  routeRecord~put(.Array~new, "CANDIDATES")
  routeRecord~put(.Directory~new, "ACTIVE_CONTEXT")
  routeRecord~put(0, "ROUTABLE")
  routeRecord~put(.Directory~new, "TASK")
  routeRecord~put(.Directory~new, "PRESENTATION")
  routeRecord~put(.Directory~new, "BLOCKED_TASK")

  if winner == .nil then do
    routeRecord~put("UNKNOWN", "STATUS")
    routeRecord~put("NONE", "REFERRAL_STATUS")
    routeRecord~put("", "INTENT")
    routeRecord~put("POSITIVE", "POLARITY")
    routeRecord~put(0, "COMPLETE")
    routeRecord~put(.Array~new, "NEEDS")
    routeRecord~put(.Directory~new, "ARGUMENTS")
    routeRecord~put(.Directory~new, "SEMANTIC")
    routeRecord~put("dl: no rule matched", "EVIDENCE")
    routeRecord~put(0, "SCORE")
    routeRecord~put(0, "MARGIN")
    return routeRecord
  end

  /* Check registration / context. */
  spec = intentTable~at(winner)
  provenance = spec~at("PROVENANCE")
  reviewState = provenance~at("REVIEW_STATE")
  if reviewState \== "APPROVED" then do
    routeRecord~put("UNKNOWN", "STATUS")
    routeRecord~put("NONE", "REFERRAL_STATUS")
    routeRecord~put("", "INTENT")
    routeRecord~put("dl: intent not APPROVED", "EVIDENCE")
    routeRecord~put(0, "SCORE")
    routeRecord~put(0, "MARGIN")
    return routeRecord
  end

  score = winningRule~at("PRECISION") * 100
  if score < threshold then do
    routeRecord~put("UNKNOWN", "STATUS")
    routeRecord~put("NONE", "REFERRAL_STATUS")
    routeRecord~put("", "INTENT")
    routeRecord~put("dl: below threshold rule=" || winningRule~at("TEST"), "EVIDENCE")
    routeRecord~put(score, "SCORE")
    routeRecord~put(0, "MARGIN")
    return routeRecord
  end

  evidence = "DL rule=" || winningRule~at("TEST") || " prec=" || format(winningRule~at("PRECISION"), , 2) || " cov=" || winningRule~at("COVERAGE")
  routeRecord~put("MATCHED", "STATUS")
  routeRecord~put(winner, "INTENT")
  routeRecord~put(score, "SCORE")
  routeRecord~put(100, "MARGIN")
  routeRecord~put(evidence, "EVIDENCE")
  routeRecord~put("POSITIVE", "POLARITY")
  routeRecord~put(1, "COMPLETE")
  routeRecord~put(.Array~new, "NEEDS")
  routeRecord~put(.Directory~new, "ARGUMENTS")
  s = .Directory~new
  s~put("decisionlist.nlp.semantic/0.1", "SCHEMA")
  s~put("DECISION_LIST", "ENGINE")
  s~put(winner, "INTENT")
  s~put(evidence, "EVIDENCE")
  s~put(.Array~new, "RELATIONS")
  s~put("DL(" || winner || ")", "FORM")
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

/* ------------------------------------------------------------ utilities (shared style) */

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
    term = tokens[i]~at("CANONICAL")
    if term == "" then iterate
    if self~isStopword(term) = 1 then iterate
    out~append(term)
  end
  if out~items = 0 then do i = 1 to tokens~items
    term = tokens[i]~at("CANONICAL")
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
