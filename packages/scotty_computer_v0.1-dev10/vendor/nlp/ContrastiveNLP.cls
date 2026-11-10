/* ContrastiveNLP.cls
   Alternate deterministic NLP strategy for the virtual representative.

   It implements the same registration and route envelope used by
   SymbolicNLPParser, but it does not use verb-before-noun symbolic scoring.
   Instead, approved intent vocabulary and phrases form per-intent feature sets
   and utterance exemplars.  Query features vote contrastively: terms appearing
   in many intents are down-weighted, while distinctive terms carry more weight.
   Approved learned phrases participate as exemplars.  Repeated identical rows
   do not multiply authority because scoring uses feature sets and the single
   best exemplar match.
*/

::class ContrastiveNLPParser public

::method init
  expose intentTable intentOrder conceptTable conceptOrder threshold ambiguityMargin activeMode activeLanguage activeApplication
  intentTable = .Directory~new
  intentOrder = .Array~new
  conceptTable = .Directory~new
  conceptOrder = .Array~new
  threshold = 60
  ambiguityMargin = 12
  activeMode = "ANY"
  activeLanguage = "ANY"
  activeApplication = "ANY"

::method version
  return "0.1-dev1-contrastive"

::method strategyName
  return "CONTRASTIVE_EXEMPLAR"

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
  expose conceptTable conceptOrder
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
  expose intentTable intentOrder
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
  expose intentTable
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
  return self

::method addApprovedPhrase
  expose intentTable
  use arg intentId, phraseTerms
  intentId = translate(strip(intentId))
  if intentTable~hasIndex(intentId) = 0 then raise syntax 93.900 array("Unknown intent:" intentId)
  normalized = self~normalizeTerms(phraseTerms)
  if normalized == "" then return self
  spec = intentTable~at(intentId)
  existing = spec~at("PHRASES")
  if existing == "" then spec~put(normalized, "PHRASES")
  else spec~put(existing || "|" || normalized, "PHRASES")
  learned = spec~at("LEARNED_PHRASES")
  if learned == .nil | learned == "" then spec~put(normalized, "LEARNED_PHRASES")
  else spec~put(learned || "|" || normalized, "LEARNED_PHRASES")
  return self

/* Preserved registration surface.  The representative does not currently use
   slots, but keeping them in the registry lets a future adapter inspect the same
   vocabulary description without changing callers. */
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
  return self~contrastiveTokens(text)

::method parse
  expose intentTable intentOrder threshold ambiguityMargin
  use arg text

  tokens = self~contrastiveTokens(text)
  dfMap = self~buildDocumentFrequency
  candidates = .Array~new
  bestAllowed = .nil
  secondAllowed = .nil
  bestContextBlocked = .nil
  bestRegistryBlocked = .nil

  do i = 1 to intentOrder~items
    spec = intentTable~at(intentOrder[i])
    candidate = self~scoreContrastive(spec, tokens, dfMap)
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

  parseRecord = self~newParseRecord(text, tokens, candidates)

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
  if bestAllowed~at("SCORE") < threshold then return parseRecord
  return self~finishMatched(parseRecord, bestAllowed, secondAllowed)

::method route
  use arg text
  parsed = self~parse(text)
  routeRecord = .Directory~new
  routeRecord~put("symbolic.nlp.route/0.1", "SCHEMA")
  routeRecord~put("CONTRASTIVE_EXEMPLAR", "ENGINE")
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

::method scoreContrastive
  use arg spec, tokens, dfMap
  querySet = self~tokenSetFromTokens(tokens)
  featureSet = self~specFeatureSet(spec)
  totalWeight = 0
  matchedWeight = 0
  matchedCount = 0
  rareCount = 0
  matchedTerms = ""

  q = querySet~allIndexes
  do i = 1 to q~items
    term = q[i]
    weight = self~featureWeight(term, dfMap)
    totalWeight = totalWeight + weight
    if featureSet~hasIndex(term) = 1 then do
      matchedWeight = matchedWeight + weight
      matchedCount = matchedCount + 1
      if self~dfValue(dfMap, term) <= 2 then rareCount = rareCount + 1
      if matchedTerms == "" then matchedTerms = term
      else matchedTerms = matchedTerms || "," || term
    end
  end

  lexicalScore = 0
  if totalWeight > 0 then lexicalScore = (matchedWeight * 100) / totalWeight
  phraseScore = self~bestExemplarScore(spec~at("PHRASES"), querySet, dfMap)
  learnedScore = self~bestExemplarScore(spec~at("LEARNED_PHRASES"), querySet, dfMap)
  if learnedScore >= 99.5 then learnedScore = 115
  else if learnedScore >= 80 then learnedScore = learnedScore + 8

  /* Lexical overlap is deliberately not authoritative by itself: broad words
     such as HUMAN, TOKEN, ACCOUNT and API occur in several intents.  Phrase
     shape and learned exemplars provide the contrast needed to break those
     collisions. */
  score = lexicalScore * 0.60
  phraseComposite = lexicalScore * 0.30 + phraseScore * 0.70
  learnedComposite = lexicalScore * 0.20 + learnedScore * 0.80
  if phraseComposite > score then score = phraseComposite
  if learnedComposite > score then score = learnedComposite
  if matchedCount >= 2 then score = score + 4
  if rareCount >= 2 then score = score + 4
  if lexicalScore >= 40 then if phraseScore >= 45 then score = score + 2
  if lexicalScore >= 40 then if learnedScore >= 45 then score = score + 2
  if score > 120 then score = 120

  fit = self~contextFit(spec)
  provenance = spec~at("PROVENANCE")
  reviewState = provenance~at("REVIEW_STATE")
  active = 0
  if reviewState == "APPROVED" then active = 1

  evidence = "CONTRASTIVE lexical=" || self~oneDecimal(lexicalScore) || -
      " phrase=" || self~oneDecimal(phraseScore) || -
      " learned=" || self~oneDecimal(learnedScore) || -
      " matched=" || matchedTerms

  candidate = .Directory~new
  candidate~put(spec~at("ID"), "ID")
  candidate~put(score, "SCORE")
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

::method newParseRecord
  use arg text, tokens, candidates
  r = .Directory~new
  r~put("symbolic.nlp.parse/0.3", "SCHEMA")
  r~put("CONTRASTIVE_EXEMPLAR", "ENGINE")
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
  s~put("contrastive.nlp.semantic/0.1", "SCHEMA")
  s~put("CONTRASTIVE_EXEMPLAR", "ENGINE")
  s~put(candidate~at("ID"), "INTENT")
  s~put(candidate~at("EVIDENCE"), "EVIDENCE")
  s~put(.Array~new, "RELATIONS")
  s~put("CONTRASTIVE(" || candidate~at("ID") || ")", "FORM")
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

::method contrastiveTokens
  use arg text
  tokens = .Array~new
  do position = 1 to words(text)
    raw = subword(text, position, 1)
    clean = self~cleanWord(raw)
    if clean == "" then iterate
    t = .Directory~new
    t~put(raw, "RAW")
    t~put(clean, "CLEAN")
    t~put(self~canonical(clean), "CANONICAL")
    t~put(position, "POSITION")
    t~put(tokens~items + 1, "INDEX")
    t~put("FEATURE", "MATCH")
    t~put(clean, "RESOLVED")
    t~put("", "ROLES")
    tokens~append(t)
  end
  return tokens

::method tokenSetFromTokens
  use arg tokens
  set = .Directory~new
  do i = 1 to tokens~items
    term = tokens[i]~at("CANONICAL")
    if term == "" then iterate
    if self~isStopword(term) = 1 then iterate
    set~put(1, term)
  end
  if set~items = 0 then do i = 1 to tokens~items
    term = tokens[i]~at("CANONICAL")
    if term <> "" then set~put(1, term)
  end
  return set

::method specFeatureSet
  use arg spec
  set = .Directory~new
  fields = .Array~of("VERBS", "NOUNS", "PHRASES", "LEARNED_PHRASES")
  do i = 1 to fields~items
    self~addTextFeatures(set, spec~at(fields[i]))
  end
  return set

::method addTextFeatures
  use arg set, text
  if text == .nil | strip(text) == "" then return
  remaining = text
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
    do i = 1 to words(segment)
      term = self~canonical(self~cleanWord(subword(segment, i, 1)))
      if term == "" then iterate
      if self~isStopword(term) = 1 then iterate
      set~put(1, term)
    end
  end
  return

::method bestExemplarScore
  use arg text, querySet, dfMap
  if text == .nil | strip(text) == "" then return 0
  best = 0
  remaining = text
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
    exemplar = .Directory~new
    self~addTextFeatures(exemplar, segment)
    score = self~weightedDice(querySet, exemplar, dfMap)
    if score > best then best = score
  end
  return best

::method weightedDice
  use arg leftSet, rightSet, dfMap
  if leftSet~items = 0 | rightSet~items = 0 then return 0
  leftWeight = self~setWeight(leftSet, dfMap)
  rightWeight = self~setWeight(rightSet, dfMap)
  commonWeight = 0
  terms = leftSet~allIndexes
  do i = 1 to terms~items
    if rightSet~hasIndex(terms[i]) = 1 then commonWeight = commonWeight + self~featureWeight(terms[i], dfMap)
  end
  if leftWeight + rightWeight = 0 then return 0
  return (2 * commonWeight * 100) / (leftWeight + rightWeight)

::method setWeight
  use arg set, dfMap
  total = 0
  terms = set~allIndexes
  do i = 1 to terms~items
    total = total + self~featureWeight(terms[i], dfMap)
  end
  return total

::method featureWeight
  use arg term, dfMap
  df = self~dfValue(dfMap, term)
  if df <= 0 then return 35
  weight = 100 / df
  if weight < 8 then weight = 8
  return weight

::method dfValue
  use arg dfMap, term
  if dfMap~hasIndex(term) = 0 then return 0
  return dfMap~at(term)

::method buildDocumentFrequency
  expose intentTable intentOrder
  dfMap = .Directory~new
  do i = 1 to intentOrder~items
    features = self~specFeatureSet(intentTable~at(intentOrder[i]))
    terms = features~allIndexes
    do j = 1 to terms~items
      term = terms[j]
      if dfMap~hasIndex(term) = 0 then dfMap~put(1, term)
      else dfMap~put(dfMap~at(term) + 1, term)
    end
  end
  return dfMap

::method cleanWord
  use arg raw
  upper = translate(raw)
  clean = ""
  do i = 1 to length(upper)
    ch = substr(upper, i, 1)
    if pos(ch, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_") > 0 then clean = clean || ch
  end
  return clean

::method canonical
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
  stop = " A AN THE ME MY I YOU YOUR PLEASE CAN COULD WOULD SHOULD DO DOES DID IS ARE AM TO OF FOR IN ON WITH AND OR IT THIS THAT BE BEEN ABOUT HOW WHAT WHY WHICH WHEN WHERE WHO MORE MUCH MANY HAVE HAS HAD FROM AS AT BY INTO THAN THEN JUST STILL REALLY VERY FULL EXACT "
  if pos(" " || term || " ", stop) > 0 then return 1
  return 0

::method isNegated
  use arg tokens
  do i = 1 to tokens~items
    term = tokens[i]~at("CLEAN")
    if term == "NO" | term == "NOT" | term == "NEVER" | term == "DONT" then return 1
  end
  return 0

::method oneDecimal
  use arg value
  return format(value, , 1)

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
