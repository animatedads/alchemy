parse arg root
if root = "" then root = "/tmp/hardworld-prompt-manifest-storage-test"
call cleanTree root

cfg = .GameConfig~new(5,10,1000,4,739039)
client = .ManifestFakeClient~new
grok = .Player~new("GROK",1000,.GrokPokerStrategy~new(client,.ManifestFallback~new))
hugo = .Player~new("Hugo",1000,.PlayerStrategy~new("ordinary",0.5,0,1))
t = .PokerTable~new("manifest-store",cfg)
t~verbose = .false
t~addPlayer(grok); t~addPlayer(hugo)
store = .PokerExperimentStore~new(root,.array~of(grok,hugo))
store~beginExperiment("prompt-manifest")
t~observer(store)

oldShadow = value("POKER_SOCIAL_SHADOW",, "ENVIRONMENT")
call value "POKER_SOCIAL_SHADOW", "2", "ENVIRONMENT"
d = grok~act(t,10,10,.true)
call value "POKER_SOCIAL_SHADOW", oldShadow, "ENVIRONMENT"
store~actionTaken(t,grok,d,10)

r = store~execute("SELECT prompt_kind,manifest_version,field_manifest,core_manifest,social_manifest,core_field_count,social_field_count,core_contract_status FROM ai_prompt_manifest WHERE experiment_id=1 ORDER BY prompt_kind")
if r~status \= .Error~SUCCESS then raise syntax 93.900 array("ai_prompt_manifest query failed")
if r~rows~items \= 2 then raise syntax 93.900 array("expected MAIN and NO_SOCIAL prompt manifest rows")
main=.nil; shadow=.nil
do row over r~rows
  if row["prompt_kind"] = "MAIN" then main=row
  else if row["prompt_kind"] = "NO_SOCIAL" then shadow=row
end
if main == .nil | shadow == .nil then raise syntax 93.900 array("prompt manifest variants missing")
if main["manifest_version"] \= "PSYCHIC_POKER_PROMPT_FIELD_MANIFEST_V1" then raise syntax 93.900 array("persisted manifest version wrong")
if main["core_contract_status"] \= "REFERENCE" then raise syntax 93.900 array("MAIN manifest should be structural reference")
if shadow["core_contract_status"] \= "MATCH" then raise syntax 93.900 array("NO_SOCIAL manifest did not verify against MAIN")
if main["core_manifest"] \= shadow["core_manifest"] then raise syntax 93.900 array("persisted counterfactual changed non-social provenance")
if main["field_manifest"] = shadow["field_manifest"] then raise syntax 93.900 array("persisted full manifests should differ in social provenance")
if main["field_manifest"]~caselessPos("your cards") > 0 then raise syntax 93.900 array("prompt values leaked into persisted manifest")
if main["field_manifest"]~caselessPos("AS KS") > 0 then raise syntax 93.900 array("hole cards leaked into persisted manifest")
if main["core_field_count"] <= 0 then raise syntax 93.900 array("core field count missing")

say "PASS persisted non-content prompt manifest and social-only counterfactual contract"
exit 0

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

::class ManifestFakeClient public
::attribute model get
::method init
  expose model
  model="fake-manifest"
::method decide
  use arg prompt
  return self~answer
::method decideWithTemperature
  use arg prompt, temperature
  return self~answer
::method answer private
  d=.directory~new
  d["action"]="CALL"; d["amount"]=0; d["talk"]="NONE"; d["talk_target"]="NONE"; d["social_evidence"]="NONE"
  return d

::class ManifestFallback public subclass PlayerStrategy
::method init
  forward class (super) array("manifest-fallback",0.5,0,1)
::method decide
  use arg player, table, toCall, minRaise, canRaise=.true
  if toCall > 0 then return .Decision~new("CALL",toCall,0,0)
  return .Decision~new("CHECK",0,0,0)

::requires "ai_grok.cls"
::requires "experiment_store.cls"
