::class PokerSocialEvidenceModel public subclass PokerAlchemyObject
::method init
  expose sql currentExperimentId baselineStats noTalkBaselineStats classStats tokenStats targetStats contextBaselineStats noTalkContextBaselineStats classContextStats tokenContextStats targetContextStats pending recentClass recentToken recentTarget recentHand recentContextStreet recentContextFacing lastPromptEvidence lastPromptText
  use arg sql, currentExperimentId
  baselineStats = .directory~new
  noTalkBaselineStats = .directory~new
  classStats = .directory~new
  tokenStats = .directory~new
  targetStats = .directory~new
  contextBaselineStats = .directory~new
  noTalkContextBaselineStats = .directory~new
  classContextStats = .directory~new
  tokenContextStats = .directory~new
  targetContextStats = .directory~new
  pending = .directory~new
  recentClass = .directory~new
  recentToken = .directory~new
  recentTarget = .directory~new
  recentHand = .directory~new
  recentContextStreet = .directory~new
  recentContextFacing = .directory~new
  lastPromptEvidence = .directory~new
  lastPromptText = .directory~new
  self~initPokerAlchemy("SOCIAL_EVIDENCE_MODEL", "Public empirical table-talk/action evidence model")
  self~registerStateVariable("currentExperimentId", "CUSTOMER", "experiment boundary for historical reconstruction")
  self~registerMethodContract("PROMPTTEXT", "Build bounded public social evidence for one live player", .array~of("VIEWER_NAME", "TABLE"), "STRING", .false)
  self~loadHistory

::method loadHistory private
  expose sql currentExperimentId baselineStats noTalkBaselineStats contextBaselineStats noTalkContextBaselineStats
  if currentExperimentId <= 1 then return

  actionsByActorHand = .directory~new
  pairedActions = .directory~new
  outcomeSeen = .directory~new
  actionQuery = "SELECT experiment_id,hand_no,seq,player_name,street,to_call,action FROM action_log WHERE experiment_id<" || currentExperimentId || " ORDER BY experiment_id,hand_no,seq"
  actionResult = sql~execute(actionQuery)
  if actionResult~status \= .Error~SUCCESS then raise syntax 93.900 array("Cannot load social action history")
  do i = 1 to actionResult~rows~items
    actionRow = actionResult~rows[i]
    actor = actionRow["player_name"]
    actorKey = translate(actor)
    self~incrementActionStat(baselineStats, actorKey, actionRow["action"])
    context = self~contextKey(actionRow["street"], actionRow["to_call"])
    self~incrementActionStat(contextBaselineStats, actorKey || "|" || context, actionRow["action"])
    key = self~handActorKey(actionRow["experiment_id"], actionRow["hand_no"], actor)
    if \actionsByActorHand~hasIndex(key) then actionsByActorHand[key] = .array~new
    item = .directory~new
    item["seq"] = actionRow["seq"]
    item["action"] = actionRow["action"]
    item["street"] = actionRow["street"]
    item["to_call"] = actionRow["to_call"]
    actionsByActorHand[key]~append(item)
  end

  talkQuery = "SELECT experiment_id,hand_no,seq,speaker,target,token,talk_class FROM table_talk WHERE experiment_id<" || currentExperimentId || " ORDER BY experiment_id,hand_no,seq"
  talkResult = sql~execute(talkQuery)
  if talkResult~status \= .Error~SUCCESS then raise syntax 93.900 array("Cannot load social talk history")
  do i = 1 to talkResult~rows~items
    talkRow = talkResult~rows[i]
    key = self~handActorKey(talkRow["experiment_id"], talkRow["hand_no"], talkRow["speaker"])
    if \actionsByActorHand~hasIndex(key) then iterate
    actions = actionsByActorHand[key]
    nextAction = ""
    nextStreet = ""
    nextToCall = 0
    nextSeq = 0
    do j = 1 to actions~items
      actionItem = actions[j]
      if actionItem["seq"] > talkRow["seq"] then do
        nextAction = actionItem["action"]
        nextStreet = actionItem["street"]
        nextToCall = actionItem["to_call"]
        nextSeq = actionItem["seq"]
        leave
      end
    end
    if nextAction = "" then iterate
    outcomeId = self~actionEventKey(talkRow["experiment_id"], talkRow["hand_no"], talkRow["speaker"], nextSeq)
    self~recordOutcome(talkRow["speaker"], talkRow["target"], talkRow["token"], talkRow["talk_class"], nextAction, nextStreet, nextToCall, outcomeId, outcomeSeen)
    pairedKey = outcomeId
    pairedActions[pairedKey] = 1
  end

  /* Silent-baseline samples are intentionally disjoint from talk-conditioned
     samples: only public actions that were not the speaker's next betting
     action after one or more table-talk events are counted here. */
  do i = 1 to actionResult~rows~items
    actionRow = actionResult~rows[i]
    pairedKey = self~actionEventKey(actionRow["experiment_id"], actionRow["hand_no"], actionRow["player_name"], actionRow["seq"])
    if pairedActions~hasIndex(pairedKey) then iterate
    actorKey = translate(actionRow["player_name"])
    self~incrementActionStat(noTalkBaselineStats, actorKey, actionRow["action"])
    context = self~contextKey(actionRow["street"], actionRow["to_call"])
    self~incrementActionStat(noTalkContextBaselineStats, actorKey || "|" || context, actionRow["action"])
  end

::method recordTalk
  expose pending recentClass recentToken recentTarget recentHand currentExperimentId
  use arg experimentId, handNo, seq, speaker, target, token, talkClass
  key = self~handActorKey(experimentId, handNo, speaker)
  if \pending~hasIndex(key) then pending[key] = .array~new
  event = .directory~new
  event["seq"] = seq
  event["target"] = target
  event["token"] = translate(token)
  event["class"] = translate(talkClass)
  pending[key]~append(event)

  if experimentId = currentExperimentId then do
    actorKey = translate(speaker)
    recentClass[actorKey] = translate(talkClass)
    recentToken[actorKey] = translate(token)
    recentTarget[actorKey] = target
    recentHand[actorKey] = handNo
  end

::method recordAction
  expose pending baselineStats noTalkBaselineStats contextBaselineStats noTalkContextBaselineStats recentContextStreet recentContextFacing currentExperimentId
  use arg experimentId, handNo, seq, speaker, action, street = "", toCall = 0
  actorKey = translate(speaker)
  self~incrementActionStat(baselineStats, actorKey, action)
  context = self~contextKey(street, toCall)
  self~incrementActionStat(contextBaselineStats, actorKey || "|" || context, action)

  key = self~handActorKey(experimentId, handNo, speaker)
  matchedTalk = .false
  outcomeSeen = .directory~new
  outcomeId = self~actionEventKey(experimentId, handNo, speaker, seq)
  if pending~hasIndex(key) then do
    events = pending[key]
    keep = .array~new
    do i = 1 to events~items
      event = events[i]
      if event["seq"] < seq then do
        self~recordOutcome(speaker, event["target"], event["token"], event["class"], action, street, toCall, outcomeId, outcomeSeen)
        matchedTalk = .true
      end
      else keep~append(event)
    end
    if experimentId = currentExperimentId then do
      if matchedTalk then do
        recentContextStreet[actorKey] = translate(street)
        if toCall > 0 then recentContextFacing[actorKey] = "FACING"
        else recentContextFacing[actorKey] = "FREE"
      end
    end
    if keep~items = 0 then pending~remove(key)
    else pending[key] = keep
  end

  if \matchedTalk then do
    self~incrementActionStat(noTalkBaselineStats, actorKey, action)
    self~incrementActionStat(noTalkContextBaselineStats, actorKey || "|" || context, action)
  end

::method recordOutcome private
  expose classStats tokenStats targetStats classContextStats tokenContextStats targetContextStats
  use arg speaker, target, token, talkClass, action, street = "", toCall = 0, outcomeId, outcomeSeen
  actorKey = translate(speaker)
  classKey = actorKey || "|" || translate(talkClass)
  tokenKey = actorKey || "|" || translate(token)
  targetKey = classKey || "|" || translate(target)
  context = self~contextKey(street, toCall)

  /* The unit of behavioural evidence is the speaker's betting decision, not
     the number of utterances made before it.  Repeated speech is still fully
     persisted in table_talk, but a class/token/target may contribute at most
     one outcome sample for a single action event. */
  self~incrementUniqueActionStat(classStats, classKey, action, "CLASS|" || classKey || "|" || outcomeId, outcomeSeen)
  self~incrementUniqueActionStat(tokenStats, tokenKey, action, "TOKEN|" || tokenKey || "|" || outcomeId, outcomeSeen)
  self~incrementUniqueActionStat(targetStats, targetKey, action, "TARGET|" || targetKey || "|" || outcomeId, outcomeSeen)
  self~incrementUniqueActionStat(classContextStats, classKey || "|" || context, action, "CLASSCTX|" || classKey || "|" || context || "|" || outcomeId, outcomeSeen)
  self~incrementUniqueActionStat(tokenContextStats, tokenKey || "|" || context, action, "TOKENCTX|" || tokenKey || "|" || context || "|" || outcomeId, outcomeSeen)
  self~incrementUniqueActionStat(targetContextStats, targetKey || "|" || context, action, "TARGETCTX|" || targetKey || "|" || context || "|" || outcomeId, outcomeSeen)

::method incrementUniqueActionStat private
  use arg stats, key, action, uniqueKey, outcomeSeen
  if outcomeSeen~hasIndex(uniqueKey) then return
  outcomeSeen[uniqueKey] = 1
  self~incrementActionStat(stats, key, action)

::method contextKey private
  use arg street, toCall = 0
  streetName = translate(street~strip)
  if streetName = "" then streetName = "UNKNOWN"
  facing = "FREE"
  if toCall > 0 then facing = "FACING"
  return streetName || "|" || facing

::method bestContextForClass private
  expose classContextStats
  use arg speaker, talkClass
  actorKey = translate(speaker)
  classKey = actorKey || "|" || translate(talkClass)
  streets = .array~of("PREFLOP", "FLOP", "TURN", "RIVER", "UNKNOWN")
  states = .array~of("FACING", "FREE")
  best = ""
  bestN = 0
  do i = 1 to streets~items
    do j = 1 to states~items
      context = streets[i] || "|" || states[j]
      key = classKey || "|" || context
      if \classContextStats~hasIndex(key) then iterate
      n = classContextStats[key]["n"]
      if n > bestN then do
        bestN = n
        best = context
      end
    end
  end
  return best

::method incrementActionStat private
  use arg stats, key, action
  if \stats~hasIndex(key) then stats[key] = self~newStat
  stat = stats[key]
  stat["n"] += 1
  actionName = translate(action)
  if stat~hasIndex(actionName) then stat[actionName] += 1

::method newStat private
  stat = .directory~new
  stat["n"] = 0
  stat["FOLD"] = 0
  stat["CHECK"] = 0
  stat["CALL"] = 0
  stat["RAISE"] = 0
  return stat

::method handActorKey private
  use arg experimentId, handNo, speaker
  return experimentId || "|" || handNo || "|" || translate(speaker)

::method actionEventKey private
  use arg experimentId, handNo, speaker, seq
  return experimentId || "|" || handNo || "|" || translate(speaker) || "|" || seq

::method bestClass private
  expose classStats
  use arg speaker
  actorKey = translate(speaker)
  classes = .array~of("PRESSURE", "CHALLENGE", "INTIMIDATE", "NEEDLE", "CLAIM", "RESPECT")
  best = ""
  bestN = 0
  do i = 1 to classes~items
    key = actorKey || "|" || classes[i]
    if \classStats~hasIndex(key) then iterate
    n = classStats[key]["n"]
    if n > bestN then do
      bestN = n
      best = classes[i]
    end
  end
  return best

::method confidence private
  use arg n
  if n >= 15 then return "HIGH"
  if n >= 5 then return "MEDIUM"
  return "LOW"

::method countsText private
  use arg stat
  return "RAISE=" || stat["RAISE"] || " CALL=" || stat["CALL"] || " CHECK=" || stat["CHECK"] || " FOLD=" || stat["FOLD"]

::method deltaText private
  use arg talkStat, silentStat
  if talkStat["n"] <= 0 then return ""
  if silentStat["n"] <= 0 then return ""
  actions = .array~of("RAISE", "CALL", "CHECK", "FOLD")
  txt = ""
  do i = 1 to actions~items
    actionName = actions[i]
    talkRate = 100 * talkStat[actionName] / talkStat["n"]
    silentRate = 100 * silentStat[actionName] / silentStat["n"]
    delta = talkRate - silentRate
    piece = format(delta, 5, 1)~strip
    if delta > 0 then piece = "+" || piece
    if txt \= "" then txt ||= " "
    txt ||= actionName || "=" || piece || "pp"
  end
  return txt

::method promptFor
  expose currentExperimentId baselineStats noTalkBaselineStats classStats tokenStats targetStats contextBaselineStats noTalkContextBaselineStats classContextStats tokenContextStats targetContextStats recentClass recentToken recentTarget recentHand recentContextStreet recentContextFacing lastPromptEvidence lastPromptText
  use arg table, viewer
  viewerKey = translate(viewer~name)
  promptMap = .directory~new
  lastPromptEvidence[viewerKey] = promptMap
  nl = "0a"x
  candidates = .array~new
  ps = table~players
  do i = 1 to ps~items
    opponent = ps[i]
    if opponent == viewer then iterate
    if opponent~stack <= 0 then iterate
    actorKey = translate(opponent~name)
    talkClass = ""
    talkToken = ""
    isRecent = .false
    if recentHand~hasIndex(actorKey) then do
      if recentHand[actorKey] = table~handNumber then do
        talkClass = recentClass[actorKey]
        talkToken = recentToken[actorKey]
        isRecent = .true
      end
    end
    if talkClass = "" then talkClass = self~bestClass(opponent~name)
    if talkClass = "" then iterate
    classKey = actorKey || "|" || talkClass
    if \classStats~hasIndex(classKey) then iterate
    stat = classStats[classKey]
    if stat["n"] <= 0 then iterate
    item = .directory~new
    item["name"] = opponent~name
    item["actor_key"] = actorKey
    item["class"] = talkClass
    item["token"] = talkToken
    item["recent"] = isRecent
    item["score"] = stat["n"]
    if isRecent then item["score"] += 100000
    candidates~append(item)
  end

  do i = 1 to candidates~items - 1
    do j = i + 1 to candidates~items
      if candidates[j]["score"] > candidates[i]["score"] then do
        swap = candidates[i]
        candidates[i] = candidates[j]
        candidates[j] = swap
      end
    end
  end

  txt = "SOCIAL EVIDENCE (PUBLIC EMPIRICAL HISTORY)" || nl
  txt ||= "Evidence only: speech is not assumed truthful and does not reveal hidden cards." || nl
  txt ||= "Your objective remains long-run chip bankroll. Use verbal patterns only when the observed public-action samples appear predictive." || nl
  txt ||= "Each talk statistic uses betting decisions as the sample unit: repeated same-class/token/target utterances before one action remain persisted but count once for that outcome." || nl
  txt ||= "Matched context compares the same speaker on the same street and whether that action faced a bet (FACING) or was free to check (FREE)." || nl
  txt ||= "The no-talk baseline is disjoint: it contains only matched public actions that were not that speaker's next action after table talk. Deltas are neutral percentage-point differences, not an interpretation of motive." || nl
  if candidates~items = 0 then do
    txt ||= "No paired historical talk/action samples are available yet." || nl
    lastPromptText[viewerKey] = txt
    return txt
  end

  limit = candidates~items
  if limit > 6 then limit = 6
  do i = 1 to limit
    item = candidates[i]
    actorKey = item["actor_key"]
    classKey = actorKey || "|" || item["class"]
    classStat = classStats[classKey]
    evidenceId = "E" || i
    evidence = .directory~new
    evidence["id"] = evidenceId
    evidence["speaker"] = item["name"]
    evidence["class"] = item["class"]
    evidence["token"] = item["token"]
    evidence["n"] = classStat["n"]
    evidence["confidence"] = self~confidence(classStat["n"])
    promptMap[evidenceId] = evidence
    prefix = evidenceId || " " || item["name"] || " " || item["class"]
    if item["recent"] then prefix ||= " (seen this hand)"
    txt ||= prefix || ": n=" || classStat["n"] || " confidence=" || self~confidence(classStat["n"]) || " next{" || self~countsText(classStat) || "}"
    if baselineStats~hasIndex(actorKey) then do
      base = baselineStats[actorKey]
      txt ||= " baseline_n=" || base["n"] || " baseline{" || self~countsText(base) || "}"
    end
    txt ||= nl

    context = ""
    if item["recent"] then do
      if recentContextStreet~hasIndex(actorKey) then do
        if recentContextFacing~hasIndex(actorKey) then context = recentContextStreet[actorKey] || "|" || recentContextFacing[actorKey]
      end
    end
    if context = "" then context = self~bestContextForClass(item["name"], item["class"])
    if context \= "" then do
      contextClassKey = classKey || "|" || context
      contextBaseKey = actorKey || "|" || context
      if classContextStats~hasIndex(contextClassKey) then do
        contextStat = classContextStats[contextClassKey]
        txt ||= "  matched context " || changestr("|", context, "/") || ": talk_n=" || contextStat["n"] || " next{" || self~countsText(contextStat) || "}"
        if contextBaselineStats~hasIndex(contextBaseKey) then do
          contextBase = contextBaselineStats[contextBaseKey]
          txt ||= " baseline_n=" || contextBase["n"] || " baseline{" || self~countsText(contextBase) || "}"
        end
        if noTalkContextBaselineStats~hasIndex(contextBaseKey) then do
          silentBase = noTalkContextBaselineStats[contextBaseKey]
          txt ||= " no_talk_n=" || silentBase["n"] || " no_talk{" || self~countsText(silentBase) || "}"
          deltaText = self~deltaText(contextStat, silentBase)
          if deltaText \= "" then txt ||= " delta_vs_no_talk{" || deltaText || "}"
        end
        else txt ||= " no_talk_n=0"
        txt ||= nl
      end
    end

    if item["token"] \= "" then do
      tokenKey = actorKey || "|" || item["token"]
      if tokenStats~hasIndex(tokenKey) then do
        tokenStat = tokenStats[tokenKey]
        txt ||= "  token " || item["token"] || ": n=" || tokenStat["n"] || " next{" || self~countsText(tokenStat) || "}" || nl
        if context \= "" then do
          contextTokenKey = tokenKey || "|" || context
          if tokenContextStats~hasIndex(contextTokenKey) then do
            tokenContextStat = tokenContextStats[contextTokenKey]
            txt ||= "    same context: n=" || tokenContextStat["n"] || " next{" || self~countsText(tokenContextStat) || "}" || nl
          end
        end
      end
    end

    targetKey = classKey || "|" || translate(viewer~name)
    if targetStats~hasIndex(targetKey) then do
      targetStat = targetStats[targetKey]
      txt ||= "  directed at you: n=" || targetStat["n"] || " next{" || self~countsText(targetStat) || "}" || nl
      if context \= "" then do
        contextTargetKey = targetKey || "|" || context
        if targetContextStats~hasIndex(contextTargetKey) then do
          targetContextStat = targetContextStats[contextTargetKey]
          txt ||= "    same context: n=" || targetContextStat["n"] || " next{" || self~countsText(targetContextStat) || "}" || nl
        end
      end
    end
  end
  lastPromptText[viewerKey] = txt
  return txt

::method promptSnapshot
  expose lastPromptEvidence lastPromptText
  use arg viewerName
  viewerKey = translate(viewerName)
  snapshot = .directory~new
  snapshot["text"] = ""
  snapshot["count"] = 0
  if lastPromptText~hasIndex(viewerKey) then snapshot["text"] = lastPromptText[viewerKey]
  if lastPromptEvidence~hasIndex(viewerKey) then snapshot["count"] = lastPromptEvidence[viewerKey]~items
  return snapshot

::method evidenceClaim
  expose lastPromptEvidence
  use arg viewerName, evidenceId
  viewerKey = translate(viewerName)
  id = translate(evidenceId~strip)
  if id = "" then return .nil
  if id = "NONE" then return .nil
  if \lastPromptEvidence~hasIndex(viewerKey) then return .nil
  promptMap = lastPromptEvidence[viewerKey]
  if \promptMap~hasIndex(id) then return .nil
  return promptMap[id]

::class PokerExperimentStore public subclass PokerAlchemyObject
::attribute root get
::attribute sql get
::attribute engine get
::attribute experimentId get
::attribute socialModel get
::attribute promptVerifier get

::method init
  expose root sql engine experimentId startStacks actionSeq socialModel promptVerifier
  use arg root, players, requestedExperimentId = .nil
  self~ensureDatabase(root)
  engine = .FederatedDatabaseEngine~new(root)
  mapping = .ObjectTableMapping~new("live_players")
  ignore = mapping~column("name", "VARCHAR", "name")
  ignore = mapping~column("stack", "INTEGER", "stack")
  ignore = mapping~column("psychic", "BOOLEAN", "isPsychic")
  ignore = mapping~column("team", "VARCHAR", "team")
  ignore = mapping~column("strategy_type", "VARCHAR", "strategyType")
  ignore = mapping~column("strategy_objective", "VARCHAR", "strategyObjective")
  ignore = mapping~identity("name")
  if \engine~register("live_players", players, mapping) then raise syntax 93.900 array("Cannot register live_players")
  sql = .NoSQLServerSQL~new(engine)
  self~schema
  if requestedExperimentId == .nil then experimentId = self~nextExperimentId
  else experimentId = requestedExperimentId
  startStacks = .directory~new
  actionSeq = 0
  socialModel = .PokerSocialEvidenceModel~new(sql, experimentId)
  promptVerifier = .PokerPromptManifestVerifier~new
  self~initPokerAlchemy("EXPERIMENT_STORE", "NoSQLServer-backed public experiment evidence boundary")
  self~registerStateVariable("root", "INTERNAL", "database root path")
  self~registerStateVariable("experimentId", "CUSTOMER", "current experiment identifier")
  self~registerExternalRequirement("library", "nosqlserver", "0.77", .true)
  self~registerMethodContract("BEGINEXPERIMENT", "Persist a new experiment identity", .array~of("LABEL"), "ANY", .false, "AUTO", "CUSTOMER", "NORMAL", "EXTERNAL", "NONE")
  self~registerMethodContract("RECORDEXPERIMENTCONTEXT", "Persist reproducibility metadata for the experiment", .array~of("CASINO_SEED", "AI_MODEL", "PROMPT_VERSION", "TABLE_CONFIGURATION", "RUN_TIMESTAMP"), "ANY", .false, "AUTO", "CUSTOMER", "NORMAL", "EXTERNAL", "NONE")
  self~recordRelationship("SOCIAL_MODEL", socialModel, "experiment social evidence model", "INTERNAL")
  self~recordRelationship("PROMPT_MANIFEST_VERIFIER", promptVerifier, "live/counterfactual AI prompt structural verifier", "INTERNAL")
  self~recordRelationship("DATABASE_ENGINE", engine, "NoSQLServer federated engine", "INTERNAL")

::method ensureDatabase private
  use arg root
  call SysFileTree root || "/database.yaml", "dbcheck.", "FO"
  if dbcheck.0 = 1 then return
  call SysMkDir root
  call SysMkDir root || "/tables"
  call lineout root || "/database.yaml", "name: psychic_poker"
  call lineout root || "/database.yaml", "formatVersion: 1"
  call lineout root || "/database.yaml", "tables: []"
  call lineout root || "/database.yaml"

::method schema private
  expose engine
  if engine~table("experiment") == .nil then self~execSQL("CREATE TABLE experiment (experiment_id INTEGER PRIMARY KEY, label VARCHAR)")
  if engine~table("experiment_context") == .nil then self~execSQL("CREATE TABLE experiment_context (experiment_id INTEGER PRIMARY KEY, casino_seed INTEGER, ai_model VARCHAR, prompt_version VARCHAR, table_configuration VARCHAR, run_timestamp VARCHAR)")
  if engine~table("hand_result") == .nil then self~execSQL("CREATE TABLE hand_result (experiment_id INTEGER, hand_no INTEGER, table_name VARCHAR, player_name VARCHAR, psychic BOOLEAN, team VARCHAR, strategy_type VARCHAR, strategy_objective VARCHAR, start_stack INTEGER, end_stack INTEGER, profit INTEGER, finish_type VARCHAR)")
  if engine~table("action_log") == .nil then self~execSQL("CREATE TABLE action_log (experiment_id INTEGER, hand_no INTEGER, seq INTEGER, table_name VARCHAR, street VARCHAR, player_name VARCHAR, action VARCHAR, amount INTEGER, equity DECIMAL, pot_odds DECIMAL, to_call INTEGER, psychic BOOLEAN, team VARCHAR, strategy_type VARCHAR, strategy_objective VARCHAR, exploit_leverage DECIMAL)")
  if engine~table("table_talk") == .nil then self~execSQL("CREATE TABLE table_talk (experiment_id INTEGER, hand_no INTEGER, seq INTEGER, street VARCHAR, speaker VARCHAR, target VARCHAR, token VARCHAR, talk_class VARCHAR, phrase VARCHAR, pressure_delta DECIMAL, provocation_delta DECIMAL)")
  if engine~table("table_talk_structured") == .nil then self~execSQL("CREATE TABLE table_talk_structured (experiment_id INTEGER, hand_no INTEGER, seq INTEGER, utterance_id VARCHAR, schema_version VARCHAR, communicative_act VARCHAR, intended_act VARCHAR, intended_outcome VARCHAR, authority_kind VARCHAR, authority_id VARCHAR, sealed BOOLEAN)")
  if engine~table("ai_social_decision") == .nil then self~execSQL("CREATE TABLE ai_social_decision (experiment_id INTEGER, hand_no INTEGER, seq INTEGER, player_name VARCHAR, street VARCHAR, action VARCHAR, amount INTEGER, evidence_id VARCHAR, evidence_valid BOOLEAN, evidence_speaker VARCHAR, evidence_class VARCHAR, evidence_token VARCHAR, evidence_n INTEGER, evidence_confidence VARCHAR, shadow_action VARCHAR, shadow_amount INTEGER, shadow_available BOOLEAN, action_changed BOOLEAN, amount_changed BOOLEAN)")
  if engine~table("ai_social_effect") == .nil then self~execSQL("CREATE TABLE ai_social_effect (experiment_id INTEGER, hand_no INTEGER, seq INTEGER, player_name VARCHAR, street VARCHAR, main_action VARCHAR, main_amount INTEGER, probe_mode INTEGER, social_present BOOLEAN, evidence_count INTEGER, evidence_snapshot VARCHAR, evidence_id VARCHAR, attribution_status VARCHAR, shadow_action VARCHAR, shadow_amount INTEGER, shadow_available BOOLEAN, control_action VARCHAR, control_amount INTEGER, control_available BOOLEAN, control_matches_main BOOLEAN, counterfactual_diff BOOLEAN, effect_status VARCHAR, unattributed_social_effect BOOLEAN)")
  if engine~table("ai_prompt_boundary") == .nil then self~execSQL("CREATE TABLE ai_prompt_boundary (experiment_id INTEGER, hand_no INTEGER, seq INTEGER, player_name VARCHAR, street VARCHAR, prompt_kind VARCHAR, include_social BOOLEAN, boundary_status VARCHAR, field_count INTEGER, public_fields INTEGER, customer_fields INTEGER, self_private_fields INTEGER, history_fields INTEGER, social_fields INTEGER, rejected_fields INTEGER, prompt_length INTEGER, prompt_sha512 VARCHAR)")
  if engine~table("ai_prompt_manifest") == .nil then self~execSQL("CREATE TABLE ai_prompt_manifest (experiment_id INTEGER, hand_no INTEGER, seq INTEGER, player_name VARCHAR, street VARCHAR, prompt_kind VARCHAR, include_social BOOLEAN, manifest_version VARCHAR, field_manifest VARCHAR, core_manifest VARCHAR, social_manifest VARCHAR, core_field_count INTEGER, social_field_count INTEGER, core_contract_status VARCHAR)")
  if engine~table("psychic_capability") == .nil then self~execSQL("CREATE TABLE psychic_capability (experiment_id INTEGER, hand_no INTEGER, observer_name VARCHAR, target_name VARCHAR, capability_type VARCHAR, detail VARCHAR)")
  if engine~table("psychic_observation") == .nil then self~execSQL("CREATE TABLE psychic_observation (experiment_id INTEGER, hand_no INTEGER, observer_name VARCHAR, target_name VARCHAR, observation_type VARCHAR, detail VARCHAR)")
  if engine~table("pot_settlement") == .nil then self~execSQL("CREATE TABLE pot_settlement (experiment_id INTEGER, hand_no INTEGER, street VARCHAR, pot_index INTEGER, pot_type VARCHAR, amount INTEGER, contribution_cap INTEGER, eligible_count INTEGER, winner_name VARCHAR, winner_share INTEGER)")
  if engine~table("bankroll_sample") == .nil then self~execSQL("CREATE TABLE bankroll_sample (experiment_id INTEGER, hand_no INTEGER, player_name VARCHAR, stack INTEGER)")
  if engine~table("oracle_model_snapshot") == .nil then self~execSQL("CREATE TABLE oracle_model_snapshot (experiment_id INTEGER PRIMARY KEY, source_experiments INTEGER, successful_hands INTEGER, successful_actions INTEGER, model_version VARCHAR)")

::method nextExperimentId private
  expose sql
  r = sql~execute("SELECT experiment_id FROM experiment ORDER BY experiment_id DESC LIMIT 1")
  if r~status \= .Error~SUCCESS then do
    say "SQL FAILED while allocating experiment id"
    say "status=" r~status "error=" r~error "message=" r~message
    raise syntax 93.900 array("Cannot allocate experiment id")
  end
  if r~rows~items = 0 then return 1
  lastRow = r~rows[1]
  return lastRow["experiment_id"] + 1

::method beginExperiment
  expose experimentId
  use arg label
  self~alchemyTouch("BEGIN_EXPERIMENT")
  row = .table~new
  row["experiment_id"] = experimentId
  row["label"] = label
  self~nativeInsert("experiment", row)

::method recordExperimentContext
  expose experimentId
  use arg casinoSeed, aiModel, promptVersion, tableConfiguration, runTimestamp = ""
  self~alchemyTouch("RECORD_EXPERIMENT_CONTEXT")
  if runTimestamp = "" then runTimestamp = date("S") || "T" || time("L")
  row = .table~new
  row["experiment_id"] = experimentId
  row["casino_seed"] = casinoSeed
  row["ai_model"] = aiModel
  row["prompt_version"] = promptVersion
  row["table_configuration"] = tableConfiguration
  row["run_timestamp"] = runTimestamp
  self~nativeInsert("experiment_context", row)

::method recordOracleModel
  expose experimentId
  use arg model
  if model == .nil then return
  row = .table~new
  row["experiment_id"] = experimentId
  row["source_experiments"] = model~experimentCount
  row["successful_hands"] = model~completedHands
  row["successful_actions"] = model~learnedActions
  row["model_version"] = model~modelVersion
  self~nativeInsert("oracle_model_snapshot", row)

::method handStarted
  expose startStacks actionSeq
  use arg table
  startStacks = .directory~new
  actionSeq = 0
  ps = table~players
  do i = 1 to ps~items
    startStacks[ps[i]~name] = ps[i]~stack
  end

::method capabilitiesCaptured
  use arg table
  ps = table~players
  do i = 1 to ps~items
    viewer = ps[i]
    if \viewer~isPsychic then iterate
    do j = 1 to ps~items
      target = ps[j]
      if target == viewer then iterate
      if \target~isPsychic then do
        self~insertCapability(table~handNumber, viewer~name, target~name, "CARD_READ_AVAILABLE", "non-psychic hole cards")
        self~insertCapability(table~handNumber, viewer~name, target~name, "STRATEGY_READ_AVAILABLE", "non-psychic strategy")
      end
      else if target~team = viewer~team then
        self~insertCapability(table~handNumber, viewer~name, target~name, "TEAM_MESSAGE_AVAILABLE", "same-table same-team hole cards")
    end
  end

::method insertCapability private
  expose experimentId
  use arg handNo, observerName, targetName, capabilityType, detail
  row = .table~new
  row["experiment_id"] = experimentId; row["hand_no"] = handNo
  row["observer_name"] = observerName; row["target_name"] = targetName
  row["capability_type"] = capabilityType; row["detail"] = detail
  self~nativeInsert("psychic_capability", row)

::method psychicObservation
  expose experimentId
  use arg table, viewer, target, observationType, detail
  row = .table~new
  row["experiment_id"] = experimentId; row["hand_no"] = table~handNumber
  row["observer_name"] = viewer~name; row["target_name"] = target~name
  row["observation_type"] = observationType; row["detail"] = detail
  self~nativeInsert("psychic_observation", row)

::method uncalledReturned
  expose experimentId
  use arg table, player, amount
  row = .table~new
  row["experiment_id"] = experimentId; row["hand_no"] = table~handNumber
  row["street"] = table~street; row["pot_index"] = 0; row["pot_type"] = "UNCALLED_RETURN"
  row["amount"] = amount; row["contribution_cap"] = 0; row["eligible_count"] = 1
  row["winner_name"] = player~name; row["winner_share"] = amount
  self~nativeInsert("pot_settlement", row)

::method potSettled
  expose experimentId
  use arg table, potIndex, potType, amount, cap, winner, winnerShare, eligibleCount
  row = .table~new
  row["experiment_id"] = experimentId; row["hand_no"] = table~handNumber
  row["street"] = table~street; row["pot_index"] = potIndex; row["pot_type"] = potType
  row["amount"] = amount; row["contribution_cap"] = cap; row["eligible_count"] = eligibleCount
  row["winner_name"] = winner~name; row["winner_share"] = winnerShare
  self~nativeInsert("pot_settlement", row)

::method tableTalk
  expose experimentId actionSeq
  use arg table, speaker, target, entry, utterance = .nil, structuredSummary = .nil
  actionSeq += 1
  row = .table~new
  row["experiment_id"] = experimentId
  row["hand_no"] = table~handNumber
  row["seq"] = actionSeq
  row["street"] = table~street
  row["speaker"] = speaker~name
  row["target"] = target~name
  row["token"] = entry~token
  row["talk_class"] = entry~talkClass
  row["phrase"] = entry~phrase
  row["pressure_delta"] = entry~pressureDelta
  row["provocation_delta"] = entry~provocationDelta
  self~nativeInsert("table_talk", row)

  if structuredSummary \== .nil then do
    sr = .table~new
    sr["experiment_id"] = experimentId
    sr["hand_no"] = table~handNumber
    sr["seq"] = actionSeq
    sr["utterance_id"] = structuredSummary["utterance_id"]
    sr["schema_version"] = structuredSummary["schema"]
    sr["communicative_act"] = structuredSummary["communicative_act"]
    sr["intended_act"] = structuredSummary["intended_act"]
    sr["intended_outcome"] = structuredSummary["intended_outcome"]
    sr["authority_kind"] = structuredSummary["authority_kind"]
    sr["authority_id"] = structuredSummary["authority_id"]
    sr["sealed"] = structuredSummary["sealed"]
    self~nativeInsert("table_talk_structured", sr)
  end

  socialModel = self~socialModel
  socialModel~recordTalk(experimentId, table~handNumber, actionSeq, speaker~name, target~name, entry~token, entry~talkClass)

::method recordPromptBoundary private
  expose experimentId promptVerifier
  use arg table, player, seq, promptKind, includeSocial = .true
  audit = table~promptAuditFor(player~name, includeSocial)
  if audit == .nil then raise syntax 93.900 array("Missing AI prompt boundary audit for " || player~name || " kind=" || promptKind)
  if audit["boundary_status"] \= "PASS" then raise syntax 93.900 array("AI prompt boundary did not pass for " || player~name || " kind=" || promptKind)
  row = .table~new
  row["experiment_id"] = experimentId
  row["hand_no"] = table~handNumber
  row["seq"] = seq
  row["player_name"] = player~name
  row["street"] = table~street
  row["prompt_kind"] = promptKind
  if includeSocial then row["include_social"] = 1
  else row["include_social"] = 0
  row["boundary_status"] = audit["boundary_status"]
  row["field_count"] = audit["field_count"]
  row["public_fields"] = audit["public_fields"]
  row["customer_fields"] = audit["customer_fields"]
  row["self_private_fields"] = audit["self_private_fields"]
  row["history_fields"] = audit["history_fields"]
  row["social_fields"] = audit["social_fields"]
  row["rejected_fields"] = audit["rejected_fields"]
  row["prompt_length"] = audit["prompt_length"]
  row["prompt_sha512"] = table~promptStrongDigestFor(player~name, includeSocial)
  if row["prompt_sha512"] = "" then raise syntax 93.900 array("Missing AI prompt bytes for strong digest " || player~name || " kind=" || promptKind)
  self~nativeInsert("ai_prompt_boundary", row)

  contractStatus = "REFERENCE"
  ignore = promptVerifier~verify(audit)
  if promptKind = "NO_SOCIAL" then do
    mainAudit = table~promptAuditFor(player~name, .true)
    contractStatus = promptVerifier~verifyCounterfactual(mainAudit, audit)
  end
  manifest = .table~new
  manifest["experiment_id"] = experimentId
  manifest["hand_no"] = table~handNumber
  manifest["seq"] = seq
  manifest["player_name"] = player~name
  manifest["street"] = table~street
  manifest["prompt_kind"] = promptKind
  if includeSocial then manifest["include_social"] = 1
  else manifest["include_social"] = 0
  manifest["manifest_version"] = audit["manifest_version"]
  manifest["field_manifest"] = audit["field_manifest"]
  manifest["core_manifest"] = audit["core_manifest"]
  manifest["social_manifest"] = audit["social_manifest"]
  manifest["core_field_count"] = audit["core_field_count"]
  manifest["social_field_count"] = audit["social_manifest_fields"]
  manifest["core_contract_status"] = contractStatus
  self~nativeInsert("ai_prompt_manifest", manifest)

::method actionTaken
  expose experimentId actionSeq
  use arg table, player, decision, toCall
  actionSeq += 1
  row = .table~new
  row["experiment_id"] = experimentId; row["hand_no"] = table~handNumber; row["seq"] = actionSeq
  row["table_name"] = table~name; row["street"] = table~street; row["player_name"] = player~name
  row["action"] = decision~action; row["amount"] = decision~amount; row["equity"] = decision~equity
  row["pot_odds"] = decision~potOdds; row["to_call"] = toCall
  row["psychic"] = player~isPsychic; row["team"] = player~team
  row["strategy_type"] = player~strategyType; row["strategy_objective"] = player~strategyObjective
  row["exploit_leverage"] = decision~exploitLeverage
  self~nativeInsert("action_log", row)
  socialModel = self~socialModel
  auditLiveLLM = .false
  strategyType = player~strategyType
  if strategyType = "AI_GROK" then auditLiveLLM = .true
  else if strategyType = "AI_GEMINI" then auditLiveLLM = .true
  if auditLiveLLM then do
    audit = .table~new
    audit["experiment_id"] = experimentId
    audit["hand_no"] = table~handNumber
    audit["seq"] = actionSeq
    audit["player_name"] = player~name
    audit["street"] = table~street
    audit["action"] = decision~action
    audit["amount"] = decision~amount
    evidenceId = decision~socialEvidenceId~strip~upper
    if evidenceId = "" then evidenceId = "NONE"
    audit["evidence_id"] = evidenceId
    evidence = socialModel~evidenceClaim(player~name, evidenceId)
    if evidence == .nil then do
      audit["evidence_valid"] = 0
      audit["evidence_speaker"] = ""
      audit["evidence_class"] = ""
      audit["evidence_token"] = ""
      audit["evidence_n"] = 0
      audit["evidence_confidence"] = ""
    end
    else do
      audit["evidence_valid"] = 1
      audit["evidence_speaker"] = evidence["speaker"]
      audit["evidence_class"] = evidence["class"]
      audit["evidence_token"] = evidence["token"]
      audit["evidence_n"] = evidence["n"]
      audit["evidence_confidence"] = evidence["confidence"]
    end
    shadowAction = decision~shadowAction~strip~upper
    audit["shadow_action"] = shadowAction
    audit["shadow_amount"] = decision~shadowAmount
    if shadowAction = "" then do
      audit["shadow_available"] = 0
      audit["action_changed"] = 0
      audit["amount_changed"] = 0
    end
    else do
      audit["shadow_available"] = 1
      if shadowAction = decision~action then audit["action_changed"] = 0
      else audit["action_changed"] = 1
      if decision~shadowAmount = decision~amount then audit["amount_changed"] = 0
      else audit["amount_changed"] = 1
    end
    self~recordPromptBoundary(table, player, actionSeq, "MAIN", .true)
    if audit["shadow_available"] = 1 then self~recordPromptBoundary(table, player, actionSeq, "NO_SOCIAL", .false)
    self~nativeInsert("ai_social_decision", audit)

    snapshot = socialModel~promptSnapshot(player~name)
    effect = .table~new
    effect["experiment_id"] = experimentId
    effect["hand_no"] = table~handNumber
    effect["seq"] = actionSeq
    effect["player_name"] = player~name
    effect["street"] = table~street
    effect["main_action"] = decision~action
    effect["main_amount"] = decision~amount
    effect["social_present"] = 0
    if snapshot["count"] > 0 then effect["social_present"] = 1
    effect["evidence_count"] = snapshot["count"]
    effect["evidence_snapshot"] = snapshot["text"]
    effect["evidence_id"] = evidenceId
    attributionStatus = "NONE"
    if evidenceId \= "NONE" then do
      if audit["evidence_valid"] = 1 then attributionStatus = "VALID"
      else attributionStatus = "INVALID"
    end
    effect["attribution_status"] = attributionStatus
    effect["shadow_action"] = audit["shadow_action"]
    effect["shadow_amount"] = audit["shadow_amount"]
    effect["shadow_available"] = audit["shadow_available"]
    effect["control_action"] = decision~controlAction~strip~upper
    effect["control_amount"] = decision~controlAmount
    controlAvailable = 0
    if effect["control_action"] \= "" then controlAvailable = 1
    effect["control_available"] = controlAvailable
    controlMatches = 0
    if controlAvailable = 1 then do
      if effect["control_action"] = decision~action then do
        if effect["control_amount"] = decision~amount then controlMatches = 1
      end
    end
    effect["control_matches_main"] = controlMatches
    counterfactualDiff = 0
    if audit["shadow_available"] = 1 then do
      if audit["action_changed"] = 1 then counterfactualDiff = 1
      else if audit["amount_changed"] = 1 then counterfactualDiff = 1
    end
    effect["counterfactual_diff"] = counterfactualDiff

    probeMode = 0
    if audit["shadow_available"] = 1 then probeMode = 1
    if controlAvailable = 1 then probeMode = 2
    effect["probe_mode"] = probeMode

    effectStatus = "NO_PROBE"
    if probeMode = 1 then do
      if counterfactualDiff = 1 then effectStatus = "PAIR_SENSITIVITY"
      else effectStatus = "PAIR_NO_CHANGE"
    end
    else if probeMode = 2 then do
      if controlMatches = 0 then effectStatus = "MODEL_INSTABILITY"
      else do
        if counterfactualDiff = 1 then effectStatus = "STABLE_SOCIAL_EFFECT"
        else effectStatus = "STABLE_NO_EFFECT"
      end
    end
    effect["effect_status"] = effectStatus

    unattributed = 0
    if attributionStatus = "NONE" then do
      if effectStatus = "PAIR_SENSITIVITY" then unattributed = 1
      else if effectStatus = "STABLE_SOCIAL_EFFECT" then unattributed = 1
    end
    effect["unattributed_social_effect"] = unattributed
    self~nativeInsert("ai_social_effect", effect)
  end
  socialModel~recordAction(experimentId, table~handNumber, actionSeq, player~name, decision~action, table~street, toCall)

::method handCompleted
  expose experimentId startStacks
  use arg table, finishType
  ps = table~players
  do i = 1 to ps~items
    p = ps[i]; before = startStacks[p~name]; after = p~stack
    row = .table~new
    row["experiment_id"] = experimentId; row["hand_no"] = table~handNumber
    row["table_name"] = table~name; row["player_name"] = p~name; row["psychic"] = p~isPsychic
    row["team"] = p~team; row["strategy_type"] = p~strategyType; row["strategy_objective"] = p~strategyObjective
    row["start_stack"] = before; row["end_stack"] = after; row["profit"] = after - before; row["finish_type"] = finishType
    self~nativeInsert("hand_result", row)
    sample = .table~new
    sample["experiment_id"] = experimentId; sample["hand_no"] = table~handNumber
    sample["player_name"] = p~name; sample["stack"] = after
    self~nativeInsert("bankroll_sample", sample)
  end

::method socialEvidenceFor
  expose socialModel
  use arg table, viewer
  return socialModel~promptFor(table, viewer)

::method execute
  expose sql
  use arg statement
  return sql~execute(statement)

::method nativeInsert private
  expose engine
  use arg tableName, row
  r = engine~insert(tableName, row)
  if r~status \= .Error~SUCCESS then do
    messageText = r~message
    if messageText~caselessPos("HALT condition") > 0 then do
      say "STORAGE INTERRUPTED while inserting into" tableName
      say "status=" r~status "error=" r~error "message=" messageText
      raise syntax 93.900 array("NoSQLServer operation interrupted; row was not a constraint violation")
    end
    say "STORAGE INSERT FAILED:" tableName
    say "status=" r~status "error=" r~error "message=" messageText
    raise syntax 93.900 array("NoSQLServer native insert failed")
  end
  return r

::method execSQL private
  expose sql
  use arg statement
  r = sql~execute(statement)
  if r~status \= .Error~SUCCESS then do
    messageText = r~message
    if messageText~caselessPos("HALT condition") > 0 then do
      say "SQL INTERRUPTED:" statement
      say "status=" r~status "error=" r~error "message=" messageText
      raise syntax 93.900 array("NoSQLServer SQL operation interrupted")
    end
    say "SQL FAILED:" statement
    say "status=" r~status "error=" r~error "message=" messageText
    raise syntax 93.900 array("NoSQLServer statement failed")
  end
  return r

::requires "nosqlserver/src/NoSQLServer.cls"

::requires "poker.cls"
