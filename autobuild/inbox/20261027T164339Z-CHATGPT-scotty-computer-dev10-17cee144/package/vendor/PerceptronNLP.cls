/* PerceptronNLP.cls
   Fourth swappable NLP strategy for the virtual representative (engine PERCEPTRON).

   A discriminative, ONLINE-LEARNING classifier.  Same registration surface and
   route envelope as the other engines; different decision model and, more
   importantly, different economics:

     * One multiclass margin perceptron over word (W), word-pair (B) and
       character-trigram (C) features.  The registry is the training set:
       approved phrases, learned phrases, nouns, and a few verb-noun pairs.
     * Every approved teaching event (addApprovedPhrase) is one online learning
       step - a handful of weight updates on that single example.  The more the
       cognition layer teaches it, the less it is needed.  No retraining pass.
     * Vocabulary repair: an unseen content word is replaced by the unique
       known word within edit distance one (two for long words).  The repair
       is reported in the route as REPAIR.
     * The explanation is the model itself: candidate EVIDENCE lists the
       weights that moved it.  Scores are softmaxed and scaled down when the
       absolute top score is thin, so one broad word cannot be confident.
     * Weights depend on the order of teaching events; replaying the same
       event log reproduces the same engine.

   Pure ooRexx.  No native math library.
*/

::class PerceptronNLPParser public

::method init
  expose intentTable intentOrder conceptTable conceptOrder threshold ambiguityMargin -
         activeMode activeLanguage activeApplication modelDirty beta evidenceFloor -
         epochs margin wts vocab lastRepair
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
  beta = 1.0
  evidenceFloor = 1.5
  epochs = 6
  margin = 2.0
  wts = .Directory~new
  vocab = .Directory~new
  lastRepair = ""

::method version
  return "0.1-dev1-perceptron"

::method strategyName
  return "ONLINE_PERCEPTRON"

::method tune
  expose beta evidenceFloor epochs margin modelDirty
  use arg newBeta, newFloor, newEpochs, newMargin
  if arg(1, "O") = 0 then beta = newBeta
  if arg(2, "O") = 0 then evidenceFloor = newFloor
  if arg(3, "O") = 0 then epochs = newEpochs
  if arg(4, "O") = 0 then margin = newMargin
  modelDirty = 1
  return self

/* Teaching event.  Before the model is first built the phrase is just stored.
   Afterwards it is one online learning step: a few margin-perceptron updates
   on the new example only, so the engine improves with use at a cost of a few
   dozen feature lookups.  Duplicates are ignored. */
::method addApprovedPhrase
  expose intentTable modelDirty
  use arg intentId, phraseTerms
  intentId = translate(strip(intentId))
  if intentTable~hasIndex(intentId) = 0 then raise syntax 93.900 array("Unknown intent:" intentId)
  normalized = self~normalizeTerms(phraseTerms)
  if normalized == "" then return self
  spec = intentTable~at(intentId)
  learned = spec~at("LEARNED_PHRASES")
  if learned \== .nil then if learned \== "" then do
    remaining = learned
    do while remaining <> ""
      p = pos("|", remaining)
      if p = 0 then do
        seg = remaining
        remaining = ""
      end
      else do
        seg = left(remaining, p - 1)
        remaining = substr(remaining, p + 1)
      end
      if seg == normalized then return self
    end
  end
  if learned == .nil | learned == "" then spec~put(normalized, "LEARNED_PHRASES")
  else spec~put(learned || "|" || normalized, "LEARNED_PHRASES")
  if modelDirty = 0 then do
    ex = self~makeExample(intentId, normalized)
    if ex \== .nil then do
      do 8
        if self~trainStep(ex) = 0 then leave
      end
    end
  end
  return self

::method parse
  expose intentTable intentOrder threshold ambiguityMargin beta evidenceFloor lastRepair
  use arg text
  numeric digits 12

  self~buildModel
  tokens = self~tokensOf(text)
  content = self~contentTokens(tokens)
  content = self~repair(content)
  feats = self~weightedFeatures(content, tokens)
  candidates = .Array~new
  parseRecord = self~newParseRecord(text, tokens, candidates)
  n = intentOrder~items
  if n = 0 | feats~items = 0 then return parseRecord

  sc = self~scoreFeats(feats)
  raw = .Array~new
  do i = 1 to n
    v = 0
    if sc~hasIndex(intentOrder[i]) = 1 then v = sc~at(intentOrder[i])
    raw~append(v)
  end
  maxS = raw[1]
  do i = 2 to n
    if raw[i] > maxS then maxS = raw[i]
  end
  denom = 0
  weightv = .Array~new
  do i = 1 to n
    w = self~expNeg(beta * (raw[i] - maxS))
    weightv~append(w)
    denom = denom + w
  end
  factor = maxS / evidenceFloor
  if factor > 1 then factor = 1
  if factor < 0 then factor = 0

  bestAllowed = .nil
  secondAllowed = .nil
  bestContextBlocked = .nil
  bestRegistryBlocked = .nil
  do i = 1 to n
    id = intentOrder[i]
    spec = intentTable~at(id)
    cscore = (weightv[i] / denom) * 100 * factor
    candidate = self~makeCandidate(spec, cscore, raw[i], feats)
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
  if lastRepair \== "" then parseRecord~put("REPAIRED " || lastRepair, "REPAIR")

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
  if bestAllowed~at("SCORE") < threshold then do
    parseRecord~put(bestAllowed~at("EVIDENCE"), "EVIDENCE")
    parseRecord~put(bestAllowed~at("SCORE"), "SCORE")
    return parseRecord
  end
  return self~finishMatched(parseRecord, bestAllowed, secondAllowed)

::method buildModel
  expose intentTable intentOrder modelDirty wts vocab epochs
  if modelDirty = 0 then return
  wts = .Directory~new
  vocab = .Directory~new
  per = .Array~new
  longest = 0
  do i = 1 to intentOrder~items
    id = intentOrder[i]
    spec = intentTable~at(id)
    list = .Array~new
    seen = .Directory~new
    self~collectExamples(list, seen, id, spec~at("PHRASES"))
    self~collectExamples(list, seen, id, spec~at("LEARNED_PHRASES"))
    self~collectExamples(list, seen, id, spec~at("NOUNS"))
    verbs = self~firstSegments(spec~at("VERBS"), 3)
    nouns = self~firstSegments(spec~at("NOUNS"), 3)
    do v = 1 to verbs~items
      do nn = 1 to nouns~items
        self~collectExamples(list, seen, id, verbs[v] || " " || nouns[nn])
      end
    end
    per~append(list)
    if list~items > longest then longest = list~items
  end
  /* Deterministic round-robin interleave so no intent is trained last. */
  examples = .Array~new
  do k = 1 to longest
    do i = 1 to per~items
      if k <= per[i]~items then examples~append(per[i][k])
    end
  end
  do e = 1 to epochs
    updates = 0
    do k = 1 to examples~items
      updates = updates + self~trainStep(examples[k])
    end
    if updates = 0 then leave
  end
  modelDirty = 0
  return

::method collectExamples
  use arg list, seen, id, segments
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
    ex = self~makeExample(id, segment)
    if ex == .nil then iterate
    key = ex~at("KEY")
    if seen~hasIndex(key) = 1 then iterate
    seen~put(1, key)
    list~append(ex)
  end
  return

::method firstSegments
  use arg segments, limit
  out = .Array~new
  if segments == .nil | strip(segments) == "" then return out
  remaining = segments
  do while remaining <> "" & out~items < limit
    p = pos("|", remaining)
    if p = 0 then do
      out~append(remaining)
      remaining = ""
    end
    else do
      out~append(left(remaining, p - 1))
      remaining = substr(remaining, p + 1)
    end
  end
  return out

::method makeExample
  expose vocab
  use arg id, segment
  toks = self~tokensOf(segment)
  content = self~contentTokens(toks)
  if content~items = 0 then return .nil
  key = ""
  do t = 1 to content~items
    key = key content[t]
    vocab~put(1, content[t])
  end
  ex = .Directory~new
  ex~put(id, "GOLD")
  ex~put(strip(key) || "~" || strip(segment), "KEY")
  ex~put(self~weightedFeatures(content, toks), "X")
  return ex

::method weightedFeatures
  use arg content, tokens
  raw = self~featuresOf(content)
  /* F family: adjacent pairs over the FULL utterance, stopwords included, so
     "ARE YOU" + "HUMAN" is distinguishable from "HUMAN REVIEW". */
  if arg(2, "E") = 1 then do
    prev = ""
    do i = 1 to tokens~items
      cur = tokens[i]~at("CLEAN")
      if prev \== "" then raw~put(1, "F:" || prev || "_" || cur)
      prev = cur
    end
  end
  x = .Directory~new
  f = raw~allIndexes
  do j = 1 to f~items
    x~put(self~familyWeight(left(f[j], 1)), f[j])
  end
  return x

::method scoreFeats
  expose wts
  use arg feats
  sc = .Directory~new
  f = feats~allIndexes
  do j = 1 to f~items
    feat = f[j]
    if wts~hasIndex(feat) = 0 then iterate
    x = feats~at(feat)
    m = wts~at(feat)
    ids = m~allIndexes
    do q = 1 to ids~items
      id = ids[q]
      v = m~at(id) * x
      if sc~hasIndex(id) = 1 then sc~put(sc~at(id) + v, id)
      else sc~put(v, id)
    end
  end
  return sc

::method trainStep
  expose margin
  use arg ex
  g = ex~at("GOLD")
  feats = ex~at("X")
  sc = self~scoreFeats(feats)
  sg = 0
  if sc~hasIndex(g) = 1 then sg = sc~at(g)
  bestId = ""
  bestV = -1000000
  ids = sc~allIndexes
  do q = 1 to ids~items
    if ids[q] == g then iterate
    if sc~at(ids[q]) > bestV then do
      bestV = sc~at(ids[q])
      bestId = ids[q]
    end
  end
  rival = bestV
  if rival < 0 then rival = 0
  if sg - rival >= margin then return 0
  f = feats~allIndexes
  do j = 1 to f~items
    self~bump(f[j], g, feats~at(f[j]))
    if bestId \== "" then if bestV >= 0 then self~bump(f[j], bestId, -feats~at(f[j]))
  end
  return 1

::method bump
  expose wts
  use arg feat, id, delta
  if wts~hasIndex(feat) = 0 then wts~put(.Directory~new, feat)
  m = wts~at(feat)
  if m~hasIndex(id) = 1 then m~put(m~at(id) + delta, id)
  else m~put(delta, id)
  return

/* Vocabulary repair: a content word the model has never seen is replaced by
   the unique known word within edit distance one (distance two for long
   words).  Ties are left alone.  The repair is reported in the route. */
::method repair
  expose vocab lastRepair
  use arg content
  lastRepair = ""
  out = .Array~new
  words = vocab~allIndexes
  do i = 1 to content~items
    w = content[i]
    if length(w) < 5 | vocab~hasIndex(w) = 1 then do
      out~append(w)
      iterate
    end
    limit = 1
    if length(w) >= 9 then limit = 2
    best = ""
    bestD = limit + 1
    tie = 0
    do j = 1 to words~items
      c = words[j]
      if abs(length(c) - length(w)) > limit then iterate
      d = self~editDistance(w, c, limit)
      if d < bestD then do
        bestD = d
        best = c
        tie = 0
      end
      else if d = bestD & d <= limit then tie = 1
    end
    if best \== "" then if bestD <= limit then if tie = 0 then do
      out~append(best)
      if lastRepair == "" then lastRepair = w || ">" || best
      else lastRepair = lastRepair || "," || w || ">" || best
    end
    else out~append(w)
  end
  return out

::method editDistance
  use arg a, b, limit
  la = length(a)
  lb = length(b)
  prev = .Array~new
  do j = 0 to lb
    prev~append(j)
  end
  do i = 1 to la
    cur = .Array~new
    cur~append(i)
    rowMin = i
    do j = 1 to lb
      cost = 1
      if substr(a, i, 1) == substr(b, j, 1) then cost = 0
      v = prev[j] + cost
      if prev[j + 1] + 1 < v then v = prev[j + 1] + 1
      if cur[j] + 1 < v then v = cur[j] + 1
      cur~append(v)
      if v < rowMin then rowMin = v
    end
    if rowMin > limit then return limit + 1
    prev = cur
  end
  return prev[lb + 1]

::method makeCandidate
  expose intentTable
  use arg spec, cscore, rawScore, feats
  fit = self~contextFit(spec)
  provenance = spec~at("PROVENANCE")
  reviewState = provenance~at("REVIEW_STATE")
  active = 0
  if reviewState == "APPROVED" then active = 1
  id = spec~at("ID")
  why = ""
  if cscore >= 5 then why = self~topFeatures(id, feats)
  evidence = "PERC raw=" || format(rawScore, , 2) || " why=" || why
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

/* The weights that moved this candidate, largest first.  The weight is the
   engine's own explanation: nothing is inferred after the fact. */
::method topFeatures
  expose wts
  use arg id, feats
  names = .Array~new
  vals = .Array~new
  f = feats~allIndexes
  do j = 1 to f~items
    if left(f[j], 1) == "C" then iterate
    if wts~hasIndex(f[j]) = 0 then iterate
    m = wts~at(f[j])
    if m~hasIndex(id) = 0 then iterate
    v = m~at(id) * feats~at(f[j])
    if v <= 0.2 then iterate
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

::method configure
  expose threshold ambiguityMargin
  use arg newThreshold, newAmbiguityMargin
  if arg(1, "O") = 0 then threshold = newThreshold
  if arg(2, "O") = 0 then ambiguityMargin = newAmbiguityMargin
  return self

/* Model hyper-parameters, exposed for qualification and A/B replay. */
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

::method route
  use arg text
  parsed = self~parse(text)
  routeRecord = .Directory~new
  routeRecord~put("symbolic.nlp.route/0.1", "SCHEMA")
  routeRecord~put("ONLINE_PERCEPTRON", "ENGINE")
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

::method familyWeight
  use arg fam
  if fam == "W" then return 1.0
  if fam == "B" then return 1.2
  if fam == "F" then return 0.9
  return 0.25

/* Exemplar evidence in nats: exact approved utterance, or an approved
   multi-word phrase wholly contained in a longer utterance. */
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
  r~put("ONLINE_PERCEPTRON", "ENGINE")
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
  s~put("perceptron.nlp.semantic/0.1", "SCHEMA")
  s~put("ONLINE_PERCEPTRON", "ENGINE")
  s~put(candidate~at("ID"), "INTENT")
  s~put(candidate~at("EVIDENCE"), "EVIDENCE")
  s~put(.Array~new, "RELATIONS")
  s~put("PERCEPTRON(" || candidate~at("ID") || ")", "FORM")
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
