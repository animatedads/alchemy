/* IntentionNLP.cls
 * Owned NLP engine registry and provider bridge for IntentionService.
 *
 * IntentionService owns the recognition engines.  Callers select an engine by
 * stable strategy name; they do not instantiate parser classes or manage files.
 */

::class IntentionNLPRegistry public

::method available class
  return .Array~of("FST", "SYMBOLIC", "CONTRASTIVE", "PROBABILISTIC", -
      "PERCEPTRON", "CALIBRATED", "HYPER", "DECISION", "RDR", "ANALOGICAL", "META")

::method canonicalName class
  use arg requested
  name = translate(strip(requested))
  if name == "" then name = "META"
  if name == "WFST" | name == "AUTOMATON" then return "FST"
  if name == "VSA" | name == "HDC" then return "HYPER"
  if name == "DL" | name == "YAROWSKY" then return "DECISION"
  if name == "RIPPLE" then return "RDR"
  if name == "AML" | name == "SKOUSEN" then return "ANALOGICAL"
  if name == "ENSEMBLE" then return "META"
  return name

::method create class
  use arg requested
  name = self~canonicalName(requested)
  select
    when name == "FST" then return .FiniteStateNLPParser~new
    when name == "SYMBOLIC" then return .SymbolicNLPParser~new
    when name == "CONTRASTIVE" then return .ContrastiveNLPParser~new
    when name == "PROBABILISTIC" then return .ProbabilisticNLPParser~new
    when name == "PERCEPTRON" then return .PerceptronNLPParser~new
    when name == "CALIBRATED" then return .CalibratedNLPParser~new
    when name == "HYPER" then return .HyperdimensionalNLPParser~new
    when name == "DECISION" then return .DecisionListNLPParser~new
    when name == "RDR" then return .RippleDownNLPParser~new
    when name == "ANALOGICAL" then return .AnalogicalNLPParser~new
    when name == "META" then return .MetaNLPParser~new
    otherwise raise syntax 93.900 array("Unknown IntentionService NLP engine:" requested)
  end

::class NLPIntentionProvider public

::method init
  expose engineName parser registrySignature name
  use arg requestedEngine = "META"
  engineName = .IntentionNLPRegistry~canonicalName(requestedEngine)
  parser = .nil
  registrySignature = ""
  name = "NLP:" || engineName

::attribute name get
::attribute engineName get

::method propose
  expose parser name
  use arg service, text
  self~synchronise(service)
  route = parser~route(text)
  intention = route~at("INTENT")
  if intention == .nil then return .Array~new
  intention = strip(intention)
  if intention == "" then return .Array~new
  registration = service~registration(intention)
  if registration == .nil then return .Array~new

  score = 100
  if route~hasIndex("SCORE") then score = route~at("SCORE")
  status = ""
  if route~hasIndex("STATUS") then status = route~at("STATUS")
  if status == "UNKNOWN" then return .Array~new

  explicit = self~explicitEvidence(registration, text)
  proposal = .IntentionProposal~new(registration~id, score, name, explicit, -
      "owned NLP engine " || engineName)

  if route~hasIndex("ARGUMENTS") then do
    arguments = route~at("ARGUMENTS")
    if arguments \== .nil then do
      supplier = arguments~supplier
      do while supplier~available
        proposal~putSlot(supplier~index, supplier~item, .true)
        supplier~next
      end
    end
  end
  return .Array~of(proposal)

::method synchronise
  expose parser engineName registrySignature
  use arg service
  signature = self~signature(service)
  if parser \== .nil then do
    if signature == registrySignature then return
  end

  parser = .IntentionNLPRegistry~create(engineName)
  registrations = service~registrations
  supplier = registrations~supplier
  do while supplier~available
    registration = supplier~item
    verbs = registration~verbTerms
    nouns = registration~nounTerms
    parser~registerIntent(registration~id, verbs, nouns, registration~phrase, 0)
    aliases = registration~aliases
    aliasIndex = 1
    do while aliasIndex <= aliases~items
      parser~addApprovedPhrase(registration~id, aliases~at(aliasIndex))
      aliasIndex = aliasIndex + 1
    end
    parser~setIntentProvenance(registration~id, "INTENTION_SERVICE", "OWNED_NLP_REGISTRY", "APPROVED")
    supplier~next
  end
  registrySignature = signature

::method signature
  use arg service
  out = ""
  registrations = service~registrations
  supplier = registrations~supplier
  do while supplier~available
    registration = supplier~item
    out = out || registration~id || ":" || registration~verbTerms || ":" || -
        registration~nounTerms || ":" || self~joinAliases(registration~aliases) || "|"
    supplier~next
  end
  return out

::method joinAliases
  use arg aliases
  out = ""
  i = 1
  do while i <= aliases~items
    if out == "" then out = aliases~at(i)
    else out = out || "|" || aliases~at(i)
    i = i + 1
  end
  return out

::method explicitEvidence
  use arg registration, text
  upperText = translate(space(text))
  aliases = registration~aliases
  i = 1
  do while i <= aliases~items
    alias = translate(space(aliases~at(i)))
    if alias \== "" then do
      if pos(alias, upperText) > 0 then return .true
    end
    i = i + 1
  end
  return .false

::requires "nlp/FiniteStateNLP.cls"
::requires "nlp/SymbolicNLP.cls"
::requires "nlp/ContrastiveNLP.cls"
::requires "nlp/ProbabilisticNLP.cls"
::requires "nlp/CalibratedNLP.cls"
::requires "nlp/PerceptronNLP.cls"
::requires "nlp/HyperdimensionalNLP.cls"
::requires "nlp/DecisionListNLP.cls"
::requires "nlp/RippleDownNLP.cls"
::requires "nlp/AnalogicalNLP.cls"
::requires "nlp/MetaNLP.cls"

::requires "IntentionContext.cls"
