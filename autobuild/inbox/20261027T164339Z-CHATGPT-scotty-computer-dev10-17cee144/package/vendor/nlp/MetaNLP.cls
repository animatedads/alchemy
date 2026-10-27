/* MetaNLP.cls
   Ensemble / Meta director for the virtual representative (engine META).

   Runs ten local engines (FST, SYMBOLIC, CONTRASTIVE, PROBABILISTIC,
   PERCEPTRON, CALIBRATED, HYPER, DECISION, RDR, ANALOGICAL) behind a single registration surface.
   FST is a Tier-0 precision fast-path: an approved accepting path returns
   immediately; an FST abstention falls through at effectively no policy cost.
   Six are authoritative voters; DECISION, RDR and ANALOGICAL are advisory/support voters because
   the labelled harness shows that its current confident-error rate is too high
   to justify veto authority.  The quorum policy on every route():

     - Each engine receives the identical concept / intent / phrase
       registrations and learned evidence.
     - On route(text) every engine is asked independently.
     - If at least minAgree authoritative engines return MATCHED for the
       *same* intent and no authoritative engine returns MATCHED for a
       different intent, the agreed route is emitted.
     - If exactly one authoritative engine matches, DECISION may supply the
       second supporting vote only when it agrees with that same intent (with the highest-scoring agreeing engine's
       SCORE / EVIDENCE / REFERRAL).
     - Otherwise STATUS = UNKNOWN (or AMBIGUOUS when multiple distinct
       MATCHED intents appear) so the existing Stage-1 / Stage-2 cognition
       path can teach.

   This is the "job-killer loop" layer: ordinary consensus stays local and
   deterministic; conflict or low agreement produces a visible, bounded
   escalation.  Azure rescue results continue to be admitted only through
   the existing reviewed promotion contract (addApprovedPhrase etc.); the
   Meta director never rewrites SalesPolicy or invents new authority.

   Pure ooRexx.  Deterministic.  Select with VIRTUAL_REP_NLP_ENGINE=META
   (or ENSEMBLE).
*/

::class MetaNLPParser public

::method init
  expose engines engineOrder minAgree threshold ambiguityMargin -
         activeMode activeLanguage activeApplication lastVotes
  engines = .Directory~new
  engineOrder = .Array~of("FST", "SYMBOLIC", "CONTRASTIVE", "PROBABILISTIC", "PERCEPTRON", "CALIBRATED", "HYPER", "DECISION", "RDR", "ANALOGICAL")
  engines~put(.FiniteStateNLPParser~new, "FST")
  engines~put(.SymbolicNLPParser~new, "SYMBOLIC")
  engines~put(.ContrastiveNLPParser~new, "CONTRASTIVE")
  engines~put(.ProbabilisticNLPParser~new, "PROBABILISTIC")
  engines~put(.PerceptronNLPParser~new, "PERCEPTRON")
  engines~put(.CalibratedNLPParser~new, "CALIBRATED")
  engines~put(.HyperdimensionalNLPParser~new, "HYPER")
  engines~put(.DecisionListNLPParser~new, "DECISION")
  engines~put(.RippleDownNLPParser~new, "RDR")
  engines~put(.AnalogicalNLPParser~new, "ANALOGICAL")
  minAgree = 2
  threshold = 60
  ambiguityMargin = 12
  activeMode = "ANY"
  activeLanguage = "ANY"
  activeApplication = "ANY"
  lastVotes = .Directory~new

::method version
  return "0.1-dev7-meta-fst-fastpath"

::method strategyName
  return "META_ENSEMBLE"

::method configure
  expose engines engineOrder threshold ambiguityMargin
  use arg newThreshold, newAmbiguityMargin
  if arg(1, "O") = 0 then threshold = newThreshold
  if arg(2, "O") = 0 then ambiguityMargin = newAmbiguityMargin
  do i = 1 to engineOrder~items
    eng = engines~at(engineOrder[i])
    eng~configure(threshold, ambiguityMargin)
  end
  return self

::method setMinAgree
  expose minAgree
  use arg n
  if arg(1, "O") = 0 then minAgree = n
  return self

::method setContext
  expose engines engineOrder activeMode activeLanguage activeApplication
  use arg mode, language, application
  activeMode = mode
  activeLanguage = language
  activeApplication = application
  do i = 1 to engineOrder~items
    eng = engines~at(engineOrder[i])
    eng~setContext(mode, language, application)
  end
  return self

::method activeContext
  expose engines engineOrder
  /* Return the context from the first engine; they are kept in lock-step. */
  return engines~at(engineOrder[1])~activeContext

::method registerConcept
  expose engines engineOrder
  use arg id, role, terms
  do i = 1 to engineOrder~items
    eng = engines~at(engineOrder[i])
    eng~registerConcept(id, role, terms)
  end
  return self

::method registerSemanticIntent
  expose engines engineOrder
  use arg id, verbs, nouns, phrases, priority
  do i = 1 to engineOrder~items
    eng = engines~at(engineOrder[i])
    eng~registerSemanticIntent(id, verbs, nouns, phrases, priority)
  end
  return self

::method registerIntent
  expose engines engineOrder
  use arg id, verbs, nouns, phrases, priority
  do i = 1 to engineOrder~items
    eng = engines~at(engineOrder[i])
    if eng~hasMethod("registerIntent") then -
      eng~registerIntent(id, verbs, nouns, phrases, priority)
  end
  return self

::method registerReferral
  expose engines engineOrder
  use arg intentId, owner, targetKind, targetId, mode, language, application, responseOwner, responseProfile
  do i = 1 to engineOrder~items
    eng = engines~at(engineOrder[i])
    eng~registerReferral(intentId, owner, targetKind, targetId, mode, language, application, responseOwner, responseProfile)
  end
  return self

::method setIntentProvenance
  expose engines engineOrder
  use arg intentId, source, producer, reviewState
  do i = 1 to engineOrder~items
    eng = engines~at(engineOrder[i])
    eng~setIntentProvenance(intentId, source, producer, reviewState)
  end
  return self

::method addApprovedPhrase
  expose engines engineOrder
  use arg intentId, phraseTerms
  do i = 1 to engineOrder~items
    eng = engines~at(engineOrder[i])
    eng~addApprovedPhrase(intentId, phraseTerms)
  end
  return self

::method registerSlot
  expose engines engineOrder
  use arg intentId, slotName, conceptId, required
  do i = 1 to engineOrder~items
    eng = engines~at(engineOrder[i])
    if eng~hasMethod("registerSlot") then -
      eng~registerSlot(intentId, slotName, conceptId, required)
  end
  return self

::method intentIds
  expose engines engineOrder
  return engines~at(engineOrder[1])~intentIds

::method conceptIds
  expose engines engineOrder
  return engines~at(engineOrder[1])~conceptIds

::method examine
  expose engines engineOrder
  use arg text
  /* Return the examine of the first engine for inspection. */
  return engines~at(engineOrder[1])~examine(text)

::method parse
  /* Meta does not expose a single parse; route() is the public entry. */
  use arg text
  return self~route(text)

::method route
  expose engines engineOrder minAgree lastVotes threshold
  use arg text
  numeric digits 12

  /* Tier 0: deterministic finite-state precision memory.  An approved
     accepting path is authoritative local evidence; UNKNOWN simply falls
     through to the family-aware ensemble. */
  routes = .Directory~new
  lastVotes = .Directory~new
  fstRoute = engines~at("FST")~route(text)
  routes~put(fstRoute, "FST")
  fstStatus = fstRoute~at("STATUS")
  fstIntent = fstRoute~at("INTENT")
  fstScore = fstRoute~at("SCORE")
  if fstScore = .nil then fstScore = 0
  lastVotes~put(fstStatus || "|" || fstIntent || "|" || fstScore, "FST")
  if fstStatus == "MATCHED" then if fstIntent \== "" then -
    return self~composeFastPath(text, fstRoute, lastVotes)

  /* Family-aware tiered ensemble.
     CALIBRATED is a conservative derivative of PROBABILISTIC, not an
     independent model family.  Counting both as separate votes can create a
     false quorum from one underlying generative model.  The fast tier therefore
     has four independent families:
       SYMBOLIC, CONTRASTIVE, PERCEPTRON, PROBABILISTIC_FAMILY.
     PROBABILISTIC + CALIBRATED contribute at most one family vote; if both
     MATCH different intents, that family abstains and marks a core conflict.
     Archive engines remain advisory only and wake lazily for one-family cases. */
  coreOrder = .Array~of("SYMBOLIC", "CONTRASTIVE", "PROBABILISTIC", "PERCEPTRON", "CALIBRATED")
  advisoryOrder = .Array~of("RDR", "ANALOGICAL", "DECISION")
  deep = translate(strip(value("VIRTUAL_REP_META_DEEP", , "ENVIRONMENT")))
  if deep == "1" | deep == "YES" | deep == "TRUE" then advisoryOrder~append("HYPER")

  matchedEngines = .Array~new

  do i = 1 to coreOrder~items
    name = coreOrder[i]
    r = engines~at(name)~route(text)
    routes~put(r, name)
    status = r~at("STATUS")
    intent = r~at("INTENT")
    score = r~at("SCORE")
    if score = .nil then score = 0
    lastVotes~put(status || "|" || intent || "|" || score, name)
    if status == "MATCHED" then if intent \== "" then matchedEngines~append(name)
  end

  /* votes counts independent model families, not raw engines. */
  votes = .Directory~new
  familyConflict = 0

  do name over .Array~of("SYMBOLIC", "CONTRASTIVE", "PERCEPTRON")
    r = routes~at(name)
    if r~at("STATUS") == "MATCHED" then if r~at("INTENT") \== "" then -
      self~addFamilyVote(votes, r~at("INTENT"))
  end

  pr = routes~at("PROBABILISTIC")
  cr = routes~at("CALIBRATED")
  pm = (pr~at("STATUS") == "MATCHED" & pr~at("INTENT") \== "")
  cm = (cr~at("STATUS") == "MATCHED" & cr~at("INTENT") \== "")
  if pm then if cm then do
    if pr~at("INTENT") == cr~at("INTENT") then self~addFamilyVote(votes, pr~at("INTENT"))
    else familyConflict = 1
  end
  else if pm then self~addFamilyVote(votes, pr~at("INTENT"))
  else if cm then self~addFamilyVote(votes, cr~at("INTENT"))

  topIntent = ""
  topCount = 0
  distinct = votes~items
  ks = votes~allIndexes
  do k = 1 to ks~items
    c = votes~at(ks[k])
    if c > topCount then do
      topCount = c
      topIntent = ks[k]
    end
  end

  supportUsed = 0
  supportSource = ""
  advisoryRun = .Array~new
  effectiveAgree = topCount

  /* Clean quorum from at least two independent families. */
  if familyConflict = 0 then if distinct = 1 then if topCount >= minAgree then do
    return self~composeMatched(text, topIntent, topCount, distinct, minAgree, -
                               routes, matchedEngines, lastVotes, supportUsed, -
                               supportSource, advisoryRun)
  end

  /* A single unopposed independent family may be strengthened by one archive
     adviser.  An adviser never creates a route alone and never vetoes core. */
  if familyConflict = 0 then if distinct = 1 then if topCount = 1 then do
    do i = 1 to advisoryOrder~items
      name = advisoryOrder[i]
      r = engines~at(name)~route(text)
      routes~put(r, name)
      advisoryRun~append(name)
      status = r~at("STATUS")
      intent = r~at("INTENT")
      score = r~at("SCORE")
      if score = .nil then score = 0
      lastVotes~put(status || "|" || intent || "|" || score, name)
      if status == "MATCHED" then if intent == topIntent then do
        /* DECISION currently has five confident wrongs on the labelled set;
           retain its winning rule as evidence but do not let it alone promote
           a one-family core guess into an authoritative route. */
        if name \== "DECISION" then do
          supportUsed = 1
          supportSource = name
          effectiveAgree = 2
          leave
        end
      end
    end
    if effectiveAgree >= minAgree then do
      return self~composeMatched(text, topIntent, effectiveAgree, distinct, minAgree, -
                                 routes, matchedEngines, lastVotes, supportUsed, -
                                 supportSource, advisoryRun)
    end
  end

  routeRecord = self~emptyMetaRoute(text, lastVotes)
  routeRecord~put(topCount, "META_AGREE")
  routeRecord~put(distinct, "META_DISTINCT")
  routeRecord~put(minAgree, "META_MIN_AGREE")
  routeRecord~put(advisoryRun, "META_ADVISORY_RUN")
  routeRecord~put(supportSource, "META_SUPPORT_SOURCE")
  if familyConflict = 1 | distinct > 1 then do
    routeRecord~put("AMBIGUOUS", "STATUS")
    routeRecord~put("meta: independent-family conflict (agree=" || topCount || " distinct=" || distinct || ")", "EVIDENCE")
  end
  else do
    routeRecord~put("UNKNOWN", "STATUS")
    routeRecord~put("meta: no independent-family quorum (agree=" || topCount || " distinct=" || distinct || ")", "EVIDENCE")
  end
  return routeRecord

::method composeFastPath
  use arg text, fstRoute, lastVotes
  r = .Directory~new
  r~put("symbolic.nlp.route/0.1", "SCHEMA")
  r~put("META_ENSEMBLE", "ENGINE")
  r~put(text, "TEXT")
  r~put(lastVotes, "META_VOTES")
  r~put("FST", "META_FAST_PATH")
  r~put("TIER0_FST", "META_ROUTE_MODE")
  r~put(1, "META_AGREE")
  r~put(1, "META_DISTINCT")
  r~put(1, "META_MIN_AGREE")
  r~put(.Array~new, "META_ADVISORY_RUN")
  r~put("FST", "META_SUPPORT_SOURCE")
  do key over .Array~of("STATUS", "REFERRAL_STATUS", "INTENT", "CANDIDATES", -
                        "POLARITY", "COMPLETE", "NEEDS", "ARGUMENTS", -
                        "SEMANTIC", "ACTIVE_CONTEXT", "SCORE", "MARGIN", -
                        "ROUTABLE", "TASK", "PRESENTATION", "BLOCKED_TASK")
    value = fstRoute~at(key)
    if value == .nil then do
      if key == "CANDIDATES" | key == "NEEDS" then value = .Array~new
      else if key == "ARGUMENTS" | key == "SEMANTIC" | key == "ACTIVE_CONTEXT" | -
              key == "TASK" | key == "PRESENTATION" | key == "BLOCKED_TASK" then value = .Directory~new
      else value = ""
    end
    r~put(value, key)
  end
  r~put("meta: Tier-0 FST accepting path; " || fstRoute~at("EVIDENCE"), "EVIDENCE")
  return r

::method addFamilyVote
  use arg votes, intent
  if votes~hasIndex(intent) = 0 then votes~put(1, intent)
  else votes~put(votes~at(intent) + 1, intent)
  return

::method composeMatched
  use arg text, topIntent, effectiveAgree, distinct, minAgree, routes, matchedEngines, lastVotes, supportUsed, supportSource, advisoryRun
  bestRoute = .nil
  bestScore = -1
  do i = 1 to matchedEngines~items
    name = matchedEngines[i]
    r = routes~at(name)
    if r~at("INTENT") == topIntent then do
      sc = r~at("SCORE")
      if sc = .nil then sc = 0
      if sc > bestScore then do
        bestScore = sc
        bestRoute = r
      end
    end
  end
  routeRecord = .Directory~new
  routeRecord~put("symbolic.nlp.route/0.1", "SCHEMA")
  routeRecord~put("META_ENSEMBLE", "ENGINE")
  routeRecord~put(text, "TEXT")
  routeRecord~put(lastVotes, "META_VOTES")
  routeRecord~put(effectiveAgree, "META_AGREE")
  routeRecord~put(distinct, "META_DISTINCT")
  routeRecord~put(minAgree, "META_MIN_AGREE")
  routeRecord~put(advisoryRun, "META_ADVISORY_RUN")
  routeRecord~put(supportSource, "META_SUPPORT_SOURCE")
  if supportUsed = 1 then routeRecord~put("ADVISORY_SUPPORT", "META_ROUTE_MODE")
  else routeRecord~put("FAST_CORE_QUORUM", "META_ROUTE_MODE")
  routeRecord~put("", "META_FAST_PATH")
  routeRecord~put("MATCHED", "STATUS")
  routeRecord~put(bestRoute~at("REFERRAL_STATUS"), "REFERRAL_STATUS")
  routeRecord~put(topIntent, "INTENT")
  routeRecord~put(bestRoute~at("CANDIDATES"), "CANDIDATES")
  routeRecord~put(bestRoute~at("POLARITY"), "POLARITY")
  routeRecord~put(bestRoute~at("COMPLETE"), "COMPLETE")
  routeRecord~put(bestRoute~at("NEEDS"), "NEEDS")
  routeRecord~put(bestRoute~at("ARGUMENTS"), "ARGUMENTS")
  routeRecord~put(bestRoute~at("SEMANTIC"), "SEMANTIC")
  routeRecord~put(bestRoute~at("ACTIVE_CONTEXT"), "ACTIVE_CONTEXT")
  evidence = bestRoute~at("EVIDENCE")
  if supportUsed = 1 then evidence = "meta: " || supportSource || " advisory support; " || evidence
  else evidence = "meta: fast-core quorum; " || evidence
  routeRecord~put(evidence, "EVIDENCE")
  routeRecord~put(bestScore, "SCORE")
  routeRecord~put(bestRoute~at("MARGIN"), "MARGIN")
  routeRecord~put(bestRoute~at("ROUTABLE"), "ROUTABLE")
  routeRecord~put(bestRoute~at("TASK"), "TASK")
  routeRecord~put(bestRoute~at("PRESENTATION"), "PRESENTATION")
  routeRecord~put(bestRoute~at("BLOCKED_TASK"), "BLOCKED_TASK")
  return routeRecord

::method emptyMetaRoute
  use arg text, lastVotes
  r = .Directory~new
  r~put("symbolic.nlp.route/0.1", "SCHEMA")
  r~put("META_ENSEMBLE", "ENGINE")
  r~put(text, "TEXT")
  r~put(lastVotes, "META_VOTES")
  r~put("ESCALATE", "META_ROUTE_MODE")
  r~put("", "META_FAST_PATH")
  r~put("NONE", "REFERRAL_STATUS")
  r~put("", "INTENT")
  r~put(.Array~new, "CANDIDATES")
  r~put("POSITIVE", "POLARITY")
  r~put(0, "COMPLETE")
  r~put(.Array~new, "NEEDS")
  r~put(.Directory~new, "ARGUMENTS")
  r~put(.Directory~new, "SEMANTIC")
  r~put(.Directory~new, "ACTIVE_CONTEXT")
  r~put(0, "SCORE")
  r~put(0, "MARGIN")
  r~put(0, "ROUTABLE")
  r~put(.Directory~new, "TASK")
  r~put(.Directory~new, "PRESENTATION")
  r~put(.Directory~new, "BLOCKED_TASK")
  return r

::method lastVotes
  expose lastVotes
  return lastVotes

::requires "FiniteStateNLP.cls"
::requires "SymbolicNLP.cls"
::requires "ContrastiveNLP.cls"
::requires "ProbabilisticNLP.cls"
::requires "CalibratedNLP.cls"
::requires "PerceptronNLP.cls"
::requires "HyperdimensionalNLP.cls"
::requires "DecisionListNLP.cls"
::requires "RippleDownNLP.cls"
::requires "AnalogicalNLP.cls"
