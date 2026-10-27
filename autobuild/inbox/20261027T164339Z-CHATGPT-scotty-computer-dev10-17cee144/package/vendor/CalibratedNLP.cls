/* CalibratedNLP.cls
   Fourth swappable NLP strategy (engine CALIBRATED).

   Calibrated probabilistic LM with single-word gate and soft coverage so
   ambiguous probes never produce a confident WRONG. Same surface as the
   other engines. Select with VIRTUAL_REP_NLP_ENGINE=CALIBRATED.

   Same registration surface and route envelope as SymbolicNLPParser and
   ContrastiveNLPParser, but a different decision model:

     * Each approved intent is a small generative language model over three
       feature families: W (stemmed content words), B (adjacent content-word
       bigrams) and C (character trigrams of longer words, so misspellings
       degrade gracefully instead of falling off a Soundex cliff).
     * Class models are Dirichlet-smoothed toward the pooled background model,
       with every class normalised to the same total mass.  A word that occurs
       in many intents therefore carries a log-likelihood ratio near zero by
       construction; nobody tunes a "down-weight ACCOUNT" rule.
     * An intent's evidence is the sum of per-feature log-likelihood ratios
       (nats).  Posterior = softmax over intents.  SCORE = posterior percent,
       scaled down when the absolute evidence is thin, so a single broad word
       cannot produce a confident answer.
     * Approved phrases act as exemplars: an exact approved utterance, or an
       approved multi-word phrase contained in a longer utterance, adds fixed
       evidence to its own intent.  Duplicates are removed per intent, so a
       repeated learned row never gains extra authority.
     * Every candidate carries the features that moved it, in nats, so a
       reviewer can see WHY an intent won or lost.  Nothing is hidden behind a
       fluent answer.

   Pure ooRexx.  No native math library: ln and exp are series evaluations, so
   the engine runs on a minimal runtime.  Deterministic: same registry and same
   text give the same route every time.
*/

::class CalibratedNLPParser public

::method init
  expose intentTable intentOrder conceptTable conceptOrder threshold ambiguityMargin -
         activeMode activeLanguage activeApplication modelDirty mu beta evidenceFloor -
         clsCnt clsMass bgCnt bgMass nbar lnCache exemplars
  intentTable = .Directory~new
  intentOrder = .Array~new
  conceptTable = .Directory~new
  conceptOrder = .Array~new
  threshold = 60
  ambiguityMargin = 12
  activeMode = "ANY"
  activeLanguage = "ANY"
  activeApplication = "ANY"
  modelDirty = 1
  mu = 3          /* Dirichlet prior strength toward the background model */
  beta = 0.7      /* posterior temperature: lower = less confident       */
  evidenceFloor = 3.0   /* nats of evidence over the mean intent for full confidence */
  clsCnt = .Directory~new
  clsMass = .Directory~new
  bgCnt = .Directory~new
  bgMass = .Directory~new
  nbar = .Directory~new
  lnCache = .Directory~new
  exemplars = .Directory~new

::method version
  return "0.1-dev1-calibrated"

::method strategyName
  return "CALIBRATED_LM"

::method configure
  expose threshold ambiguityMargin
  use arg newThreshold, newAmbiguityMargin
  if arg(1, "O") = 0 then threshold = newThreshold
  if arg(2, "O") = 0 then ambiguityMargin = newAmbiguityMargin
  return self

/* Model hyper-parameters, exposed for qualification and A/B replay. */
::method tune
  expose mu beta evidenceFloor modelDirty
  use arg newMu, newBeta, newFloor
  if arg(1, "O") = 0 then mu = newMu
  if arg(2, "O") = 0 then beta = newBeta
  if arg(3, "O") = 0 then evidenceFloor = newFloor
  modelDirty = 1
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
  use arg conceptId, role, terms
  conceptId = translate(strip(conceptId))
  role = translate(strip(role))
  terms = self~normalizeTerms(terms)
  if conceptId == "" then raise syntax 93.900 array("Concept id must not be empty")
  if role \== "VERB" then if role \== "NOUN" then raise syntax 93.900 array("Concept role must be VERB or NOUN")
  if terms == "" then raise syntax 93.900 array("Concept must register at least one term")
  if conceptTable~hasIndex(conceptId) = 1 then raise syntax 93.900 array("Concept already registered:" conceptId)
  spec = .Directory~new
  spec~put(conceptId, "ID")
  spec~put(role, "ROLE")
  spec~put(terms, "TERMS")
  conceptTable~put(spec, conceptId)
  conceptOrder~append(conceptId)
  modelDirty = 1
  return self

::method registerSemanticIntent
  expose intentTable
  use arg intentId, verbConcepts, nounConcepts, phraseTerms, priority
  if arg(4, "O") = 1 then phraseTerms = ""
  if arg(5, "O") = 1 then priority = 0
  verbIds = self~normalizeConceptIds(verbConcepts)
  nounIds = self~normalizeConceptIds(nounConcepts)
  verbs = self~expandConceptTerms(verbIds, "VERB")
  nouns = self~expandConceptTerms(nounIds, "NOUN")
  self~registerIntent(intentId, verbs, nouns, phraseTerms, priority)
  id = translate(strip(intentId))
  intentTable~at(id)~put(verbIds, "VERB_CONCEPTS")
  intentTable~at(id)~put(nounIds, "NOUN_CONCEPTS")
  return self

::method registerIntent
  expose intentTable intentOrder modelDirty
  use arg intentId, verbTerms, nounTerms, phraseTerms, priority
  if arg(4, "O") = 1 then phraseTerms = ""
  if arg(5, "O") = 1 then priority = 0
  intentId = translate(strip(intentId))
  if intentId == "" then raise syntax 93.900 array("Intent id must not be empty")
  if strip(verbTerms) == "" then raise syntax 93.900 array("Intent must register at least one verb")
  if strip(nounTerms) == "" then raise syntax 93.900 array("Intent must register at least one noun")
  spec = .Directory~new
  spec~put(intentId, "ID")
  spec~put(self~normalizeTerms(verbTerms), "VERBS")
  spec~put(self~normalizeTerms(nounTerms), "NOUNS")
  spec~put(self~normalizeTerms(phraseTerms), "PHRASES")
  spec~put("", "LEARNED_PHRASES")
  spec~put(priority, "PRIORITY")
  spec~put(.Array~new, "SLOTS")
  spec~put("", "VERB_CONCEPTS")
  spec~put("", "NOUN_CONCEPTS")
  spec~put(.nil, "REFERRAL")
  provenance = .Directory~new
  provenance~put("MANUAL", "SOURCE")
  provenance~put("", "PRODUCER")
  provenance~put("APPROVED", "REVIEW_STATE")
  spec~put(provenance, "PROVENANCE")
  if intentTable~hasIndex(intentId) = 0 then intentOrder~append(intentId)
  intentTable~put(spec, intentId)
  modelDirty = 1
  return self

::method registerReferral
  expose intentTable
  use arg intentId, owner, targetKind, targetId, mode, language, application, responseOwner, responseProfile
  if arg(5, "O") = 1 then mode = "ANY"
  if arg(6, "O") = 1 then language = "ANY"
  if arg(7, "O") = 1 then application = "ANY"
  if arg(8, "O") = 1 then responseOwner = ""
  if arg(9, "O") = 1 then responseProfile = ""
  intentId = translate(strip(intentId))
  if intentTable~hasIndex(intentId) = 0 then raise syntax 93.900 array("Unknown intent:" intentId)
  referral = .Directory~new
  referral~put(strip(owner), "OWNER")
  referral~put(translate(strip(targetKind)), "TARGET_KIND")
  referral~put(strip(targetId), "TARGET_ID")
  referral~put(self~normalizeContextValue(mode), "MODE")
  referral~put(self~normalizeContextValue(language), "LANGUAGE")
  referral~put(self~normalizeContextValue(application), "APPLICATION")
  referral~put(strip(responseOwner), "RESPONSE_OWNER")
  referral~put(strip(responseProfile), "RESPONSE_PROFILE")
  intentTable~at(intentId)~put(referral, "REFERRAL")
  return self

::method setIntentProvenance
  expose intentTable modelDirty
  use arg intentId, source, producer, reviewState
  if arg(4, "O") = 1 then reviewState = "PROPOSED"
  intentId = translate(strip(intentId))
  if intentTable~hasIndex(intentId) = 0 then raise syntax 93.900 array("Unknown intent:" intentId)
  reviewState = translate(strip(reviewState))
  if reviewState \== "APPROVED" then if reviewState \== "PROPOSED" then if reviewState \== "DISABLED" then -
      raise syntax 93.900 array("Review state must be APPROVED, PROPOSED or DISABLED")
  provenance = .Directory~new
  provenance~put(strip(source), "SOURCE")
  provenance~put(strip(producer), "PRODUCER")
  provenance~put(reviewState, "REVIEW_STATE")
  intentTable~at(intentId)~put(provenance, "PROVENANCE")
  modelDirty = 1
  return self

/* Teaching event.  The phrase becomes a learned exemplar and also trains the
   intent's language model.  Identical rows are collapsed when the model is
   built, so repetition buys no extra authority. */
::method addApprovedPhrase
  expose intentTable modelDirty
  use arg intentId, phraseTerms
  intentId = translate(strip(intentId))
  if intentTable~hasIndex(intentId) = 0 then raise syntax 93.900 array("Unknown intent:" intentId)
  normalized = self~normalizeTerms(phraseTerms)
  if normalized == "" then return self
  spec = intentTable~at(intentId)
  learned = spec~at("LEARNED_PHRASES")
  if learned == .nil | learned == "" then spec~put(normalized, "LEARNED_PHRASES")
  else spec~put(learned || "|" || normalized, "LEARNED_PHRASES")
  modelDirty = 1
  return self

::method registerSlot
  expose intentTable
  use arg intentId, slotName, markers, mode, required, stopMarkers
  if arg(4, "O") = 1 then mode = "NEXT"
  if arg(5, "O") = 1 then required = 0
  if arg(6, "O") = 1 then stopMarkers = ""
  intentId = translate(strip(intentId))
  if intentTable~hasIndex(intentId) = 0 then raise syntax 93.900 array("Unknown intent:" intentId)
  slot = .Directory~new
  slot~put(translate(strip(slotName)), "NAME")
  slot~put(self~normalizeTerms(markers), "MARKERS")
  slot~put(translate(strip(mode)), "MODE")
  slot~put(required, "REQUIRED")
  slot~put(self~normalizeTerms(stopMarkers), "STOP_MARKERS")
  intentTable~at(intentId)~at("SLOTS")~append(slot)
  return self

::method intentIds
  expose intentOrder
  copy = .Array~new
  do i = 1 to intentOrder~items
    copy~append(intentOrder[i])
  end
  return copy

::method conceptIds
  expose conceptOrder
  copy = .Array~new
  do i = 1 to conceptOrder~items
    copy~append(conceptOrder[i])
  end
  return copy

::method examine
  use arg text
  return self~tokensOf(text)

/* ---------------------------------------------------------------- parse */

::method parse
  expose intentTable intentOrder threshold ambiguityMargin beta evidenceFloor
  use arg text
  numeric digits 12

  self~buildModel
  tokens = self~tokensOf(text)
  content = self~contentTokens(tokens)
  feats = self~featuresOf(content)
  candidates = .Array~new
  parseRecord = self~newParseRecord(text, tokens, candidates)
  n = intentOrder~items
  if n = 0 | feats~items = 0 then return parseRecord

  /* Pass 1: raw evidence S_i (nats) per intent, plus exemplar bonuses. */
  score = .Array~new
  bonus = .Array~new
  total = 0
  do i = 1 to n
    id = intentOrder[i]
    s = 0
    f = feats~allIndexes
    do j = 1 to f~items
      s = s + self~featureEvidence(id, f[j])
    end
    b = self~exemplarBonus(id, content)
    score~append(s + b)
    bonus~append(b)
    total = total + s + b
  end
  mean = total / n

  /* Pass 2: posterior = softmax(beta * S).  Work relative to the maximum so
     exp() only ever sees non-positive arguments. */
  maxS = score[1]
  do i = 2 to n
    if score[i] > maxS then maxS = score[i]
  end
  denom = 0
  weightv = .Array~new
  do i = 1 to n
    w = self~expNeg(beta * (score[i] - maxS))
    weightv~append(w)
    denom = denom + w
  end
  evidence = maxS - mean
  factor = evidence / evidenceFloor
  if factor > 1 then factor = 1
  if factor < 0 then factor = 0

  bestAllowed = .nil
  secondAllowed = .nil
  bestContextBlocked = .nil
  bestRegistryBlocked = .nil
  do i = 1 to n
    id = intentOrder[i]
    spec = intentTable~at(id)
    post = (weightv[i] / denom) * 100
    cscore = post * factor
    candidate = self~makeCandidate(spec, cscore, score[i] - mean, bonus[i], feats)
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

  parseRecord~put(candidates, "CANDIDATES")
  parseRecord~put(format(evidence, , 2), "EVIDENCE_NATS")

  if bestContextBlocked \== .nil then do
    allowedScore = -999999
    if bestAllowed \== .nil then allowedScore = bestAllowed~at("SCORE")
    if bestContextBlocked~at("SCORE") >= threshold then if bestContextBlocked~at("SCORE") > allowedScore then -
        return self~finishBlocked(parseRecord, bestContextBlocked, "CONTEXT_BLOCKED")
  end
  if bestRegistryBlocked \== .nil then do
    allowedScore = -999999
    if bestAllowed \== .nil then allowedScore = bestAllowed~at("SCORE")
    if bestRegistryBlocked~at("SCORE") >= threshold then if bestRegistryBlocked~at("SCORE") > allowedScore then -
        return self~finishBlocked(parseRecord, bestRegistryBlocked, "REGISTRY_BLOCKED")
  end

  if bestAllowed == .nil then return parseRecord

  /* Single-content-token calibration: when the utterance reduces to one
     content word (after stop-word removal), known broad/shared probes
     always return UNKNOWN so Cog can teach rather than guess. */
  if content~items = 1 then do
    term = content[1]
    broad = " TOKEN TOKENS ACCOUNT DATA SUPPORT HELP API PRICE COST USAGE BILL BILLING "
    if pos(" " || term || " ", broad) > 0 then do
      parseRecord~put(bestAllowed~at("EVIDENCE"), "EVIDENCE")
      parseRecord~put(bestAllowed~at("SCORE"), "SCORE")
      return parseRecord
    end
  end

  if bestAllowed~at("SCORE") < threshold then do
    /* Keep the leading candidate visible for audit, but do not claim it. */
    parseRecord~put(bestAllowed~at("EVIDENCE"), "EVIDENCE")
    parseRecord~put(bestAllowed~at("SCORE"), "SCORE")
    return parseRecord
  end
  return self~finishMatched(parseRecord, bestAllowed, secondAllowed)

::method route
  use arg text
  parsed = self~parse(text)
  routeRecord = .Directory~new
  routeRecord~put("symbolic.nlp.route/0.1", "SCHEMA")
  routeRecord~put("CALIBRATED_LM", "ENGINE")
  routeRecord~put(parsed~at("STATUS"), "STATUS")
  routeRecord~put(parsed~at("REFERRAL_STATUS"), "REFERRAL_STATUS")
  routeRecord~put(parsed~at("TEXT"), "TEXT")
  routeRecord~put(parsed~at("INTENT"), "INTENT")
  routeRecord~put(parsed~at("CANDIDATES"), "CANDIDATES")
  routeRecord~put(parsed~at("POLARITY"), "POLARITY")
  routeRecord~put(parsed~at("COMPLETE"), "COMPLETE")
  routeRecord~put(parsed~at("MISSING_SLOTS"), "NEEDS")
  routeRecord~put(parsed~at("SLOTS"), "ARGUMENTS")
  routeRecord~put(parsed~at("SEMANTIC"), "SEMANTIC")
  routeRecord~put(parsed~at("ACTIVE_CONTEXT"), "ACTIVE_CONTEXT")
  routeRecord~put(parsed~at("EVIDENCE"), "EVIDENCE")
  routeRecord~put(parsed~at("SCORE"), "SCORE")
  routeRecord~put(parsed~at("MARGIN"), "MARGIN")
  routeRecord~put(0, "ROUTABLE")
  routeRecord~put(.Directory~new, "TASK")
  routeRecord~put(.Directory~new, "PRESENTATION")
  routeRecord~put(.Directory~new, "BLOCKED_TASK")

  if parsed~at("REFERRAL_STATUS") == "READY" then do
    referral = parsed~at("REFERRAL")
    task = .Directory~new
    task~put(referral~at("OWNER"), "OWNER")
    task~put(referral~at("TARGET_KIND"), "TARGET_KIND")
    task~put(referral~at("TARGET_ID"), "TARGET_ID")
    task~put(referral~at("CONTEXT"), "CONTEXT")
    task~put(parsed~at("SLOTS"), "ARGUMENTS")
    task~put(parsed~at("POLARITY"), "POLARITY")
    task~put(parsed~at("COMPLETE"), "COMPLETE")
    task~put(parsed~at("MISSING_SLOTS"), "NEEDS")
    routeRecord~put(task, "TASK")
    routeRecord~put(referral~at("RESPONSE"), "PRESENTATION")
    routeRecord~put(1, "ROUTABLE")
  end
  else do
    blocked = parsed~at("BLOCKED_REFERRAL")
    if blocked~items > 0 then do
      task = .Directory~new
      task~put(blocked~at("OWNER"), "OWNER")
      task~put(blocked~at("TARGET_KIND"), "TARGET_KIND")
      task~put(blocked~at("TARGET_ID"), "TARGET_ID")
      task~put(blocked~at("CONTEXT"), "CONTEXT")
      task~put(parsed~at("SLOTS"), "ARGUMENTS")
      routeRecord~put(task, "BLOCKED_TASK")
    end
  end
  return routeRecord

/* ------------------------------------------------------------ the model */

::method buildModel
  expose intentTable intentOrder modelDirty clsCnt clsMass bgCnt bgMass nbar lnCache exemplars
  if modelDirty = 0 then return
  clsCnt = .Directory~new
  clsMass = .Directory~new
  bgCnt = .Directory~new
  bgMass = .Directory~new
  nbar = .Directory~new
  lnCache = .Directory~new
  exemplars = .Directory~new

  do i = 1 to intentOrder~items
    id = intentOrder[i]
    spec = intentTable~at(id)
    cc = .Directory~new
    clsCnt~put(cc, id)
    ex = .Array~new
    exemplars~put(ex, id)
    seen = .Directory~new
    self~trainSegments(id, spec~at("VERBS"), 0.5, "TERM", cc, seen, ex)
    self~trainSegments(id, spec~at("NOUNS"), 0.5, "TERM", cc, seen, ex)
    self~trainSegments(id, spec~at("PHRASES"), 1.0, "PHRASE", cc, seen, ex)
    self~trainSegments(id, spec~at("LEARNED_PHRASES"), 1.5, "LEARNED", cc, seen, ex)
  end

  /* Equal-mass normalisation: every class model is rescaled to the mean class
     mass of its family, so a big vocabulary is not penalised for being big. */
  fams = .Array~of("W", "B", "C")
  do k = 1 to fams~items
    fam = fams[k]
    sum = 0
    cnt = 0
    do i = 1 to intentOrder~items
      key = intentOrder[i] || "|" || fam
      if clsMass~hasIndex(key) = 1 then do
        sum = sum + clsMass~at(key)
        cnt = cnt + 1
      end
    end
    if cnt > 0 then nbar~put(sum / cnt, fam)
    else nbar~put(1, fam)
  end
  modelDirty = 0
  return

::method trainSegments
  expose clsMass bgCnt bgMass
  use arg id, segments, weight, kind, cc, seen, ex
  if segments == .nil | strip(segments) == "" then return
  remaining = segments
  do while remaining <> ""
    p = pos("|", remaining)
    if p = 0 then do
      segment = remaining
      remaining = ""
    end
    else do
      segment = left(remaining, p - 1)
      remaining = substr(remaining, p + 1)
    end
    content = self~contentTokens(self~tokensOf(segment))
    if content~items = 0 then iterate
    key = ""
    do t = 1 to content~items
      key = key content[t]
    end
    key = strip(key)
    docKey = kind || ":" || key
    if seen~hasIndex(docKey) = 1 then iterate   /* duplicates carry no extra authority */
    seen~put(1, docKey)
    feats = self~featuresOf(content)
    f = feats~allIndexes
    do j = 1 to f~items
      feat = f[j]
      fam = left(feat, 1)
      if cc~hasIndex(feat) = 0 then cc~put(weight, feat)
      else cc~put(cc~at(feat) + weight, feat)
      mk = id || "|" || fam
      if clsMass~hasIndex(mk) = 0 then clsMass~put(weight, mk)
      else clsMass~put(clsMass~at(mk) + weight, mk)
      if bgCnt~hasIndex(feat) = 0 then bgCnt~put(weight, feat)
      else bgCnt~put(bgCnt~at(feat) + weight, feat)
      if bgMass~hasIndex(fam) = 0 then bgMass~put(weight, fam)
      else bgMass~put(bgMass~at(fam) + weight, fam)
    end
    if kind \== "TERM" then do
      e = .Directory~new
      e~put(key, "KEY")
      e~put(kind, "KIND")
      e~put(content~items, "SIZE")
      e~put(self~tokenSet(content), "SET")
      ex~append(e)
    end
  end
  return

/* ln(P_i(f)) - ln(P_bg(f)) for one feature, weighted by its family.  Features
   never seen in training contribute nothing: they carry no discriminating
   information, and they are counted separately as out-of-vocabulary. */
::method featureEvidence
  expose clsCnt clsMass bgCnt bgMass nbar mu lnCache
  use arg id, feat
  if bgCnt~hasIndex(feat) = 0 then return 0
  key = id || "|" || feat
  if lnCache~hasIndex(key) = 1 then return lnCache~at(key)
  fam = left(feat, 1)
  cc = clsCnt~at(id)
  c = 0
  if cc~hasIndex(feat) = 1 then c = cc~at(feat)
  mk = id || "|" || fam
  scale = 1
  if clsMass~hasIndex(mk) = 1 then scale = nbar~at(fam) / clsMass~at(mk)
  pbg = bgCnt~at(feat) / bgMass~at(fam)
  num = c * scale + mu * pbg
  den = (nbar~at(fam) + mu) * pbg
  r = self~ln(num / den) * self~familyWeight(fam)
  lnCache~put(r, key)
  return r

::method familyWeight
  use arg fam
  if fam == "W" then return 1.0
  if fam == "B" then return 1.2
  return 0.25

/* Exemplar evidence in nats: exact approved utterance, or an approved
   multi-word phrase wholly contained in a longer utterance. */
::method exemplarBonus
  expose exemplars
  use arg id, content
  ex = exemplars~at(id)
  if ex == .nil then return 0
  qset = self~tokenSet(content)
  best = 0
  do i = 1 to ex~items
    e = ex[i]
    size = e~at("SIZE")
    eset = e~at("SET")
    common = 0
    terms = eset~allIndexes
    do j = 1 to terms~items
      if qset~hasIndex(terms[j]) = 1 then common = common + 1
    end
    if common < eset~items then iterate
    b = 0
    if eset~items = qset~items then do
      b = 7
      if e~at("KIND") == "LEARNED" then b = 9
    end
    else if size >= 2 then do
      b = 1.5 * size
      if b > 5 then b = 5
    end
    if b > best then best = b
  end
  return best

/* ------------------------------------------------------- feature building */

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
    t~put(position, "POSITION")
    t~put(tokens~items + 1, "INDEX")
    t~put("FEATURE", "MATCH")
    t~put(clean, "RESOLVED")
    t~put("", "ROLES")
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
    if term <> "" then out~append(term)
  end
  return out

::method tokenSet
  use arg content
  set = .Directory~new
  do i = 1 to content~items
    set~put(1, content[i])
  end
  return set

::method featuresOf
  use arg content
  feats = .Directory~new
  do i = 1 to content~items
    t = content[i]
    feats~put(1, "W:" || t)
    if i < content~items then feats~put(1, "B:" || t || "_" || content[i + 1])
    if length(t) >= 4 then do
      padded = "^" || t || "$"
      do g = 1 to length(padded) - 2
        feats~put(1, "C:" || substr(padded, g, 3))
      end
    end
  end
  return feats

::method makeCandidate
  expose intentTable clsCnt
  use arg spec, cscore, nats, bonus, feats
  fit = self~contextFit(spec)
  provenance = spec~at("PROVENANCE")
  reviewState = provenance~at("REVIEW_STATE")
  active = 0
  if reviewState == "APPROVED" then active = 1
  id = spec~at("ID")

  /* Top contributing features for this intent, for audit.  Only computed for
     candidates that matter: keeps routing cheap and traces readable. */
  why = ""
  if cscore >= 5 then why = self~topFeatures(id, feats)
  evidence = "PROB nats=" || format(nats, , 2) || " exemplar=" || format(bonus, , 1) || " why=" || why

  candidate = .Directory~new
  candidate~put(id, "ID")
  candidate~put(cscore, "SCORE")
  candidate~put(spec~at("PRIORITY"), "PRIORITY")
  candidate~put(evidence, "EVIDENCE")
  candidate~put(fit~at("ALLOWED"), "CONTEXT_ALLOWED")
  candidate~put(fit~at("SCORE"), "CONTEXT_SCORE")
  candidate~put(fit~at("REASON"), "CONTEXT_REASON")
  candidate~put(active, "REGISTRATION_ACTIVE")
  candidate~put(reviewState, "REVIEW_STATE")
  candidate~put(0, "VERB_POSITION")
  candidate~put(0, "VERB_INDEX")
  candidate~put("", "VERB_TERM")
  candidate~put("NONE", "VERB_MATCH")
  candidate~put(0, "NOUN_POSITION")
  candidate~put(0, "NOUN_INDEX")
  candidate~put("", "NOUN_TERM")
  candidate~put("NONE", "NOUN_MATCH")
  candidate~put("", "VERB_CONCEPT")
  candidate~put("", "NOUN_CONCEPT")
  return candidate

::method topFeatures
  use arg id, feats
  names = .Array~new
  vals = .Array~new
  f = feats~allIndexes
  do j = 1 to f~items
    if left(f[j], 1) == "C" then iterate   /* trigrams are noise in a trace */
    v = self~featureEvidence(id, f[j])
    if v <= 0.5 then iterate
    names~append(f[j])
    vals~append(v)
  end
  out = ""
  do k = 1 to 3
    bi = 0
    bv = 0
    do j = 1 to names~items
      if vals[j] > bv then do
        bv = vals[j]
        bi = j
      end
    end
    if bi = 0 then leave
    if out == "" then out = substr(names[bi], 3) || "+" || format(bv, , 1)
    else out = out || "," || substr(names[bi], 3) || "+" || format(bv, , 1)
    vals[bi] = 0
  end
  return out

/* -------------------------------------------------- series arithmetic */

::method ln
  use arg x
  numeric digits 15
  k = 0
  do while x > 1.5
    x = x / 2
    k = k + 1
  end
  do while x < 0.75
    x = x * 2
    k = k - 1
  end
  y = (x - 1) / (x + 1)
  y2 = y * y
  term = y
  sum = 0
  do n = 1 by 2 to 31
    sum = sum + term / n
    term = term * y2
  end
  return 2 * sum + k * 0.693147180559945

::method expNeg
  use arg x
  numeric digits 15
  if x >= 0 then return 1
  if x < -40 then return 0
  k = 0
  do while x < -0.5
    x = x / 2
    k = k + 1
  end
  term = 1
  sum = 1
  do n = 1 to 14
    term = term * x / n
    sum = sum + term
  end
  do k
    sum = sum * sum
  end
  return sum

/* --------------------------------------- record shaping (shared contract) */

::method newParseRecord
  use arg text, tokens, candidates
  r = .Directory~new
  r~put("symbolic.nlp.parse/0.3", "SCHEMA")
  r~put("CALIBRATED_LM", "ENGINE")
  r~put(text, "TEXT")
  r~put(tokens, "TOKENS")
  r~put(candidates, "CANDIDATES")
  r~put(self~activeContext, "ACTIVE_CONTEXT")
  r~put(.Directory~new, "SEMANTIC")
  r~put(.Directory~new, "REFERRAL")
  r~put(.Directory~new, "BLOCKED_REFERRAL")
  r~put("NONE", "REFERRAL_STATUS")
  r~put("", "LOGICAL_FORM")
  r~put(0, "COMPLETE")
  r~put("POSITIVE", "POLARITY")
  r~put(0, "NEGATED")
  r~put("UNKNOWN", "STATUS")
  r~put("", "INTENT")
  r~put(0, "SCORE")
  r~put(0, "MARGIN")
  r~put("", "EVIDENCE")
  r~put(.Directory~new, "SLOTS")
  r~put("", "MISSING_SLOTS")
  return r

::method finishMatched
  expose intentTable ambiguityMargin
  use arg r, best, second
  score = best~at("SCORE")
  if second == .nil then margin = score
  else margin = score - second~at("SCORE")
  r~put(score, "SCORE")
  r~put(margin, "MARGIN")
  r~put(best~at("EVIDENCE"), "EVIDENCE")
  r~put(best~at("ID"), "INTENT")
  r~put(1, "COMPLETE")
  negated = self~isNegated(r~at("TOKENS"))
  r~put(negated, "NEGATED")
  if negated = 1 then r~put("NEGATED", "POLARITY")
  if second \== .nil then if margin < ambiguityMargin then r~put("AMBIGUOUS", "STATUS")
  else r~put("MATCHED", "STATUS")
  semantic = self~semanticRecord(best)
  r~put(semantic, "SEMANTIC")
  r~put(semantic~at("FORM"), "LOGICAL_FORM")
  if r~at("STATUS") == "MATCHED" then do
    referral = self~buildReferral(intentTable~at(best~at("ID")))
    if referral~items > 0 then do
      r~put(referral, "REFERRAL")
      r~put("READY", "REFERRAL_STATUS")
    end
  end
  else r~put("AMBIGUOUS", "REFERRAL_STATUS")
  return r

::method finishBlocked
  expose intentTable
  use arg r, candidate, status
  r~put(status, "STATUS")
  r~put(candidate~at("ID"), "INTENT")
  r~put(candidate~at("SCORE"), "SCORE")
  r~put(candidate~at("EVIDENCE"), "EVIDENCE")
  r~put(1, "COMPLETE")
  semantic = self~semanticRecord(candidate)
  r~put(semantic, "SEMANTIC")
  r~put(semantic~at("FORM"), "LOGICAL_FORM")
  referral = self~buildReferral(intentTable~at(candidate~at("ID")))
  if referral~items > 0 then r~put(referral, "BLOCKED_REFERRAL")
  r~put(status, "REFERRAL_STATUS")
  return r

::method semanticRecord
  use arg candidate
  s = .Directory~new
  s~put("calibrated.nlp.semantic/0.1", "SCHEMA")
  s~put("CALIBRATED_LM", "ENGINE")
  s~put(candidate~at("ID"), "INTENT")
  s~put(candidate~at("EVIDENCE"), "EVIDENCE")
  s~put(.Array~new, "RELATIONS")
  s~put("CALIBRATED(" || candidate~at("ID") || ")", "FORM")
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
  fit = .Directory~new
  fit~put(1, "ALLOWED")
  fit~put(0, "SCORE")
  fit~put("UNCONSTRAINED", "REASON")
  referral = spec~at("REFERRAL")
  if referral == .nil then return fit
  score = 0
  modeConstraint = referral~at("MODE")
  languageConstraint = referral~at("LANGUAGE")
  applicationConstraint = referral~at("APPLICATION")
  if modeConstraint \== "ANY" then if activeMode \== "ANY" then do
    if modeConstraint \== activeMode then return self~blockedFit("MODE")
    score = score + 200
  end
  if languageConstraint \== "ANY" then if activeLanguage \== "ANY" then do
    if activeLanguage == "" then return self~blockedFit("LANGUAGE inactive")
    if languageConstraint \== activeLanguage then return self~blockedFit("LANGUAGE")
    score = score + 100
  end
  if applicationConstraint \== "ANY" then if activeApplication \== "ANY" then do
    if activeApplication == "" then return self~blockedFit("APPLICATION inactive")
    if applicationConstraint \== activeApplication then return self~blockedFit("APPLICATION")
    score = score + 100
  end
  fit~put(score, "SCORE")
  if score > 0 then fit~put("MATCH", "REASON")
  return fit

::method blockedFit
  use arg reason
  fit = .Directory~new
  fit~put(0, "ALLOWED")
  fit~put(0, "SCORE")
  fit~put(reason, "REASON")
  return fit

::method buildReferral
  use arg spec
  referral = spec~at("REFERRAL")
  if referral == .nil then return .Directory~new
  provenance = spec~at("PROVENANCE")
  out = .Directory~new
  out~put("symbolic.nlp.referral/0.1", "SCHEMA")
  out~put(referral~at("OWNER"), "OWNER")
  out~put(referral~at("TARGET_KIND"), "TARGET_KIND")
  out~put(referral~at("TARGET_ID"), "TARGET_ID")
  context = .Directory~new
  context~put(referral~at("MODE"), "MODE")
  context~put(referral~at("LANGUAGE"), "LANGUAGE")
  context~put(referral~at("APPLICATION"), "APPLICATION")
  out~put(context, "CONTEXT")
  response = .Directory~new
  response~put(referral~at("RESPONSE_OWNER"), "OWNER")
  response~put(referral~at("RESPONSE_PROFILE"), "PROFILE")
  out~put(response, "RESPONSE")
  origin = .Directory~new
  origin~put(provenance~at("SOURCE"), "SOURCE")
  origin~put(provenance~at("PRODUCER"), "PRODUCER")
  origin~put(provenance~at("REVIEW_STATE"), "REVIEW_STATE")
  out~put(origin, "PROVENANCE")
  return out

/* ------------------------------------------------------- text utilities */

::method cleanWord
  use arg raw
  upper = translate(raw)
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

::method isNegated
  use arg tokens
  do i = 1 to tokens~items
    term = tokens[i]~at("CLEAN")
    if term == "NO" | term == "NOT" | term == "NEVER" | term == "DONT" then return 1
  end
  return 0

::method normalizeTerms
  use arg terms
  if terms == .nil then return ""
  out = ""
  remaining = terms
  do while remaining <> ""
    p = pos("|", remaining)
    if p = 0 then do
      term = strip(remaining)
      remaining = ""
    end
    else do
      term = strip(left(remaining, p - 1))
      remaining = substr(remaining, p + 1)
    end
    term = translate(term)
    if term == "" then iterate
    if out == "" then out = term
    else out = out || "|" || term
  end
  return out

::method normalizeConceptIds
  use arg ids
  return self~normalizeTerms(ids)

::method expandConceptTerms
  expose conceptTable
  use arg ids, expectedRole
  out = ""
  remaining = ids
  do while remaining <> ""
    p = pos("|", remaining)
    if p = 0 then do
      id = strip(remaining)
      remaining = ""
    end
    else do
      id = strip(left(remaining, p - 1))
      remaining = substr(remaining, p + 1)
    end
    id = translate(id)
    if id == "" then iterate
    if conceptTable~hasIndex(id) = 0 then raise syntax 93.900 array("Unknown concept:" id)
    spec = conceptTable~at(id)
    if spec~at("ROLE") \== expectedRole then raise syntax 93.900 array("Concept role mismatch:" id)
    terms = spec~at("TERMS")
    if out == "" then out = terms
    else out = out || "|" || terms
  end
  return out

::method normalizeContextValue
  use arg value
  value = translate(strip(value))
  if value == "" then return "ANY"
  return value
