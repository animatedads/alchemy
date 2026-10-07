/* ScientificSolverProvider.cls
 * "Rent a PhD" provider-facing intention package.
 *
 * This layer routes work.  It does not duplicate Maths, ML, ML Graph,
 * Physics World, or Rexxtronics semantics.  Crucially, Rexx objects remain
 * Rexx objects through request -> capability -> result.
 */

::class ScientificSolverProvider public
::method init
  expose capabilities registrations capabilityRevision
  capabilities = .Array~new
  registrations = .Array~new
  capabilityRevision = 0

::method contract
  return "scientific.solver/0.1"

::method install
  expose registrations
  use strict arg service
  if service == .nil then raise syntax 93.900 array("IntentionService is required")

  policy = .IntentionBucketPolicy~new("FLEXIBLE", 50, 10, .true, .false)
  service~registerBucket("SCIENTIFIC_SOLVER", policy)

  /* Evidence is advisory vocabulary for recognition; authority remains in
   * the selected specialist component and its returned objects. */
  service~feed("SCIENTIFIC_SOLVER", -
      "advanced scientific solve mathematics maths proof optimisation numerical modelling", -
      "scientific-solver/maths")
  service~feed("SCIENTIFIC_SOLVER", -
      "machine learning pattern scoring classification fitting temporal pattern wobble analysis", -
      "scientific-solver/ml")
  service~feed("SCIENTIFIC_SOLVER", -
      "machine learning graph technical visualisation evidence plot overlay renderer", -
      "scientific-solver/ml-graph")
  service~feed("SCIENTIFIC_SOLVER", -
      "physics mechanics acoustics fluids thermal aerodynamics electromechanics simulation", -
      "scientific-solver/physics")
  service~feed("SCIENTIFIC_SOLVER", -
      "electronics circuit transient dc semiconductor sensor electrical electromechanical rexxtronics", -
      "scientific-solver/rexxtronics")
  service~feed("SCIENTIFIC_SOLVER", -
      "multidisciplinary coupled solve scientific analysis expert solver rent a phd", -
      "scientific-solver/coupled")

  registrations = .Array~new
  self~addRegistration(service, "solve mathematics", "MATHS", -
      "solve maths|prove mathematics|numerical analysis|optimise mathematically|analyze mathematics")
  self~addRegistration(service, "solve machine learning problem", "ML", -
      "machine learning analysis|fit model|score pattern|classify pattern|analyse ml")
  self~addRegistration(service, "visualise machine learning evidence", "ML_GRAPH", -
      "graph ml|plot ml evidence|visualize ml|visualise ml|render ml graph")
  self~addRegistration(service, "solve physics problem", "PHYSICS", -
      "simulate physics|physics model|mechanics analysis|acoustic analysis|fluid analysis|thermal analysis")
  self~addRegistration(service, "solve electronics problem", "REXXTRONICS", -
      "circuit analysis|simulate circuit|electronics analysis|rexxtronics|electrical analysis")
  self~addRegistration(service, "solve multidisciplinary scientific problem", "COUPLED", -
      "scientific solve|expert solve|rent a phd|coupled model|multiphysics|cross domain analysis")

  /* Generic fallback is deliberately broad but still confirmation-gated. */
  self~addRegistration(service, "ask scientific solver", "AUTO", -
      "scientific question|technical analysis|expert analysis|solve this problem")
  return self

::method addRegistration private
  expose registrations
  use strict arg service, phrase, domain, aliasText
  event = .ScientificSolverEvent~new(self, domain)
  reg = service~register(phrase, event, "SCIENTIFIC_SOLVER")
  reg~tag("PROVIDER", "scientific.solver/0.1")
  reg~tag("DOMAIN", domain)
  rest = aliasText
  do while rest \== ""
    parse var rest alias '|' rest
    alias = strip(alias)
    if alias \== "" then reg~alias(alias)
  end
  reg~semantics(self~verbsFor(domain), self~nounsFor(domain))
  reg~planBuilder(.ScientificSolverPlanBuilder~new(domain))
  registrations~append(reg)
  return reg

::method verbsFor private
  use strict arg domain
  select
    when domain == "ML_GRAPH" then return "visualise|visualize|graph|plot|render|explain"
    when domain == "ML" then return "analyse|analyze|fit|score|classify|learn|solve"
    when domain == "PHYSICS" then return "simulate|model|analyse|analyze|solve|predict"
    when domain == "REXXTRONICS" then return "simulate|model|analyse|analyze|solve|measure"
    otherwise return "solve|analyse|analyze|model|prove|optimise|optimize|calculate"
  end

::method nounsFor private
  use strict arg domain
  select
    when domain == "MATHS" then return "maths|mathematics|proof|equation|numerics|optimisation|optimization"
    when domain == "ML" then return "ml|machine learning|pattern|model|classifier|fit|wobble"
    when domain == "ML_GRAPH" then return "ml graph|graph|plot|visualisation|visualization|evidence"
    when domain == "PHYSICS" then return "physics|mechanics|acoustics|fluid|thermal|aerodynamics|simulation"
    when domain == "REXXTRONICS" then return "electronics|circuit|electrical|rexxtronics|transient|semiconductor"
    when domain == "COUPLED" then return "scientific problem|multiphysics|coupled model|expert problem"
    otherwise return "scientific problem|technical problem|question|analysis"
  end

::method registerCapability
  expose capabilities capabilityRevision
  use strict arg capability
  if capability == .nil then raise syntax 93.900 array("Scientific solver capability is required")
  if \capability~isA(.ScientificSolverCapability) then -
      raise syntax 93.900 array("Expected ScientificSolverCapability")

  /* Names are registry identities. Re-registering the same specialist is an
   * atomic replacement rather than a second ambiguous candidate. */
  replacement = .Array~new
  do current over capabilities
    if translate(current~name) \== translate(capability~name) then replacement~append(current)
  end
  replacement~append(capability)
  capabilities = replacement
  capabilityRevision = capabilityRevision + 1
  return self

::method unregisterCapability
  expose capabilities capabilityRevision
  use strict arg name
  replacement = .Array~new
  removed = .false
  do current over capabilities
    if translate(current~name) == translate(strip(name)) then removed = .true
    else replacement~append(current)
  end
  if removed then do
    capabilities = replacement
    capabilityRevision = capabilityRevision + 1
  end
  return removed

::method capabilityRevision
  expose capabilityRevision
  return capabilityRevision

::method capabilities
  expose capabilities
  /* Return a snapshot of registrations, not a cached availability answer. */
  return capabilities~copy

::method discover
  expose capabilities
  use strict arg request
  available = .Array~new
  do capability over capabilities
    /* Availability and request requirements are deliberately re-evaluated
     * for every request.  No permanent routing catalogue is inferred. */
    if capability~available(request) then do
      if capability~matchesRequirements(request) then available~append(capability)
    end
  end
  return available

::method select
  expose capabilityRevision
  use strict arg request
  candidates = self~discover(request)
  observations = .Array~new
  best = .nil
  bestScore = -1
  do capability over candidates
    score = capability~score(request)
    reason = ""
    if capability~executor \== .nil then do
      if capability~executor~hasMethod("EXPLAINSELECTION") then reason = capability~executor~explainSelection(request)
    end
    observations~append(.ScientificSolverCandidate~new(capability, score, reason))
    if score > bestScore then do
      bestScore = score
      best = capability
    end
  end
  return .ScientificSolverSelection~new(request, capabilityRevision, observations, best, bestScore)

::method solve
  use strict arg request
  if request == .nil then raise syntax 93.900 array("ScientificSolverRequest is required")
  if \request~isA(.ScientificSolverRequest) then -
      raise syntax 93.900 array("Expected ScientificSolverRequest")

  selection = self~select(request)
  best = selection~selected
  if best == .nil then return .ScientificSolverResult~unavailable(request, -
      "No currently available scientific capability satisfied the request", selection)
  value = best~solve(request)
  if value~isA(.ScientificSolverResult) then do
    value~selection = selection
    return value
  end
  return .ScientificSolverResult~solved(request, best~name, value, .nil, "", selection)

::class ScientificSolverEvent public
::method init
  expose provider domain
  use strict arg provider, domain
::method invoke
  expose provider domain
  use strict arg decision
  return .ScientificSolverDirective~new(provider, domain, decision)

::class ScientificSolverDirective public
::method init
  expose provider domain decision
  use strict arg provider, domain, decision
::attribute provider get
::attribute domain get
::attribute decision get
::method intentionId
  expose decision
  return decision~registration~id
::method slots
  expose decision
  return decision~slots
::method proposedPlan
  expose decision
  return decision~proposedPlan
::method request
  expose domain decision
  use strict arg subject=.nil, context=.nil, evidence=.nil
  return .ScientificSolverRequest~new(domain, decision~input, subject, context, evidence, decision)
::method solve
  expose provider
  use strict arg subject=.nil, context=.nil, evidence=.nil
  return provider~solve(self~request(subject, context, evidence))

::class ScientificSolverRequest public
::method init
  expose domain question subject context evidence decision metadata requirements
  use strict arg domain, question, subject=.nil, context=.nil, evidence=.nil, decision=.nil
  domain = translate(strip(domain))
  question = question
  subject = subject
  context = context
  evidence = evidence
  decision = decision
  metadata = .Directory~new
  requirements = .Directory~new
::attribute domain get
::attribute question get
::attribute subject get
::attribute context get
::attribute evidence get
::attribute decision get
::method tag
  expose metadata
  use strict arg name, value
  metadata~put(value, translate(strip(name)))
  return self
::method metadata
  expose metadata
  return metadata
::method require
  expose requirements
  use strict arg name, value
  requirements~put(value, translate(strip(name)))
  return self
::method requirements
  expose requirements
  return requirements~copy
::method requirement
  expose requirements
  use strict arg name, default=.nil
  key = translate(strip(name))
  if requirements~hasIndex(key) then return requirements~at(key)
  return default

::class ScientificSolverCapability public
::method init
  expose name domains executor priority properties
  use strict arg name, domains, executor, priority=50
  name = strip(name)
  domains = translate(strip(domains))
  executor = executor
  priority = priority
  properties = .Directory~new
  properties~put("READ_ONLY", "SIDE_EFFECT_CLASS")
  properties~put("NATIVE_REXX", "OBJECT_TRANSPORT")
  properties~put("SPECIALIST", "AUTHORITY_ROLE")
::attribute name get
::attribute priority get
::attribute executor get
::method domains
  expose domains
  return domains
::method tag
  expose properties
  use strict arg name, value
  properties~put(value, translate(strip(name)))
  return self
::method property
  expose properties
  use strict arg name, default=.nil
  key = translate(strip(name))
  if properties~hasIndex(key) then return properties~at(key)
  return default
::method properties
  expose properties
  return properties~copy
::method matchesRequirements
  expose properties
  use strict arg request
  requirements = request~requirements
  indexes = requirements~allIndexes
  do i = 1 to indexes~items
    key = indexes~at(i)
    if \properties~hasIndex(key) then return .false
    if properties~at(key) \== requirements~at(key) then return .false
  end
  return .true
::method supports
  expose domains
  use strict arg domain
  wanted = translate(strip(domain))
  if wanted == "AUTO" | wanted == "COUPLED" then return .true
  rest = translate(domains)
  do while rest \== ""
    parse var rest item '|' rest
    if strip(item) == wanted then return .true
  end
  return .false
::method available
  expose executor
  use strict arg request
  if \self~supports(request~domain) then return .false
  if executor == .nil then return .false
  if executor~hasMethod("AVAILABLE") then return executor~available(request)
  return .true
::method score
  expose executor priority
  use strict arg request
  value = priority
  if executor \== .nil then do
    if executor~hasMethod("SCORE") then value = value + executor~score(request)
  end
  return value
::method solve
  expose executor
  use strict arg request
  if executor == .nil then return .ScientificSolverResult~unavailable(request)
  return executor~solve(request)

::class ScientificSolverResult public
::method init
  expose status request capability value evidence explanation selection limitations
  use strict arg status, request, capability="", value=.nil, evidence=.nil, explanation="", selection=.nil
  limitations = .Array~new
::method solved class
  use strict arg request, capability, value, evidence=.nil, explanation="", selection=.nil
  return self~new("SOLVED", request, capability, value, evidence, explanation, selection)
::method unavailable class
  use strict arg request, explanation="No currently available scientific capability accepted the request", selection=.nil
  return self~new("UNAVAILABLE", request, "", .nil, .nil, explanation, selection)
::attribute status get
::attribute request get
::attribute capability get
::attribute value get
::attribute evidence get
::attribute explanation get
::attribute selection
::method addLimitation
  expose limitations
  use strict arg limitation
  limitations~append(limitation)
  return self
::method limitations
  expose limitations
  return limitations~copy

::class ScientificSolverCandidate public
::method init
  expose capability score reason
  use strict arg capability, score, reason=""
::attribute capability get
::attribute score get
::attribute reason get
::method name
  expose capability
  return capability~name
::method properties
  expose capability
  return capability~properties

::class ScientificSolverSelection public
::method init
  expose request registryRevision candidates selected selectedScore
  use strict arg request, registryRevision, candidates, selected=.nil, selectedScore=0
::attribute request get
::attribute registryRevision get
::attribute selected get
::attribute selectedScore get
::method candidates
  expose candidates
  return candidates~copy
::method selectedName
  expose selected
  if selected == .nil then return ""
  return selected~name

::class ScientificSolverPlanBuilder public
::method init
  expose domain
  use strict arg domain
::method build
  expose domain
  use strict arg service, registration, proposal
  plan = .IntentionPlan~new(registration~id, "Direct problem to the scientific solver provider")
  plan~sideEffectClass = "READ_ONLY"
  plan~addStep("DISCOVER_CAPABILITIES", "Re-evaluate currently available specialist capabilities", domain)
  plan~addStep("MATCH_REQUIREMENTS", "Reject live specialists that do not satisfy caller requirements", domain)
  plan~addStep("SELECT_SPECIALIST", "Select the best live specialist and retain selection evidence", domain)
  plan~addStep("SOLVE", "Pass the original Rexx objects to the selected specialist", domain)
  plan~addStep("RETURN_EVIDENCE", "Return specialist result and evidence without flattening objects", domain)
  plan~expectOutput("ScientificSolverResult")
  plan~tag("DOMAIN", domain)
  plan~tag("OBJECT_TRANSPORT", "NATIVE_REXX")
  plan~tag("DISCOVERY", "DYNAMIC_PER_REQUEST")
  plan~tag("SELECTION_EVIDENCE", "NATIVE_REXX")
  return plan

::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
