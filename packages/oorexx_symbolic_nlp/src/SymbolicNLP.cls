/* SymbolicNLP.cls
   Small deterministic symbolic NLP / semantic intent parser for ooRexx.

   Command owners register the vocabulary and argument grammar they own.
   The parser returns evidence, polarity, slots and a compact semantic form.
   It deliberately does not execute commands and grants no authority.
*/

::class SymbolicNLPParser public

::method init
  expose intentTable intentOrder conceptTable conceptOrder lexicon soundexIndex negators threshold ambiguityMargin

  intentTable = .Directory~new
  intentOrder = .Array~new
  conceptTable = .Directory~new
  conceptOrder = .Array~new
  lexicon = .Directory~new
  soundexIndex = .Directory~new
  negators = .Directory~new

  threshold = 60
  ambiguityMargin = 12

  negators~put(1, "NO")
  negators~put(1, "NOT")
  negators~put(1, "NEVER")
  negators~put(1, "DONT")

::method version
  return "0.1-dev2"

::method configure
  expose threshold ambiguityMargin
  use arg newThreshold, newAmbiguityMargin

  if arg(1, "O") = 0 then threshold = newThreshold
  if arg(2, "O") = 0 then ambiguityMargin = newAmbiguityMargin
  return self

/* Register a reusable semantic concept.  Terms are alternatives separated by |.
   Example: registerConcept("CREATE", "VERB", "CREATE|MAKE|DEFINE") */
::method registerConcept
  expose conceptTable conceptOrder
  use arg conceptId, role, terms

  conceptId = translate(strip(conceptId))
  role = translate(strip(role))
  terms = self~normalizeTerms(terms)

  if conceptId == "" then raise syntax 93.900 array("Concept id must not be empty")
  if role \== "VERB" then do
    if role \== "NOUN" then raise syntax 93.900 array("Concept role must be VERB or NOUN")
  end
  if terms == "" then raise syntax 93.900 array("Concept must register at least one term")
  if conceptTable~hasIndex(conceptId) = 1 then raise syntax 93.900 array("Concept already registered:" conceptId)

  spec = .Directory~new
  spec~put(conceptId, "ID")
  spec~put(role, "ROLE")
  spec~put(terms, "TERMS")
  conceptTable~put(spec, conceptId)
  conceptOrder~append(conceptId)

  self~registerTerms(terms, role)
  return self

/* Register an intent in terms of reusable verb/noun concepts. */
::method registerSemanticIntent
  expose intentTable
  use arg intentId, verbConcepts, nounConcepts, phraseTerms, priority

  if arg(4, "O") = 1 then phraseTerms = ""
  if arg(5, "O") = 1 then priority = 0

  normalizedVerbs = self~normalizeConceptIds(verbConcepts)
  normalizedNouns = self~normalizeConceptIds(nounConcepts)
  verbTerms = self~expandConceptTerms(normalizedVerbs, "VERB")
  nounTerms = self~expandConceptTerms(normalizedNouns, "NOUN")

  self~registerIntent(intentId, verbTerms, nounTerms, phraseTerms, priority)
  intentId = translate(strip(intentId))
  spec = intentTable~at(intentId)
  spec~put(normalizedVerbs, "VERB_CONCEPTS")
  spec~put(normalizedNouns, "NOUN_CONCEPTS")
  return self

/* Compatibility surface from dev1.  Raw terms remain valid. */
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
  spec~put(priority, "PRIORITY")
  spec~put(.Array~new, "SLOTS")
  spec~put("", "VERB_CONCEPTS")
  spec~put("", "NOUN_CONCEPTS")

  if intentTable~hasIndex(intentId) = 0 then intentOrder~append(intentId)
  intentTable~put(spec, intentId)

  self~registerTerms(spec~at("VERBS"), "VERB")
  self~registerTerms(spec~at("NOUNS"), "NOUN")
  self~registerTerms(spec~at("PHRASES"), "PHRASE")
  return self

/* Modes:
      NEXT   one token after the marker
      REST   all remaining text after the marker
      PHRASE a quoted phrase, or text through the next configured stop marker

   stopMarkers is an optional | separated list.  It matters only to PHRASE.
*/
::method registerSlot
  expose intentTable
  use arg intentId, slotName, markers, mode, required, stopMarkers

  if arg(4, "O") = 1 then mode = "NEXT"
  if arg(5, "O") = 1 then required = 0
  if arg(6, "O") = 1 then stopMarkers = ""

  intentId = translate(strip(intentId))
  slotName = translate(strip(slotName))
  mode = translate(strip(mode))

  if intentTable~hasIndex(intentId) = 0 then raise syntax 93.900 array("Unknown intent:" intentId)
  if slotName == "" then raise syntax 93.900 array("Slot name must not be empty")
  if mode \== "NEXT" then do
    if mode \== "REST" then do
      if mode \== "PHRASE" then raise syntax 93.900 array("Slot mode must be NEXT, REST or PHRASE")
    end
  end

  normalizedMarkers = self~normalizeTerms(markers)
  if normalizedMarkers == "" then raise syntax 93.900 array("Slot must register at least one marker")

  slot = .Directory~new
  slot~put(slotName, "NAME")
  slot~put(normalizedMarkers, "MARKERS")
  slot~put(mode, "MODE")
  slot~put(required, "REQUIRED")
  slot~put(self~normalizeTerms(stopMarkers), "STOP_MARKERS")

  intentTable~at(intentId)~at("SLOTS")~append(slot)
  self~registerTerms(slot~at("MARKERS"), "SLOT_MARKER")
  self~registerTerms(slot~at("STOP_MARKERS"), "SLOT_STOP")
  return self

::method parse
  expose intentTable intentOrder negators threshold ambiguityMargin
  use arg text

  tokens = self~examine(text)
  candidates = .Array~new
  best = .nil
  second = .nil

  do i = 1 to intentOrder~items
    intentId = intentOrder~at(i)
    spec = intentTable~at(intentId)
    candidate = self~scoreIntent(spec, tokens)
    candidates~append(candidate)

    if best == .nil then do
      best = candidate
      iterate
    end

    if self~candidateBetter(candidate, best) = 1 then do
      second = best
      best = candidate
    end
    else do
      if second == .nil then second = candidate
      else if self~candidateBetter(candidate, second) = 1 then second = candidate
    end
  end

  parseRecord = .Directory~new
  parseRecord~put("symbolic.nlp.parse/0.2", "SCHEMA")
  parseRecord~put(text, "TEXT")
  parseRecord~put(tokens, "TOKENS")
  parseRecord~put(candidates, "CANDIDATES")
  parseRecord~put(.Directory~new, "SEMANTIC")
  parseRecord~put("", "LOGICAL_FORM")
  parseRecord~put(0, "COMPLETE")

  if best == .nil then do
    parseRecord~put("POSITIVE", "POLARITY")
    parseRecord~put(0, "NEGATED")
    parseRecord~put("UNKNOWN", "STATUS")
    parseRecord~put("", "INTENT")
    parseRecord~put(0, "SCORE")
    parseRecord~put(0, "MARGIN")
    parseRecord~put(.Directory~new, "SLOTS")
    parseRecord~put("", "MISSING_SLOTS")
    return parseRecord
  end

  negated = self~isNegated(tokens, negators, best~at("VERB_INDEX"))
  parseRecord~put(negated, "NEGATED")
  if negated = 1 then parseRecord~put("NEGATED", "POLARITY")
  else parseRecord~put("POSITIVE", "POLARITY")

  bestScore = best~at("SCORE")
  if second == .nil then margin = bestScore
  else margin = bestScore - second~at("SCORE")

  parseRecord~put(bestScore, "SCORE")
  parseRecord~put(margin, "MARGIN")
  parseRecord~put(best~at("EVIDENCE"), "EVIDENCE")

  if bestScore < threshold then do
    parseRecord~put("UNKNOWN", "STATUS")
    parseRecord~put("", "INTENT")
    parseRecord~put(.Directory~new, "SLOTS")
    parseRecord~put("", "MISSING_SLOTS")
    return parseRecord
  end

  parseRecord~put(best~at("ID"), "INTENT")
  if second \== .nil then do
    if margin < ambiguityMargin then parseRecord~put("AMBIGUOUS", "STATUS")
    else parseRecord~put("MATCHED", "STATUS")
  end
  else parseRecord~put("MATCHED", "STATUS")

  slotRecord = self~extractSlots(intentTable~at(best~at("ID")), tokens)
  parseRecord~put(slotRecord~at("VALUES"), "SLOTS")
  parseRecord~put(slotRecord~at("MISSING"), "MISSING_SLOTS")
  if slotRecord~at("MISSING") == "" then parseRecord~put(1, "COMPLETE")

  semantic = self~buildSemantic(best, parseRecord, slotRecord)
  parseRecord~put(semantic, "SEMANTIC")
  parseRecord~put(semantic~at("FORM"), "LOGICAL_FORM")
  return parseRecord

::method examine
  expose lexicon soundexIndex
  use arg text

  tokens = .Array~new
  wordCount = words(text)

  do position = 1 to wordCount
    raw = subword(text, position, 1)
    clean = self~cleanWord(raw)
    if clean == "" then iterate

    token = .Directory~new
    token~put(raw, "RAW")
    token~put(clean, "CLEAN")
    token~put(position, "POSITION")
    token~put(tokens~items + 1, "INDEX")
    token~put("UNKNOWN", "MATCH")
    token~put(clean, "RESOLVED")
    token~put("", "ROLES")

    if lexicon~hasIndex(clean) = 1 then do
      entry = lexicon~at(clean)
      token~put("EXACT", "MATCH")
      token~put(clean, "RESOLVED")
      token~put(entry~at("ROLES"), "ROLES")
    end
    else do
      sx = self~soundex(clean)
      if soundexIndex~hasIndex(sx) = 1 then do
        bucket = soundexIndex~at(sx)
        if bucket~items = 1 then do
          resolved = bucket~at(1)
          entry = lexicon~at(resolved)
          token~put("SOUNDEX", "MATCH")
          token~put(resolved, "RESOLVED")
          token~put(entry~at("ROLES"), "ROLES")
        end
      end
    end

    tokens~append(token)
  end

  return tokens

::method intentIds
  expose intentOrder
  copy = .Array~new
  do i = 1 to intentOrder~items
    copy~append(intentOrder~at(i))
  end
  return copy

::method conceptIds
  expose conceptOrder
  copy = .Array~new
  do i = 1 to conceptOrder~items
    copy~append(conceptOrder~at(i))
  end
  return copy

::method scoreIntent private
  use arg spec, tokens

  verb = self~bestTermMatch(tokens, spec~at("VERBS"))
  noun = self~bestTermMatch(tokens, spec~at("NOUNS"))
  phrase = self~bestPhraseMatch(tokens, spec~at("PHRASES"))
  slotSignal = self~scoreSlotSignals(spec, tokens)

  verbScore = 0
  nounScore = 0
  phraseScore = 0
  orderScore = 0
  evidence = ""

  if verb~at("MATCH") == "EXACT" then verbScore = 50
  else if verb~at("MATCH") == "SOUNDEX" then verbScore = 34

  if noun~at("MATCH") == "EXACT" then nounScore = 35
  else if noun~at("MATCH") == "SOUNDEX" then nounScore = 22

  if phrase~at("MATCH") == "EXACT" then phraseScore = 15

  if verbScore > 0 then do
    if nounScore > 0 then do
      if verb~at("INDEX") < noun~at("INDEX") then orderScore = 10
    end
  end

  if verbScore > 0 then evidence = evidence || "VERB " || verb~at("TERM") || " " || verb~at("MATCH") || " +" || verbScore || "; "
  if nounScore > 0 then evidence = evidence || "NOUN " || noun~at("TERM") || " " || noun~at("MATCH") || " +" || nounScore || "; "
  if phraseScore > 0 then evidence = evidence || "PHRASE " || phrase~at("TERM") || " +" || phraseScore || "; "
  if orderScore > 0 then evidence = evidence || "VERB_BEFORE_NOUN +" || orderScore || "; "
  if slotSignal~at("EVIDENCE") \== "" then evidence = evidence || slotSignal~at("EVIDENCE")

  candidate = .Directory~new
  candidate~put(spec~at("ID"), "ID")
  candidate~put(verbScore + nounScore + phraseScore + orderScore + slotSignal~at("SCORE"), "SCORE")
  candidate~put(spec~at("PRIORITY"), "PRIORITY")
  candidate~put(strip(evidence), "EVIDENCE")
  candidate~put(verb~at("POSITION"), "VERB_POSITION")
  candidate~put(verb~at("INDEX"), "VERB_INDEX")
  candidate~put(verb~at("TERM"), "VERB_TERM")
  candidate~put(verb~at("MATCH"), "VERB_MATCH")
  candidate~put(noun~at("POSITION"), "NOUN_POSITION")
  candidate~put(noun~at("INDEX"), "NOUN_INDEX")
  candidate~put(noun~at("TERM"), "NOUN_TERM")
  candidate~put(noun~at("MATCH"), "NOUN_MATCH")
  candidate~put(self~resolveConcept(spec~at("VERB_CONCEPTS"), verb~at("TERM"), "VERB"), "VERB_CONCEPT")
  candidate~put(self~resolveConcept(spec~at("NOUN_CONCEPTS"), noun~at("TERM"), "NOUN"), "NOUN_CONCEPT")
  return candidate

::method scoreSlotSignals private
  use arg spec, tokens

  score = 0
  evidence = ""
  slots = spec~at("SLOTS")

  do i = 1 to slots~items
    slot = slots~at(i)
    binding = self~extractSlotBinding(tokens, slot)
    if binding~at("FOUND") = 1 then do
      if slot~at("REQUIRED") = 1 then points = 12
      else points = 6
      score = score + points
      evidence = evidence || "SLOT " || slot~at("NAME") || " MARKER " || binding~at("MARKER") || " +" || points || "; "
    end
    else do
      if slot~at("REQUIRED") = 1 then do
        score = score - 12
        evidence = evidence || "REQUIRED_SLOT " || slot~at("NAME") || " MISSING -12; "
      end
    end
  end

  signal = .Directory~new
  signal~put(score, "SCORE")
  signal~put(evidence, "EVIDENCE")
  return signal

::method candidateBetter private
  use arg leftCandidate, rightCandidate

  if leftCandidate~at("SCORE") > rightCandidate~at("SCORE") then return 1
  if leftCandidate~at("SCORE") < rightCandidate~at("SCORE") then return 0
  if leftCandidate~at("PRIORITY") > rightCandidate~at("PRIORITY") then return 1
  return 0

::method bestTermMatch private
  use arg tokens, termsText

  best = self~emptyMatch
  terms = self~splitTerms(termsText)

  do t = 1 to terms~items
    term = terms~at(t)
    termWords = words(term)

    if termWords > 1 then do
      phraseMatch = self~findPhrase(tokens, term)
      if phraseMatch~at("MATCH") == "EXACT" then return phraseMatch
      iterate
    end

    do i = 1 to tokens~items
      token = tokens~at(i)
      if token~at("CLEAN") == term then return self~tokenMatch("EXACT", term, token)
    end

    do i = 1 to tokens~items
      token = tokens~at(i)
      if token~at("MATCH") == "SOUNDEX" then do
        if token~at("RESOLVED") == term then do
          if best~at("MATCH") == "NONE" then best = self~tokenMatch("SOUNDEX", term, token)
        end
      end
    end
  end

  return best

::method tokenMatch private
  use arg matchKind, term, token

  match = .Directory~new
  match~put(matchKind, "MATCH")
  match~put(term, "TERM")
  match~put(token~at("POSITION"), "POSITION")
  match~put(token~at("INDEX"), "INDEX")
  match~put(token~at("POSITION"), "END_POSITION")
  match~put(token~at("INDEX"), "END_INDEX")
  return match

::method bestPhraseMatch private
  use arg tokens, termsText

  terms = self~splitTerms(termsText)
  do i = 1 to terms~items
    term = terms~at(i)
    if words(term) < 2 then iterate
    match = self~findPhrase(tokens, term)
    if match~at("MATCH") == "EXACT" then return match
  end
  return self~emptyMatch

::method findPhrase private
  use arg tokens, phrase

  phraseWords = words(phrase)
  if phraseWords = 0 then return self~emptyMatch
  if tokens~items < phraseWords then return self~emptyMatch

  limit = tokens~items - phraseWords + 1
  do start = 1 to limit
    matched = 1
    do offset = 0 to phraseWords - 1
      expected = subword(phrase, offset + 1, 1)
      token = tokens~at(start + offset)
      if token~at("CLEAN") \== expected then matched = 0
    end

    if matched = 1 then do
      parseRecord = .Directory~new
      parseRecord~put("EXACT", "MATCH")
      parseRecord~put(phrase, "TERM")
      parseRecord~put(tokens~at(start)~at("POSITION"), "POSITION")
      parseRecord~put(start, "INDEX")
      parseRecord~put(tokens~at(start + phraseWords - 1)~at("POSITION"), "END_POSITION")
      parseRecord~put(start + phraseWords - 1, "END_INDEX")
      return parseRecord
    end
  end

  return self~emptyMatch

::method emptyMatch private
  match = .Directory~new
  match~put("NONE", "MATCH")
  match~put("", "TERM")
  match~put(0, "POSITION")
  match~put(0, "INDEX")
  match~put(0, "END_POSITION")
  match~put(0, "END_INDEX")
  return match

::method extractSlots private
  use arg spec, tokens

  values = .Directory~new
  bindings = .Array~new
  missing = ""
  slots = spec~at("SLOTS")

  do i = 1 to slots~items
    slot = slots~at(i)
    binding = self~extractSlotBinding(tokens, slot)
    binding~put(slot~at("NAME"), "NAME")
    bindings~append(binding)

    if binding~at("FOUND") = 1 then values~put(binding~at("VALUE"), slot~at("NAME"))
    else do
      if slot~at("REQUIRED") = 1 then missing = space(missing slot~at("NAME"))
    end
  end

  parseRecord = .Directory~new
  parseRecord~put(values, "VALUES")
  parseRecord~put(bindings, "BINDINGS")
  parseRecord~put(missing, "MISSING")
  return parseRecord

::method extractSlotBinding private
  use arg tokens, slot

  binding = self~emptyBinding
  markers = self~splitTerms(slot~at("MARKERS"))
  bestStart = 0
  bestMarker = ""

  do m = 1 to markers~items
    marker = markers~at(m)
    markerWords = words(marker)
    if markerWords = 0 then iterate
    if tokens~items < markerWords then iterate

    limit = tokens~items - markerWords + 1
    do start = 1 to limit
      if self~markerAt(tokens, start, marker) = 1 then do
        if bestStart = 0 then do
          bestStart = start
          bestMarker = marker
        end
        else if start < bestStart then do
          bestStart = start
          bestMarker = marker
        end
        leave
      end
    end
  end

  if bestStart = 0 then return binding

  valueStart = bestStart + words(bestMarker)
  if valueStart > tokens~items then return binding

  mode = slot~at("MODE")
  valueEnd = valueStart
  if mode == "NEXT" then value = self~cleanValue(tokens~at(valueStart)~at("RAW"))
  else if mode == "REST" then do
    valueEnd = tokens~items
    value = self~cleanValue(self~joinRaw(tokens, valueStart, valueEnd))
  end
  else do
    phraseRecord = self~capturePhrase(tokens, valueStart, slot~at("STOP_MARKERS"))
    value = phraseRecord~at("VALUE")
    valueEnd = phraseRecord~at("END_INDEX")
  end

  if value == "" then return binding

  binding~put(1, "FOUND")
  binding~put(value, "VALUE")
  binding~put(bestMarker, "MARKER")
  binding~put(bestStart, "MARKER_INDEX")
  binding~put(valueStart, "START_INDEX")
  binding~put(valueEnd, "END_INDEX")
  return binding

::method capturePhrase private
  use arg tokens, valueStart, stopMarkersText

  phraseRecord = .Directory~new
  phraseRecord~put("", "VALUE")
  phraseRecord~put(valueStart, "END_INDEX")

  firstRaw = tokens~at(valueStart)~at("RAW")
  firstChar = left(firstRaw, 1)
  quoteChar = ""
  if firstChar == '"' then quoteChar = '"'
  else if firstChar == "'" then quoteChar = "'"

  if quoteChar \== "" then do
    valueEnd = valueStart
    do i = valueStart to tokens~items
      valueEnd = i
      raw = tokens~at(i)~at("RAW")
      if i = valueStart then do
        if length(raw) > 1 then do
          if right(raw, 1) == quoteChar then leave
        end
      end
      else if right(raw, 1) == quoteChar then leave
    end
    phraseRecord~put(self~cleanValue(self~joinRaw(tokens, valueStart, valueEnd)), "VALUE")
    phraseRecord~put(valueEnd, "END_INDEX")
    return phraseRecord
  end

  valueEnd = tokens~items
  if strip(stopMarkersText) \== "" then do
    do i = valueStart + 1 to tokens~items
      if self~anyMarkerAt(tokens, i, stopMarkersText) = 1 then do
        valueEnd = i - 1
        leave
      end
    end
  end

  phraseRecord~put(self~cleanValue(self~joinRaw(tokens, valueStart, valueEnd)), "VALUE")
  phraseRecord~put(valueEnd, "END_INDEX")
  return phraseRecord

::method anyMarkerAt private
  use arg tokens, start, markersText

  markers = self~splitTerms(markersText)
  do i = 1 to markers~items
    if self~markerAt(tokens, start, markers~at(i)) = 1 then return 1
  end
  return 0

::method markerAt private
  use arg tokens, start, marker

  markerWords = words(marker)
  if markerWords = 0 then return 0
  if start + markerWords - 1 > tokens~items then return 0

  do offset = 0 to markerWords - 1
    expected = subword(marker, offset + 1, 1)
    if tokens~at(start + offset)~at("CLEAN") \== expected then return 0
  end
  return 1

::method emptyBinding private
  binding = .Directory~new
  binding~put(0, "FOUND")
  binding~put("", "VALUE")
  binding~put("", "MARKER")
  binding~put(0, "MARKER_INDEX")
  binding~put(0, "START_INDEX")
  binding~put(0, "END_INDEX")
  return binding

::method joinRaw private
  use arg tokens, firstIndex, lastIndex

  value = ""
  do i = firstIndex to lastIndex
    value = value tokens~at(i)~at("RAW")
  end
  return strip(value)

::method isNegated private
  use arg tokens, negators, verbIndex

  if verbIndex <= 1 then return 0
  start = verbIndex - 3
  if start < 1 then start = 1

  do i = start to verbIndex - 1
    token = tokens~at(i)
    if negators~hasIndex(token~at("CLEAN")) = 1 then return 1
  end
  return 0

::method buildSemantic private
  use arg best, parseRecord, slotRecord

  semantic = .Directory~new
  semantic~put("symbolic.nlp.semantic/0.1", "SCHEMA")
  semantic~put(best~at("ID"), "INTENT")
  semantic~put(parseRecord~at("STATUS"), "STATUS")
  semantic~put(parseRecord~at("POLARITY"), "POLARITY")
  semantic~put(self~semanticNode("ACTION", best~at("VERB_CONCEPT"), best~at("VERB_TERM"), best~at("VERB_MATCH"), best~at("VERB_INDEX"), best~at("VERB_POSITION")), "ACTION")
  semantic~put(self~semanticNode("OBJECT", best~at("NOUN_CONCEPT"), best~at("NOUN_TERM"), best~at("NOUN_MATCH"), best~at("NOUN_INDEX"), best~at("NOUN_POSITION")), "OBJECT")
  semantic~put(slotRecord~at("VALUES"), "ARGUMENTS")

  relations = .Array~new
  if best~at("VERB_TERM") \== "" then do
    if best~at("NOUN_TERM") \== "" then do
      relation = .Directory~new
      relation~put("PREDICATE_OBJECT", "TYPE")
      relation~put(best~at("VERB_CONCEPT"), "PREDICATE")
      relation~put(best~at("NOUN_CONCEPT"), "OBJECT")
      relations~append(relation)
    end
  end

  if parseRecord~at("NEGATED") = 1 then do
    relation = .Directory~new
    relation~put("NEGATION", "TYPE")
    relation~put("ACTION", "TARGET")
    relations~append(relation)
  end

  bindings = slotRecord~at("BINDINGS")
  do i = 1 to bindings~items
    binding = bindings~at(i)
    if binding~at("FOUND") = 1 then do
      relation = .Directory~new
      relation~put("ARGUMENT", "TYPE")
      relation~put(binding~at("NAME"), "ROLE")
      relation~put(binding~at("VALUE"), "VALUE")
      relation~put(binding~at("MARKER"), "MARKER")
      relations~append(relation)
    end
  end

  semantic~put(relations, "RELATIONS")
  semantic~put(self~renderSemanticForm(best, parseRecord, bindings), "FORM")
  return semantic

::method semanticNode private
  use arg nodeType, concept, term, matchKind, tokenIndex, position

  node = .Directory~new
  node~put(nodeType, "TYPE")
  node~put(concept, "CONCEPT")
  node~put(term, "TERM")
  node~put(matchKind, "MATCH")
  node~put(tokenIndex, "INDEX")
  node~put(position, "POSITION")
  return node

::method renderSemanticForm private
  use arg best, parseRecord, bindings

  form = best~at("ID") || "[" || parseRecord~at("POLARITY") || "](" 
  separator = ""

  if best~at("VERB_CONCEPT") \== "" then do
    form = form || "ACTION=" || best~at("VERB_CONCEPT")
    separator = ";"
  end
  if best~at("NOUN_CONCEPT") \== "" then do
    form = form || separator || "OBJECT=" || best~at("NOUN_CONCEPT")
    separator = ";"
  end

  do i = 1 to bindings~items
    binding = bindings~at(i)
    if binding~at("FOUND") = 1 then do
      form = form || separator || binding~at("NAME") || "=" || self~formValue(binding~at("VALUE"))
      separator = ";"
    end
  end

  return form || ")"

::method formValue private
  use arg value

  if pos(" ", value) = 0 then return value
  return '"' || value || '"'

::method resolveConcept private
  expose conceptTable
  use arg conceptIds, term, expectedRole

  if term == "" then return ""
  ids = self~splitTerms(conceptIds)
  do i = 1 to ids~items
    conceptId = ids~at(i)
    if conceptTable~hasIndex(conceptId) = 0 then iterate
    concept = conceptTable~at(conceptId)
    if concept~at("ROLE") \== expectedRole then iterate
    terms = self~splitTerms(concept~at("TERMS"))
    do t = 1 to terms~items
      if terms~at(t) == term then return conceptId
    end
  end

  /* Legacy raw-term intents still have useful canonical semantic labels. */
  return term

::method normalizeConceptIds private
  use arg conceptIds

  ids = self~splitTerms(conceptIds)
  out = ""
  do i = 1 to ids~items
    conceptId = translate(strip(ids~at(i)))
    if conceptId == "" then iterate
    if out == "" then out = conceptId
    else out = out || "|" || conceptId
  end
  return out

::method expandConceptTerms private
  expose conceptTable
  use arg conceptIds, expectedRole

  ids = self~splitTerms(conceptIds)
  out = ""
  do i = 1 to ids~items
    conceptId = ids~at(i)
    if conceptTable~hasIndex(conceptId) = 0 then raise syntax 93.900 array("Unknown concept:" conceptId)
    concept = conceptTable~at(conceptId)
    if concept~at("ROLE") \== expectedRole then raise syntax 93.900 array("Concept has wrong role:" conceptId)
    terms = self~splitTerms(concept~at("TERMS"))
    do t = 1 to terms~items
      term = terms~at(t)
      if out == "" then out = term
      else if self~termListContains(out, term) = 0 then out = out || "|" || term
    end
  end
  return out

::method termListContains private
  use arg termsText, wanted

  terms = self~splitTerms(termsText)
  do i = 1 to terms~items
    if terms~at(i) == wanted then return 1
  end
  return 0

::method registerTerms private
  use arg termsText, role

  terms = self~splitTerms(termsText)
  do i = 1 to terms~items
    term = terms~at(i)
    do w = 1 to words(term)
      self~registerLexeme(subword(term, w, 1), role)
    end
  end

::method registerLexeme private
  expose lexicon soundexIndex
  use arg surface, role

  surface = translate(strip(surface))
  if surface == "" then return

  if lexicon~hasIndex(surface) = 1 then do
    entry = lexicon~at(surface)
    roles = entry~at("ROLES")
    marker = ";" || role || ";"
    if pos(marker, ";" || roles || ";") = 0 then entry~put(roles || ";" || role, "ROLES")
    return
  end

  entry = .Directory~new
  entry~put(surface, "SURFACE")
  entry~put(role, "ROLES")
  lexicon~put(entry, surface)

  sx = self~soundex(surface)
  if soundexIndex~hasIndex(sx) = 0 then soundexIndex~put(.Array~new, sx)
  soundexIndex~at(sx)~append(surface)

::method normalizeTerms private
  use arg termsText

  terms = self~splitTerms(termsText)
  out = ""
  do i = 1 to terms~items
    term = space(translate(strip(terms~at(i))))
    if term == "" then iterate
    if out == "" then out = term
    else out = out || "|" || term
  end
  return out

::method splitTerms private
  use arg termsText

  out = .Array~new
  rest = strip(termsText)
  do while rest \== ""
    parse var rest term "|" rest
    term = space(translate(strip(term)))
    if term \== "" then out~append(term)
  end
  return out

::method cleanWord private
  use arg raw

  upper = translate(raw)
  clean = ""
  do i = 1 to length(upper)
    ch = substr(upper, i, 1)
    if pos(ch, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_") > 0 then clean = clean || ch
  end
  return clean

::method cleanValue private
  use arg raw

  value = strip(raw)
  do while length(value) > 0
    first = left(value, 1)
    if pos(first, '"''([{') > 0 then value = substr(value, 2)
    else leave
  end

  do while length(value) > 0
    last = right(value, 1)
    if pos(last, '"'')]}.,;:') > 0 then value = left(value, length(value) - 1)
    else leave
  end
  return value

::method soundex private
  use arg name

  name = translate(name)
  cleanName = ""
  do i = 1 to length(name)
    char = substr(name, i, 1)
    if pos(char, "ABCDEFGHIJKLMNOPQRSTUVWXYZ") > 0 then cleanName = cleanName || char
  end

  if cleanName == "" then return "0000"

  firstLetter = left(cleanName, 1)
  coded = ""

  do i = 1 to length(cleanName)
    char = substr(cleanName, i, 1)
    select
      when pos(char, "BFPV") > 0 then code = "1"
      when pos(char, "CGJKQSXZ") > 0 then code = "2"
      when pos(char, "DT") > 0 then code = "3"
      when char == "L" then code = "4"
      when pos(char, "MN") > 0 then code = "5"
      when char == "R" then code = "6"
      otherwise code = "."
    end
    coded = coded || code
  end

  cleanCodes = left(coded, 1)
  do i = 2 to length(coded)
    prev = substr(coded, i - 1, 1)
    curr = substr(coded, i, 1)
    if curr \== prev then cleanCodes = cleanCodes || curr
  end

  cleanCodes = substr(cleanCodes, 2)
  cleanCodes = changestr(".", cleanCodes, "")
  finalCode = firstLetter || cleanCodes
  return left(finalCode, 4, "0")
