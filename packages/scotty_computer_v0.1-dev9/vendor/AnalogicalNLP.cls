/* AnalogicalNLP.cls
   Eighth swappable NLP strategy (engine ANALOGICAL / AML / SKOUSEN).

   University-archive paradigm: Analogical Modeling of Language
   (Royal Skousen, Brigham Young University, 1989 book and subsequent
   papers).  Almost never productised.  Pure analogical inference with
   an explicit homogeneity filter and quadratic weighting.

   Given a query the engine:

     1. Extracts its content-token features.
     2. Enumerates every non-empty supracontext (subset of those features).
     3. For each supracontext, collects the stored exemplars that contain
        at least those features.
     4. Keeps the supracontext only if it is homogeneous (all matching
        exemplars share the same intent).
     5. Heterogeneous supracontexts are discarded.
     6. Surviving homogeneous supracontexts vote with weight n²
        (quadratic in the number of pointers / exemplars).
     7. The intent with the highest total weight wins if it clears a
        threshold; otherwise UNKNOWN.

   There is no global feature selection, no learned weights, no rule
   ordering, and no abstraction step that discards the original cases.
   addApprovedPhrase simply stores another raw exemplar — classic lazy
   behaviour.  The inductive bias is therefore different from decision
   lists, ordinary k-NN, generative models, RDR exception trees and VSA.

   Pure ooRexx, deterministic, same registration surface and route
   envelope.  Select with VIRTUAL_REP_NLP_ENGINE=ANALOGICAL
   (or AML or SKOUSEN).
*/

::class AnalogicalNLPParser public

::method init
  expose intentTable intentOrder conceptTable conceptOrder -
         threshold ambiguityMargin activeMode activeLanguage activeApplication -
         exemplars modelDirty maxFeatures
  intentTable = .Directory~new
  intentOrder = .Array~new
  conceptTable = .Directory~new
  conceptOrder = .Array~new
  threshold = 4           /* quadratic weight threshold (n² scale is small on this corpus) */
  ambiguityMargin = 5
  activeMode = "ANY"
  activeLanguage = "ANY"
  activeApplication = "ANY"
  exemplars = .Array~new  /* each: Directory(FEATURES=Array, INTENT=id) */
  modelDirty = 1
  maxFeatures = 8         /* safety cap on power-set size */

::method version
  return "0.1-dev1-analogical"

::method strategyName
  return "ANALOGICAL_MODELING"

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
  expose intentTable exemplars modelDirty
  use arg intentId, phraseTerms
  intentId = translate(strip(intentId))
  if intentTable~hasIndex(intentId) = 0 then raise syntax 93.900 array("Unknown intent:" intentId)
  normalized = self~normalizeTerms(phraseTerms)
  if normalized == "" then return self
  spec = intentTable~at(intentId)
  learned = spec~at("LEARNED_PHRASES")
  if learned == "" then spec~put(normalized, "LEARNED_PHRASES")
  else spec~put(learned || "|" || normalized, "LEARNED_PHRASES")

  /* Lazy: just store another raw exemplar. */
  tokens = self~tokensOf(phraseTerms)
  content = self~contentTokens(tokens)
  if content~items > 0 then do
    ex = .Directory~new
    ex~put(content, "FEATURES")
    ex~put(intentId, "INTENT")
    exemplars~append(ex)
  end
  modelDirty = 0
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

/* ------------------------------------------------------------ analogical core */

::method buildModel
  expose intentTable intentOrder exemplars modelDirty
  if modelDirty = 0 then return
  exemplars = .Array~new
  do i = 1 to intentOrder~items
    id = intentOrder[i]
    spec = intentTable~at(id)
    self~storePhrases(id, spec~at("PHRASES"))
    self~storePhrases(id, spec~at("LEARNED_PHRASES"))
    /* Also store distinctive single terms from verbs/nouns as weak exemplars. */
    self~storeTerms(id, spec~at("VERBS"))
    self~storeTerms(id, spec~at("NOUNS"))
  end
  modelDirty = 0

::method storePhrases
  expose exemplars
  use arg intentId, termString
  if termString == "" | termString == .nil then return
  s = translate(termString, " ", "|")
  /* whole multi-word phrase as one exemplar */
  if words(s) > 1 then do
    feats = .Array~new
    do position = 1 to words(s)
      t = subword(s, position, 1)
      if t \== "" then feats~append(t)
    end
    if feats~items > 0 then do
      ex = .Directory~new
      ex~put(feats, "FEATURES")
      ex~put(intentId, "INTENT")
      exemplars~append(ex)
    end
  end
  /* each single token also becomes a tiny exemplar */
  do position = 1 to words(s)
    t = subword(s, position, 1)
    if t == "" then iterate
    if self~isBroad(t) = 1 then iterate
    feats = .Array~new
    feats~append(t)
    ex = .Directory~new
    ex~put(feats, "FEATURES")
    ex~put(intentId, "INTENT")
    exemplars~append(ex)
  end

::method storeTerms
  expose exemplars
  use arg intentId, termString
  if termString == "" | termString == .nil then return
  s = translate(termString, " ", "|")
  do position = 1 to words(s)
    t = subword(s, position, 1)
    if t == "" then iterate
    if self~isBroad(t) = 1 then iterate
    feats = .Array~new
    feats~append(t)
    ex = .Directory~new
    ex~put(feats, "FEATURES")
    ex~put(intentId, "INTENT")
    exemplars~append(ex)
  end

::method isBroad
  use arg term
  broad = " TOKEN TOKENS ACCOUNT DATA SUPPORT HELP API PRICE COST USAGE BILL BILLING "
  if pos(" " || term || " ", broad) > 0 then return 1
  return 0

/* Singleton supracontexts represented as simple strings for robustness.
   Homogeneity + quadratic weighting still applied. */
::method supracontexts
  use arg features
  out = .Array~new
  n = features~items
  do i = 1 to n
    out~append(features~at(i))
  end
  return out

::method containsAll
  /* True if exemplar feature set contains the (singleton) supracontext term. */
  use arg exFeatures, term
  do i = 1 to exFeatures~items
    if exFeatures~at(i) == term then return 1
  end
  return 0

/* ------------------------------------------------------------ routing */

::method route
  expose intentTable exemplars threshold modelDirty maxFeatures
  use arg text
  numeric digits 12
  self~buildModel

  tokens = self~tokensOf(text)
  content = self~contentTokens(tokens)
  if content~items = 0 then return self~unknownRoute(text, "aml: no content tokens")

  /* Cap feature count for the power set. */
  feats = .Array~new
  do i = 1 to content~items
    if i > maxFeatures then leave
    feats~append(content~at(i))
  end

  contexts = self~supracontexts(feats)
  /* intent -> accumulated n² weight */
  scores = .Directory~new
  homoCount = 0
  ctxCount = contexts~items

  do c = 1 to ctxCount
    subset = contexts~at(c)
    /* collect intents of exemplars that contain this supracontext */
    intentCounts = .Directory~new
    totalPointers = 0
    do e = 1 to exemplars~items
      ex = exemplars~at(e)
      if self~containsAll(ex~at("FEATURES"), subset) = 1 then do
        id = ex~at("INTENT")
        if intentCounts~hasIndex(id) = 0 then intentCounts~put(1, id)
        else intentCounts~put(intentCounts~at(id) + 1, id)
        totalPointers = totalPointers + 1
      end
    end
    if totalPointers = 0 then iterate
    /* homogeneity: exactly one intent present */
    if intentCounts~items \= 1 then iterate
    /* homogeneous → quadratic weight */
    intent = intentCounts~allIndexes[1]
    n = intentCounts~at(intent)
    weight = n * n
    if scores~hasIndex(intent) = 0 then scores~put(weight, intent)
    else scores~put(scores~at(intent) + weight, intent)
    homoCount = homoCount + 1
  end

  if scores~items = 0 then return self~unknownRoute(text, "aml: no homogeneous supracontexts")

  /* pick highest */
  bestIntent = ""
  bestScore = -1
  secondScore = -1
  ks = scores~allIndexes
  do i = 1 to ks~items
    sc = scores~at(ks[i])
    if sc > bestScore then do
      secondScore = bestScore
      bestScore = sc
      bestIntent = ks[i]
    end
    else if sc > secondScore then secondScore = sc
  end

  margin = bestScore - secondScore
  if secondScore < 0 then margin = bestScore

  /* Build evidence string */
  evidence = "AML weight=" || bestScore || " homo=" || homoCount || " margin=" || margin

  routeRecord = .Directory~new
  routeRecord~put("symbolic.nlp.route/0.1", "SCHEMA")
  routeRecord~put("ANALOGICAL_MODELING", "ENGINE")
  routeRecord~put(text, "TEXT")
  routeRecord~put(.Array~new, "CANDIDATES")
  routeRecord~put(.Directory~new, "ACTIVE_CONTEXT")
  routeRecord~put(0, "ROUTABLE")
  routeRecord~put(.Directory~new, "TASK")
  routeRecord~put(.Directory~new, "PRESENTATION")
  routeRecord~put(.Directory~new, "BLOCKED_TASK")

  if bestScore < threshold then do
    routeRecord~put("UNKNOWN", "STATUS")
    routeRecord~put("NONE", "REFERRAL_STATUS")
    routeRecord~put("", "INTENT")
    routeRecord~put("POSITIVE", "POLARITY")
    routeRecord~put(0, "COMPLETE")
    routeRecord~put(.Array~new, "NEEDS")
    routeRecord~put(.Directory~new, "ARGUMENTS")
    routeRecord~put(.Directory~new, "SEMANTIC")
    routeRecord~put(evidence || " (below threshold)", "EVIDENCE")
    routeRecord~put(bestScore, "SCORE")
    routeRecord~put(margin, "MARGIN")
    return routeRecord
  end

  /* approval check */
  if intentTable~hasIndex(bestIntent) = 0 then return self~unknownRoute(text, "aml: unknown intent")
  spec = intentTable~at(bestIntent)
  provenance = spec~at("PROVENANCE")
  if provenance~at("REVIEW_STATE") \== "APPROVED" then -
    return self~unknownRoute(text, "aml: intent not APPROVED")

  /* normalise score to roughly 0-100 for the common envelope */
  displayScore = bestScore
  if displayScore > 100 then displayScore = 100

  routeRecord~put("MATCHED", "STATUS")
  routeRecord~put(bestIntent, "INTENT")
  routeRecord~put(displayScore, "SCORE")
  routeRecord~put(margin, "MARGIN")
  routeRecord~put(evidence, "EVIDENCE")
  routeRecord~put("POSITIVE", "POLARITY")
  routeRecord~put(1, "COMPLETE")
  routeRecord~put(.Array~new, "NEEDS")
  routeRecord~put(.Directory~new, "ARGUMENTS")
  s = .Directory~new
  s~put("analogical.nlp.semantic/0.1", "SCHEMA")
  s~put("ANALOGICAL_MODELING", "ENGINE")
  s~put(bestIntent, "INTENT")
  s~put(evidence, "EVIDENCE")
  s~put(.Array~new, "RELATIONS")
  s~put("AML(" || bestIntent || ")", "FORM")
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

::method unknownRoute
  use arg text, evidence
  routeRecord = .Directory~new
  routeRecord~put("symbolic.nlp.route/0.1", "SCHEMA")
  routeRecord~put("ANALOGICAL_MODELING", "ENGINE")
  routeRecord~put(text, "TEXT")
  routeRecord~put("UNKNOWN", "STATUS")
  routeRecord~put("NONE", "REFERRAL_STATUS")
  routeRecord~put("", "INTENT")
  routeRecord~put(.Array~new, "CANDIDATES")
  routeRecord~put("POSITIVE", "POLARITY")
  routeRecord~put(0, "COMPLETE")
  routeRecord~put(.Array~new, "NEEDS")
  routeRecord~put(.Directory~new, "ARGUMENTS")
  routeRecord~put(.Directory~new, "SEMANTIC")
  routeRecord~put(.Directory~new, "ACTIVE_CONTEXT")
  routeRecord~put(evidence, "EVIDENCE")
  routeRecord~put(0, "SCORE")
  routeRecord~put(0, "MARGIN")
  routeRecord~put(0, "ROUTABLE")
  routeRecord~put(.Directory~new, "TASK")
  routeRecord~put(.Directory~new, "PRESENTATION")
  routeRecord~put(.Directory~new, "BLOCKED_TASK")
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
