/* RippleDownNLP.cls
   Seventh swappable NLP strategy (engine RDR / RIPPLE).

   University-archive paradigm: Ripple-Down Rules
   (Compton, Jansen, Edwards et al., University of New South Wales,
   late 1980s–1990s).  Incremental exception-based knowledge acquisition
   designed for the exact “system misclassifies → expert supplies correct
   label → system adds a local exception justified by the failing case”
   loop that this architecture already possesses.

   Structure:
     - A tree of rules.  Each rule has a set of conditions (atomic tests)
       and an intent (or UNKNOWN).
     - Classification = start at root; repeatedly descend to the first
       child whose conditions all match the utterance; when no child
       matches, return the current node’s intent.
     - Learning (addApprovedPhrase) = walk the tree with the new phrase;
       attach a new child exception under the rule that currently fires,
       using the most specific features of the phrase as conditions.
       Exact multi-word phrases become high-specificity conditions.

   Initial population: registered exact phrases and distinctive terms are
   turned into first-level rules under the root (exact phrases first).
   No global re-ranking ever occurs; every update is strictly local.

   Pure ooRexx, deterministic, same registration surface and route
   envelope.  Select with VIRTUAL_REP_NLP_ENGINE=RDR (or RIPPLE).
*/

::class RippleDownNLPParser public

::method init
  expose intentTable intentOrder conceptTable conceptOrder -
         threshold ambiguityMargin activeMode activeLanguage activeApplication -
         root modelDirty
  intentTable = .Directory~new
  intentOrder = .Array~new
  conceptTable = .Directory~new
  conceptOrder = .Array~new
  threshold = 60
  ambiguityMargin = 5
  activeMode = "ANY"
  activeLanguage = "ANY"
  activeApplication = "ANY"
  root = self~newNode("", "UNKNOWN")
  modelDirty = 1

::method version
  return "0.1-dev1-rippledown"

::method strategyName
  return "RIPPLE_DOWN_RULES"

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
  expose intentTable modelDirty root
  use arg intentId, phraseTerms
  intentId = translate(strip(intentId))
  if intentTable~hasIndex(intentId) = 0 then raise syntax 93.900 array("Unknown intent:" intentId)
  normalized = self~normalizeTerms(phraseTerms)
  if normalized == "" then return self
  spec = intentTable~at(intentId)
  learned = spec~at("LEARNED_PHRASES")
  if learned == "" then spec~put(normalized, "LEARNED_PHRASES")
  else spec~put(learned || "|" || normalized, "LEARNED_PHRASES")

  /* Incremental RDR update: walk the tree with this phrase, then attach
     a new exception child under the node that currently fires. */
  self~buildModel          /* ensure initial rules exist */
  tokens = self~tokensOf(phraseTerms)
  content = self~contentTokens(tokens)
  qset = self~tokenSet(content)
  path = self~classifyPath(qset, phraseTerms)
  parent = path~at(path~items)   /* last node on the path = current winner */
  conditions = self~makeConditions(content, phraseTerms)
  if conditions~items > 0 then do
    child = self~newNode(conditions, intentId)
    children = parent~at("CHILDREN")
    children~append(child)
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

/* ------------------------------------------------------------ RDR core */

::method newNode
  use arg conditions, intent
  node = .Directory~new
  if conditions~isA(.String) then do
    /* allow passing a single condition string or an array */
    if conditions == "" then node~put(.Array~new, "CONDITIONS")
    else do
      a = .Array~new
      a~append(conditions)
      node~put(a, "CONDITIONS")
    end
  end
  else node~put(conditions, "CONDITIONS")
  node~put(intent, "INTENT")
  node~put(.Array~new, "CHILDREN")
  return node

::method buildModel
  expose intentTable intentOrder root modelDirty
  if modelDirty = 0 then return
  /* Rebuild a clean first-level rule set from registered knowledge.
     Exact / learned phrases become high-specificity rules; distinctive
     single terms become lower-specificity rules.  Order = exact first. */
  root = self~newNode("", "UNKNOWN")
  children = root~at("CHILDREN")

  /* Exact phrases first (highest specificity). */
  do i = 1 to intentOrder~items
    id = intentOrder[i]
    spec = intentTable~at(id)
    self~addPhraseRules(children, id, spec~at("PHRASES"), "EXACT")
    self~addPhraseRules(children, id, spec~at("LEARNED_PHRASES"), "EXACT")
  end
  /* Then distinctive single terms from verbs/nouns as CONTAINS rules.
     Broad terms are filtered.  Order after exacts so exacts win first. */
  do i = 1 to intentOrder~items
    id = intentOrder[i]
    spec = intentTable~at(id)
    self~addTermRules(children, id, spec~at("VERBS"))
    self~addTermRules(children, id, spec~at("NOUNS"))
  end
  modelDirty = 0

::method addPhraseRules
  use arg children, intentId, termString, kind
  if termString == "" | termString == .nil then return
  s = translate(termString, " ", "|")
  if words(s) > 1 then do
    cond = "EXACT:" || translate(s, "_", " ")
    node = self~newNode(cond, intentId)
    children~append(node)
  end
  else if words(s) = 1 then do
    t = subword(s, 1, 1)
    if t \== "" then if self~isBroad(t) = 0 then do
      /* single-word phrase → exact match only (not contains) */
      cond = "EXACT:" || t
      node = self~newNode(cond, intentId)
      children~append(node)
    end
  end

::method addTermRules
  use arg children, intentId, termString
  if termString == "" | termString == .nil then return
  s = translate(termString, " ", "|")
  do position = 1 to words(s)
    t = subword(s, position, 1)
    if t == "" then iterate
    /* skip extremely common terms that would fire too broadly */
    if self~isBroad(t) = 1 then iterate
    cond = "CONTAINS:" || t
    node = self~newNode(cond, intentId)
    children~append(node)
  end

::method isBroad
  use arg term
  broad = " TOKEN TOKENS ACCOUNT DATA SUPPORT HELP API PRICE COST USAGE BILL BILLING "
  if pos(" " || term || " ", broad) > 0 then return 1
  return 0

::method makeConditions
  use arg content, rawText
  conditions = .Array~new
  qnorm = self~normalizeTerms(rawText)
  if words(translate(qnorm, " ", "|")) > 1 then do
    conditions~append("EXACT:" || translate(qnorm, "_", "|"))
  end
  do i = 1 to content~items
    if self~isBroad(content[i]) = 0 then -
      conditions~append("CONTAINS:" || content[i])
  end
  return conditions

::method tokenSet
  use arg content
  set = .Directory~new
  do i = 1 to content~items
    set~put(1, content[i])
  end
  return set

::method conditionsMatch
  use arg conditions, qset, rawText
  if conditions~items = 0 then return 1   /* empty = always true (root) */
  qnorm = self~normalizeTerms(rawText)
  qexact = translate(qnorm, "_", "|")
  do i = 1 to conditions~items
    cond = conditions[i]
    if left(cond, 8) == "CONTAINS" then do
      term = substr(cond, 10)
      if qset~hasIndex(term) = 0 then return 0
    end
    else if left(cond, 5) == "EXACT" then do
      phrase = substr(cond, 7)
      if qexact \= phrase then return 0
    end
    else return 0
  end
  return 1

::method classifyPath
  /* Returns the array of nodes visited (root … final). */
  expose root
  use arg qset, rawText
  path = .Array~new
  node = root
  path~append(node)
  do forever
    children = node~at("CHILDREN")
    next = .nil
    do i = 1 to children~items
      child = children[i]
      if self~conditionsMatch(child~at("CONDITIONS"), qset, rawText) = 1 then do
        next = child
        leave
      end
    end
    if next == .nil then leave
    node = next
    path~append(node)
  end
  return path

/* ------------------------------------------------------------ routing */

::method route
  expose intentTable root threshold modelDirty
  use arg text
  numeric digits 12
  self~buildModel

  tokens = self~tokensOf(text)
  content = self~contentTokens(tokens)
  qset = self~tokenSet(content)
  path = self~classifyPath(qset, text)
  finalNode = path~at(path~items)
  winner = finalNode~at("INTENT")

  /* Build a human-readable path for the evidence string. */
  pathStr = ""
  do i = 1 to path~items
    n = path[i]
    conds = n~at("CONDITIONS")
    cstr = ""
    do j = 1 to conds~items
      if cstr == "" then cstr = conds[j]
      else cstr = cstr || "&" || conds[j]
    end
    if cstr == "" then cstr = "ROOT"
    if pathStr == "" then pathStr = cstr
    else pathStr = pathStr || " -> " || cstr
  end

  routeRecord = .Directory~new
  routeRecord~put("symbolic.nlp.route/0.1", "SCHEMA")
  routeRecord~put("RIPPLE_DOWN_RULES", "ENGINE")
  routeRecord~put(text, "TEXT")
  routeRecord~put(.Array~new, "CANDIDATES")
  routeRecord~put(.Directory~new, "ACTIVE_CONTEXT")
  routeRecord~put(0, "ROUTABLE")
  routeRecord~put(.Directory~new, "TASK")
  routeRecord~put(.Directory~new, "PRESENTATION")
  routeRecord~put(.Directory~new, "BLOCKED_TASK")

  if winner == "UNKNOWN" | winner == "" then do
    routeRecord~put("UNKNOWN", "STATUS")
    routeRecord~put("NONE", "REFERRAL_STATUS")
    routeRecord~put("", "INTENT")
    routeRecord~put("POSITIVE", "POLARITY")
    routeRecord~put(0, "COMPLETE")
    routeRecord~put(.Array~new, "NEEDS")
    routeRecord~put(.Directory~new, "ARGUMENTS")
    routeRecord~put(.Directory~new, "SEMANTIC")
    routeRecord~put("rdr: " || pathStr, "EVIDENCE")
    routeRecord~put(0, "SCORE")
    routeRecord~put(0, "MARGIN")
    return routeRecord
  end

  /* Registration / approval check. */
  if intentTable~hasIndex(winner) = 0 then do
    routeRecord~put("UNKNOWN", "STATUS")
    routeRecord~put("NONE", "REFERRAL_STATUS")
    routeRecord~put("", "INTENT")
    routeRecord~put("rdr: unknown intent " || winner, "EVIDENCE")
    routeRecord~put(0, "SCORE")
    routeRecord~put(0, "MARGIN")
    return routeRecord
  end
  spec = intentTable~at(winner)
  provenance = spec~at("PROVENANCE")
  reviewState = provenance~at("REVIEW_STATE")
  if reviewState \== "APPROVED" then do
    routeRecord~put("UNKNOWN", "STATUS")
    routeRecord~put("NONE", "REFERRAL_STATUS")
    routeRecord~put("", "INTENT")
    routeRecord~put("rdr: intent not APPROVED", "EVIDENCE")
    routeRecord~put(0, "SCORE")
    routeRecord~put(0, "MARGIN")
    return routeRecord
  end

  /* Specificity proxy: EXACT conditions or deeper exception paths score higher.
     Pure single CONTAINS at depth 1 stays below threshold → UNKNOWN. */
  depth = path~items - 1
  ncond = finalNode~at("CONDITIONS")~items
  hasExact = 0
  conds = finalNode~at("CONDITIONS")
  do j = 1 to conds~items
    if left(conds[j], 5) == "EXACT" then hasExact = 1
  end
  score = 40 + (depth * 20) + (ncond * 8)
  if hasExact = 1 then score = score + 30
  if score > 99 then score = 99

  /* Require either an EXACT condition or a real exception depth before
     claiming MATCHED.  Pure depth-1 CONTAINS is treated as UNKNOWN so
     that broad term rules do not produce confident wrongs. */
  if hasExact = 0 then if depth <= 1 then do
    routeRecord~put("UNKNOWN", "STATUS")
    routeRecord~put("NONE", "REFERRAL_STATUS")
    routeRecord~put("", "INTENT")
    routeRecord~put("rdr: no exact / shallow " || pathStr, "EVIDENCE")
    routeRecord~put(score, "SCORE")
    routeRecord~put(0, "MARGIN")
    return routeRecord
  end

  if score < threshold then do
    routeRecord~put("UNKNOWN", "STATUS")
    routeRecord~put("NONE", "REFERRAL_STATUS")
    routeRecord~put("", "INTENT")
    routeRecord~put("rdr: low specificity " || pathStr, "EVIDENCE")
    routeRecord~put(score, "SCORE")
    routeRecord~put(0, "MARGIN")
    return routeRecord
  end

  evidence = "RDR path=" || pathStr
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
  s~put("rippledown.nlp.semantic/0.1", "SCHEMA")
  s~put("RIPPLE_DOWN_RULES", "ENGINE")
  s~put(winner, "INTENT")
  s~put(evidence, "EVIDENCE")
  s~put(.Array~new, "RELATIONS")
  s~put("RDR(" || winner || ")", "FORM")
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
