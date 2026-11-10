/* HyperdimensionalNLP.cls
   Fifth swappable NLP strategy (engine HYPER / VSA / HDC).

   University-archive paradigm: Vector Symbolic Architectures /
   Hyperdimensional Computing (Kanerva Sparse Distributed Memory,
   Plate Holographic Reduced Representations, Gayler, early 1990s–2000s).

   Concepts, terms and intents are represented as high-dimensional binary
   vectors (default D=512).  Composition uses the classic operations:

     bind(a, b)   = element-wise XOR
     bundle(a, b) = element-wise majority (sum then threshold)
     similarity   = 1 - Hamming(a, b) / D

   Each registered term receives a deterministic random vector (seeded by
   a simple hash of the term).  An intent prototype is the bundle of the
   vectors of its verbs, nouns and phrase tokens.  A query is the bundle
   of its content-word vectors.  Exact approved / learned phrases receive
   an additional fixed similarity bonus, preserving the existing teaching
   contract.

   This is deliberately a different inductive bias from the generative LM,
   contrastive exemplar and symbolic grammar engines already in the panel.
   It naturally supports accumulated multi-turn state later (bind tone,
   bind polarity, bundle history) without growing a prompt.

   Pure ooRexx, no native math libraries beyond ordinary arithmetic.
   Deterministic.  Same registration surface and route envelope.
   Select with VIRTUAL_REP_NLP_ENGINE=HYPER (or VSA or HDC).
*/

::class HyperdimensionalNLPParser public

::method init
  expose intentTable intentOrder conceptTable conceptOrder -
         threshold ambiguityMargin activeMode activeLanguage activeApplication -
         dim vectors prototypes modelDirty seedBase
  intentTable = .Directory~new
  intentOrder = .Array~new
  conceptTable = .Directory~new
  conceptOrder = .Array~new
  threshold = 55          /* similarity percent */
  ambiguityMargin = 8
  activeMode = "ANY"
  activeLanguage = "ANY"
  activeApplication = "ANY"
  dim = 512               /* hypervector dimensionality */
  vectors = .Directory~new
  prototypes = .Directory~new
  modelDirty = 1
  seedBase = 2654435769   /* golden-ratio constant for mixing (0x9E3779B9) */

::method version
  return "0.1-dev1-hyperdimensional"

::method strategyName
  return "HYPERDIMENSIONAL_VSA"

::method configure
  expose threshold ambiguityMargin
  use arg newThreshold, newAmbiguityMargin
  if arg(1, "O") = 0 then threshold = newThreshold
  if arg(2, "O") = 0 then ambiguityMargin = newAmbiguityMargin
  return self

::method setDimension
  expose dim modelDirty vectors prototypes
  use arg d
  if arg(1, "O") = 0 then do
    dim = d
    modelDirty = 1
    vectors = .Directory~new
    prototypes = .Directory~new
  end
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
  /* Accepted for surface compatibility; slots are not used by VSA matching. */
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

/* ------------------------------------------------------------ core VSA */

::method buildModel
  expose intentTable intentOrder modelDirty prototypes vectors
  if modelDirty = 0 then return
  prototypes = .Directory~new
  do i = 1 to intentOrder~items
    id = intentOrder[i]
    spec = intentTable~at(id)
    /* Collect every atomic term that characterises this intent. */
    terms = .Array~new
    self~collectTerms(spec~at("VERBS"), terms)
    self~collectTerms(spec~at("NOUNS"), terms)
    self~collectTerms(spec~at("PHRASES"), terms)
    self~collectTerms(spec~at("LEARNED_PHRASES"), terms)
    /* Bundle their random vectors into a prototype. */
    proto = self~zeroVector
    do j = 1 to terms~items
      v = self~vectorOf(terms[j])
      proto = self~bundle(proto, v)
    end
    prototypes~put(proto, id)
  end
  modelDirty = 0

::method collectTerms
  use arg termString, outArray
  if termString == "" | termString == .nil then return
  /* termString is pipe-separated or space-separated normalised tokens */
  s = translate(termString, " ", "|")
  do position = 1 to words(s)
    t = subword(s, position, 1)
    if t \== "" then outArray~append(t)
  end

::method vectorOf
  expose vectors dim seedBase
  use arg term
  numeric digits 12
  term = translate(strip(term))
  if term == "" then return self~zeroVector
  if vectors~hasIndex(term) = 1 then return vectors~at(term)
  /* Deterministic random binary vector seeded by a mix of the term hash. */
  h = self~hashString(term)
  v = .Array~new(dim)
  do i = 1 to dim
    /* Simple LCG step, keep in positive 31-bit range */
    h = h * 1664525 + 1013904223
    h = h // 2147483647
    if h < 0 then h = -h
    bit = h // 2
    v[i] = bit
  end
  vectors~put(v, term)
  return v

::method zeroVector
  expose dim
  v = .Array~new(dim)
  do i = 1 to dim
    v[i] = 0
  end
  return v

::method bundle
  /* Element-wise majority: sum then threshold at 1 (for two vectors this is OR-ish;
     for many it becomes true majority).  For simplicity and speed we use
     element-wise max (logical OR) which is a standard sparse bundling approx. */
  expose dim
  use arg a, b
  out = .Array~new(dim)
  do i = 1 to dim
    if a[i] + b[i] >= 1 then out[i] = 1
    else out[i] = 0
  end
  return out

::method similarity
  /* Normalised Hamming similarity: 1 - (Hamming / D) expressed as percent. */
  expose dim
  use arg a, b
  if a == .nil | b == .nil then return 0
  dist = 0
  do i = 1 to dim
    if a[i] \= b[i] then dist = dist + 1
  end
  return ((dim - dist) / dim) * 100

::method hashString
  expose seedBase
  use arg s
  numeric digits 12
  h = seedBase
  do i = 1 to length(s)
    c = c2d(substr(s, i, 1))
    h = h + c * (i + 17)
    h = h // 2147483647
  end
  if h < 0 then h = -h
  return h

/* ------------------------------------------------------------ routing */

::method route
  expose intentTable intentOrder threshold ambiguityMargin prototypes modelDirty
  use arg text
  numeric digits 12
  self~buildModel

  tokens = self~tokensOf(text)
  content = self~contentTokens(tokens)
  query = self~zeroVector
  do i = 1 to content~items
    query = self~bundle(query, self~vectorOf(content[i]))
  end

  /* Exact / contained phrase bonus. */
  phraseBonus = .Directory~new
  do i = 1 to intentOrder~items
    id = intentOrder[i]
    b = self~phraseBonus(id, content, text)
    phraseBonus~put(b, id)
  end

  candidates = .Array~new
  bestAllowed = .nil
  secondAllowed = .nil
  bestContextBlocked = .nil
  bestRegistryBlocked = .nil

  do i = 1 to intentOrder~items
    id = intentOrder[i]
    spec = intentTable~at(id)
    proto = prototypes~at(id)
    sim = self~similarity(query, proto)
    bonus = phraseBonus~at(id)
    if bonus = .nil then bonus = 0
    /* Blend: base similarity + scaled phrase bonus (bonus is already in percent-ish units). */
    cscore = sim + bonus
    if cscore > 100 then cscore = 100

    candidate = self~makeCandidate(spec, cscore, sim, bonus)
    candidates~append(candidate)

    if candidate~at("REGISTRATION_ACTIVE") = 0 then do
      if bestRegistryBlocked == .nil then bestRegistryBlocked = candidate
      else if self~candidateBetter(candidate, bestRegistryBlocked) = 1 then bestRegistryBlocked = candidate
      iterate
    end
    if candidate~at("CONTEXT_ALLOWED") = 0 then do
      if bestContextBlocked == .nil then bestContextBlocked = candidate
      else if self~candidateBetter(candidate, bestContextBlocked) = 1 then bestContextBlocked = candidate
      iterate
    end
    if bestAllowed == .nil then bestAllowed = candidate
    else if self~candidateBetter(candidate, bestAllowed) = 1 then do
      secondAllowed = bestAllowed
      bestAllowed = candidate
    end
    else do
      if secondAllowed == .nil then secondAllowed = candidate
      else if self~candidateBetter(candidate, secondAllowed) = 1 then secondAllowed = candidate
    end
  end

  routeRecord = .Directory~new
  routeRecord~put("symbolic.nlp.route/0.1", "SCHEMA")
  routeRecord~put("HYPERDIMENSIONAL_VSA", "ENGINE")
  routeRecord~put(text, "TEXT")
  routeRecord~put(candidates, "CANDIDATES")
  routeRecord~put(.Directory~new, "ACTIVE_CONTEXT")
  routeRecord~put(0, "ROUTABLE")
  routeRecord~put(.Directory~new, "TASK")
  routeRecord~put(.Directory~new, "PRESENTATION")
  routeRecord~put(.Directory~new, "BLOCKED_TASK")

  if bestAllowed == .nil then do
    routeRecord~put("UNKNOWN", "STATUS")
    routeRecord~put("NONE", "REFERRAL_STATUS")
    routeRecord~put("", "INTENT")
    routeRecord~put("POSITIVE", "POLARITY")
    routeRecord~put(0, "COMPLETE")
    routeRecord~put(.Array~new, "NEEDS")
    routeRecord~put(.Directory~new, "ARGUMENTS")
    routeRecord~put(.Directory~new, "SEMANTIC")
    routeRecord~put("hyper: no candidate", "EVIDENCE")
    routeRecord~put(0, "SCORE")
    routeRecord~put(0, "MARGIN")
    return routeRecord
  end

  /* Ambiguity check. */
  margin = 100
  if secondAllowed \== .nil then margin = bestAllowed~at("SCORE") - secondAllowed~at("SCORE")
  if bestAllowed~at("SCORE") < threshold | margin < ambiguityMargin then do
    routeRecord~put("UNKNOWN", "STATUS")
    routeRecord~put("NONE", "REFERRAL_STATUS")
    routeRecord~put("", "INTENT")
    routeRecord~put("POSITIVE", "POLARITY")
    routeRecord~put(0, "COMPLETE")
    routeRecord~put(.Array~new, "NEEDS")
    routeRecord~put(.Directory~new, "ARGUMENTS")
    routeRecord~put(.Directory~new, "SEMANTIC")
    routeRecord~put(bestAllowed~at("EVIDENCE"), "EVIDENCE")
    routeRecord~put(bestAllowed~at("SCORE"), "SCORE")
    routeRecord~put(margin, "MARGIN")
    return routeRecord
  end

  /* MATCHED */
  routeRecord~put("MATCHED", "STATUS")
  routeRecord~put(bestAllowed~at("ID"), "INTENT")
  routeRecord~put(bestAllowed~at("SCORE"), "SCORE")
  routeRecord~put(margin, "MARGIN")
  routeRecord~put(bestAllowed~at("EVIDENCE"), "EVIDENCE")
  routeRecord~put("POSITIVE", "POLARITY")
  routeRecord~put(1, "COMPLETE")
  routeRecord~put(.Array~new, "NEEDS")
  routeRecord~put(.Directory~new, "ARGUMENTS")
  routeRecord~put(self~semanticRecord(bestAllowed), "SEMANTIC")

  ref = intentTable~at(bestAllowed~at("ID"))~at("REFERRAL")
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

::method phraseBonus
  expose intentTable
  use arg id, content, rawText
  spec = intentTable~at(id)
  bonus = 0
  /* Exact full-utterance match against phrases / learned phrases. */
  qnorm = self~normalizeTerms(rawText)
  do part over .Array~of(spec~at("PHRASES"), spec~at("LEARNED_PHRASES"))
    if part == "" | part == .nil then iterate
    s = translate(part, " ", "|")
    do position = 1 to words(s)
      /* For multi-word phrases we would need more, but for now reward any
         exact token that appears as a registered phrase atom. */
      p = subword(s, position, 1)
      if p == qnorm then do
        if part == spec~at("LEARNED_PHRASES") then bonus = 25
        else bonus = 18
        return bonus
      end
    end
  end
  /* Contained multi-word phrase: if every token of a registered phrase
     appears in the query content, give a smaller bonus. */
  qset = .Directory~new
  do i = 1 to content~items
    qset~put(1, content[i])
  end
  do part over .Array~of(spec~at("PHRASES"), spec~at("LEARNED_PHRASES"))
    if part == "" | part == .nil then iterate
    s = translate(part, " ", "|")
    needed = 0
    hit = 0
    do position = 1 to words(s)
      p = subword(s, position, 1)
      if p == "" then iterate
      needed = needed + 1
      if qset~hasIndex(p) = 1 then hit = hit + 1
    end
    if needed >= 2 then if hit = needed then do
      b = 8 + needed
      if part == spec~at("LEARNED_PHRASES") then b = b + 4
      if b > bonus then bonus = b
    end
  end
  return bonus

::method makeCandidate
  use arg spec, cscore, sim, bonus
  fit = self~contextFit(spec)
  provenance = spec~at("PROVENANCE")
  reviewState = provenance~at("REVIEW_STATE")
  active = 0
  if reviewState == "APPROVED" then active = 1
  evidence = "VSA sim=" || format(sim, , 1) || " phrase=" || format(bonus, , 1)
  candidate = .Directory~new
  candidate~put(spec~at("ID"), "ID")
  candidate~put(cscore, "SCORE")
  candidate~put(spec~at("PRIORITY"), "PRIORITY")
  candidate~put(evidence, "EVIDENCE")
  candidate~put(fit~at("ALLOWED"), "CONTEXT_ALLOWED")
  candidate~put(fit~at("SCORE"), "CONTEXT_SCORE")
  candidate~put(fit~at("REASON"), "CONTEXT_REASON")
  candidate~put(active, "REGISTRATION_ACTIVE")
  candidate~put(reviewState, "REVIEW_STATE")
  return candidate

::method semanticRecord
  use arg candidate
  s = .Directory~new
  s~put("hyperdimensional.nlp.semantic/0.1", "SCHEMA")
  s~put("HYPERDIMENSIONAL_VSA", "ENGINE")
  s~put(candidate~at("ID"), "INTENT")
  s~put(candidate~at("EVIDENCE"), "EVIDENCE")
  s~put(.Array~new, "RELATIONS")
  s~put("VSA(" || candidate~at("ID") || ")", "FORM")
  return s

::method candidateBetter
  use arg leftCandidate, rightCandidate
  if leftCandidate~at("SCORE") > rightCandidate~at("SCORE") then return 1
  if leftCandidate~at("SCORE") < rightCandidate~at("SCORE") then return 0
  if leftCandidate~at("CONTEXT_SCORE") > rightCandidate~at("CONTEXT_SCORE") then return 1
  if leftCandidate~at("CONTEXT_SCORE") < rightCandidate~at("CONTEXT_SCORE") then return 0
  if leftCandidate~at("PRIORITY") > rightCandidate~at("PRIORITY") then return 1
  return 0

::method contextFit
  expose activeMode activeLanguage activeApplication
  use arg spec
  ref = spec~at("REFERRAL")
  allowed = 1
  score = 1
  reason = "OK"
  if ref \== .nil then if ref~items > 0 then do
    ctx = ref~at("CONTEXT")
    if ctx \== .nil then do
      m = ctx~at("MODE")
      l = ctx~at("LANGUAGE")
      a = ctx~at("APPLICATION")
      if m \== "ANY" then if m \== "" then if activeMode \== "ANY" then if m \== activeMode then do
        /* mismatch handled below */
      end
      /* Simplified: if active context is set and referral restricts it, check. */
      if activeMode \== "ANY" then if m \== "ANY" then if m \== "" then if m \== activeMode then do
        allowed = 0
        reason = "MODE"
      end
    end
  end
  fit = .Directory~new
  fit~put(allowed, "ALLOWED")
  fit~put(score, "SCORE")
  fit~put(reason, "REASON")
  return fit

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
