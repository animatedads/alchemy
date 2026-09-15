parse arg root
if root = "" then root = "/tmp/hardworld-prompt-boundary-storage-test"
call cleanTree root

cfg = .GameConfig~new(5,10,1000,4,738038)
ordinary = .PlayerStrategy~new("ordinary",0.5,0,1)
client = .PromptAuditFakeClient~new
grokStrategy = .GrokPokerStrategy~new(client,.PromptAuditFallback~new)
grok = .Player~new("GROK",1000,grokStrategy)
hugo = .Player~new("Hugo",1000,ordinary)
noah = .Player~new("Noah",1000,.GeminiEmulatedStrategy~new)
t = .PokerTable~new("prompt-audit-store",cfg)
t~verbose = .false
t~addPlayer(grok); t~addPlayer(hugo); t~addPlayer(noah)
store = .PokerExperimentStore~new(root,.array~of(grok,hugo,noah))
store~beginExperiment("prompt-boundary")
t~observer(store)

oldShadow = value("POKER_SOCIAL_SHADOW",, "ENVIRONMENT")
call value "POKER_SOCIAL_SHADOW", "2", "ENVIRONMENT"
d = grok~act(t,10,10,.true)
call value "POKER_SOCIAL_SHADOW", oldShadow, "ENVIRONMENT"
store~actionTaken(t,grok,d,10)

r = store~execute("SELECT prompt_kind,include_social,boundary_status,field_count,public_fields,customer_fields,self_private_fields,history_fields,social_fields,rejected_fields,prompt_length,prompt_sha512 FROM ai_prompt_boundary WHERE experiment_id=1 ORDER BY prompt_kind")
if r~status \= .Error~SUCCESS then raise syntax 93.900 array("ai_prompt_boundary query failed")
if r~rows~items \= 2 then raise syntax 93.900 array("strict social triplet should persist MAIN and NO_SOCIAL prompt audits")
main = .nil; shadow = .nil
do row over r~rows
  if row["prompt_kind"] = "MAIN" then main = row
  else if row["prompt_kind"] = "NO_SOCIAL" then shadow = row
end
if main == .nil then raise syntax 93.900 array("MAIN prompt audit missing")
if shadow == .nil then raise syntax 93.900 array("NO_SOCIAL prompt audit missing")
call assertAudit main, .true
call assertAudit shadow, .false
if main["prompt_sha512"] \= .SHA512~new(client~mainPrompt)~digest then raise syntax 93.900 array("stored MAIN prompt digest does not identify actual model input")
if shadow["prompt_sha512"] \= .SHA512~new(client~shadowPrompt)~digest then raise syntax 93.900 array("stored NO_SOCIAL prompt digest does not identify actual counterfactual input")
if main["prompt_sha512"] = shadow["prompt_sha512"] then raise syntax 93.900 array("social and no-social prompt variants unexpectedly have identical digest")

/* Scripted AI_GEMINI_EMULATED never receives a live-model prompt and must not
   pollute the prompt-boundary audit relation. */
store~actionTaken(t,noah,.Decision~new("CHECK",0,0,0),0)
r2 = store~execute("SELECT player_name FROM ai_prompt_boundary WHERE experiment_id=1")
if r2~rows~items \= 2 then raise syntax 93.900 array("scripted AI seat polluted live prompt boundary relation")
do row over r2~rows
  if row["player_name"] \= "GROK" then raise syntax 93.900 array("non-live player present in prompt boundary relation")
end

say "PASS persisted live-AI prompt boundary evidence and SHA-512 identity"
exit 0

assertAudit: procedure
  use arg row, socialExpected
  if row["boundary_status"] \= "PASS" then raise syntax 93.900 array("persisted prompt boundary did not pass")
  if row["field_count"] <= 0 then raise syntax 93.900 array("persisted prompt field count missing")
  if row["public_fields"] <= 0 then raise syntax 93.900 array("persisted public field count missing")
  if row["customer_fields"] \= 1 then raise syntax 93.900 array("prompt must contain exactly one CUSTOMER field: viewer hole cards")
  if row["self_private_fields"] \= 1 then raise syntax 93.900 array("self-private count mismatch")
  if row["history_fields"] < 1 then raise syntax 93.900 array("public-history provenance count missing")
  if row["rejected_fields"] \= 0 then raise syntax 93.900 array("persisted prompt had rejected fields")
  if row["prompt_length"] <= 0 then raise syntax 93.900 array("persisted prompt length missing")
  if row["prompt_sha512"]~length \= 128 then raise syntax 93.900 array("persisted prompt SHA-512 malformed")
  includeSocial = translate(row["include_social"]~string)
  if socialExpected then do
    if includeSocial \= "TRUE" then raise syntax 93.900 array("MAIN prompt include_social flag wrong")
  end
  else do
    if includeSocial \= "FALSE" then raise syntax 93.900 array("NO_SOCIAL include_social flag wrong")
  end
  return

cleanTree: procedure
  use arg root
  call SysFileTree root || "/*", "oldFiles.", "FOS"
  do i = 1 to oldFiles.0
    call SysFileDelete oldFiles.i
  end
  call SysFileTree root || "/*", "oldDirs.", "DOS"
  do i = oldDirs.0 to 1 by -1
    call SysRmDir oldDirs.i
  end
  call SysRmDir root
  return

::class PromptAuditFakeClient public
::attribute model get
::attribute mainPrompt get
::attribute shadowPrompt get
::method init
  expose model mainPrompt shadowPrompt calls
  model = "fake-prompt-audit"
  mainPrompt = ""
  shadowPrompt = ""
  calls = 0
::method decide
  use arg prompt
  return self~answer(prompt)
::method decideWithTemperature
  expose mainPrompt shadowPrompt calls
  use arg prompt, temperature
  calls += 1
  if prompt~pos("SOCIAL EVIDENCE DISABLED FOR COUNTERFACTUAL PROBE") > 0 then shadowPrompt = prompt
  else if mainPrompt = "" then mainPrompt = prompt
  return self~answer(prompt)
::method answer private
  use arg prompt
  d = .directory~new
  d["action"] = "CALL"
  d["amount"] = 0
  d["talk"] = "NONE"
  d["talk_target"] = "NONE"
  d["social_evidence"] = "NONE"
  return d

::class PromptAuditFallback public subclass PlayerStrategy
::method init
  forward class (super) array("prompt-audit-fallback",0.5,0,1)
::method decide
  use arg player, table, toCall, minRaise, canRaise=.true
  if toCall > 0 then return .Decision~new("FOLD",0,0,0)
  return .Decision~new("CHECK",0,0,0)

::requires "poker.cls"
::requires "experiment_store.cls"
