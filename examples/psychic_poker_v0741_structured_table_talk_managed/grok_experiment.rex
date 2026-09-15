parse arg hands root replaySeed
if hands = "" then hands = 5
if root = "" then root = "/tmp/hardworld-grok-db"

if replaySeed = "" then do
  casinoSeed = .CasinoSeed~fresh
  seedMode = "fresh"
end
else do
  casinoSeed = .CasinoSeed~normalize(replaySeed)
  seedMode = "replay"
end

config = .GameConfig~new(5, 10, 1000, 24, casinoSeed)
table = .PokerTable~new("grok-table", config)

balanced = .PlayerStrategy~new("balanced", 0.50, 0.08, 1.00)
psiTeam = .PsychicTeamStrategy~new("psi-team", 0.55, 0.10, 1.10)
psiAggressive = .PsychicAggressiveStrategy~new
grokFallback = .GrokFallbackStrategy~new
grokClient = .GrokAPIClient~new("grok-4.5")
grokStrategy = .GrokPokerStrategy~new(grokClient, grokFallback)
geminiFallback = .ResourceAwareStrategy~new
geminiClient = .GeminiAPIClient~new
geminiStrategy = .GeminiPokerStrategy~new(geminiClient, geminiFallback)
aggressiveStrategy = .AggressiveStrategy~new
geminiEmulatedStrategy = .GeminiEmulatedStrategy~new
resourceAwareStrategy = .ResourceAwareStrategy~new
apexStrategy = .ApexStrategy~new
paladinStrategy = .PaladinStrategy~new
blindBennyStrategy = .BlindPsychicStrategy~new
oracleStrategy = .OracleStrategy~new

ada = .Player~new("Ada", 1000, balanced)
grace = .Player~new("Grace", 1000, balanced)
grok = .Player~new("GROK", 1000, grokStrategy)
gemini = .Player~new("GEMINI", 1000, geminiStrategy)
hugo = .Player~new("Hugo", 1000, aggressiveStrategy)
noah = .Player~new("Noah", 1000, geminiEmulatedStrategy)
rosa = .Player~new("Rosa", 1000, resourceAwareStrategy)
apexBot = .Player~new("Apex", 1000, apexStrategy)
paladin = .Player~new("Paladin", 1000, paladinStrategy)
benny = .PsychicPlayer~new("Benny", 1000, blindBennyStrategy, "")
oracle = .Player~new("The_Oracle", 1000, oracleStrategy)
psiA = .PsychicPlayer~new("Eve", 1000, psiTeam, "RED")
psiB = .PsychicPlayer~new("Frank", 1000, psiTeam, "RED")
maya = .PsychicPlayer~new("Maya", 1000, psiAggressive, "RED")

seatCandidates = .array~of(ada, grace, grok, gemini, hugo, noah, rosa, apexBot, paladin, benny, oracle, psiA, psiB, maya)
seating = table~seatPlayersRandomized(seatCandidates)
seatOrder = ""
do i = 1 to seating~items
  if i > 1 then seatOrder ||= ","
  seatOrder ||= seating[i]~name
end

store = .PokerExperimentStore~new(root, table~players)
store~beginExperiment("blind-table-grok")
experimentId = store~experimentId
oracleModel = .OracleHistoryModel~new(store, experimentId)
oracleStrategy~historyModel = oracleModel
store~recordOracleModel(oracleModel)
tableConfig = "players=" || table~players~items || ";sb=" || config~smallBlind || ";bb=" || config~bigBlind || ";stack=" || config~startingStack || ";seats=" || seatOrder
store~recordExperimentContext(config~seed, "GROK=" || grokClient~model || ";GEMINI=" || geminiClient~model, "MULTI_AI_SOCIAL_ATTRIBUTION_V9", tableConfig)
table~observer(store)

say "== HardWorld Casino =="
say "Experiment ID:" store~experimentId
say "GROK model:" grokClient~model
say "GEMINI model:" geminiClient~model
say "Casino seed:" config~seed "(" || seedMode || ")"
say "Initial seats:" seatOrder
say "Oracle model:" oracleModel~modelVersion
say "Oracle history:" oracleModel~learnedActions "actions from" oracleModel~completedHands "completed ordinary-player hands across" oracleModel~experimentCount "experiments"
say "Blinds:" config~smallBlind "/" config~bigBlind " starting stack:" config~startingStack
say ""

do h = 1 to hands
  live = 0
  ps = table~players
  do i = 1 to ps~items
    if ps[i]~stack > 0 then live += 1
  end
  if live < 2 then leave
  say "--- hand" h "---"
  table~playHand
  table~showStacks
  say ""
end

say "=== AI ACTIONS ==="
call show store~execute("SELECT player_name,hand_no,street,action,amount,to_call FROM action_log WHERE experiment_id=" || experimentId || " AND (player_name='GROK' OR player_name='GEMINI') ORDER BY hand_no,seq")
say ""
say "=== AI PROMPT BOUNDARY ==="
call show store~execute("SELECT player_name,hand_no,street,prompt_kind,include_social,boundary_status,field_count,public_fields,customer_fields,history_fields,social_fields,rejected_fields,prompt_sha512 FROM ai_prompt_boundary WHERE experiment_id=" || experimentId || " ORDER BY hand_no,seq,prompt_kind")
say ""
say "=== AI PROMPT MANIFEST ==="
call show store~execute("SELECT player_name,hand_no,street,prompt_kind,manifest_version,core_field_count,social_field_count,core_contract_status FROM ai_prompt_manifest WHERE experiment_id=" || experimentId || " ORDER BY hand_no,seq,prompt_kind")
say ""
say "=== AI SOCIAL ATTRIBUTION ==="
call show store~execute("SELECT player_name,hand_no,street,action,evidence_id,evidence_valid,evidence_speaker,evidence_class,evidence_n,evidence_confidence,shadow_action,action_changed,amount_changed FROM ai_social_decision WHERE experiment_id=" || experimentId || " ORDER BY hand_no,seq")
say
say "=== AI SOCIAL EFFECTS ==="
call show store~execute("SELECT player_name,hand_no,street,probe_mode,evidence_id,attribution_status,evidence_count,control_action,shadow_action,effect_status,unattributed_social_effect FROM ai_social_effect WHERE experiment_id=" || experimentId || " ORDER BY hand_no,seq")
say ""
say "=== SOCIAL EVIDENCE SNAPSHOT: GROK ==="
grokEvidence = store~socialEvidenceFor(table, grok)
say grokEvidence
say "=== SOCIAL EVIDENCE SNAPSHOT: GEMINI ==="
geminiEvidence = store~socialEvidenceFor(table, gemini)
say geminiEvidence
say "=== FINAL STACKS ==="
call show store~execute("SELECT name,stack FROM live_players ORDER BY stack DESC")
exit 0

show: procedure
  use arg r
  if r~status \= .Error~SUCCESS then do
    say "QUERY ERROR" r~error r~message
    return
  end
  do i = 1 to r~rows~items
    row = r~rows[i]; names = row~values~allIndexes; line = ""
    do n over names
      if line <> "" then line ||= " | "
      line ||= n || "=" || row[n]
    end
    say line
  end
  return

::requires "poker.cls"
::requires "ai_grok.cls"
::requires "ai_gemini.cls"
::requires "experiment_store.cls"
