MICRO = 1000000
keys=.WLUFastMacKeyRing~new; keys~addKey("demo","000102030405060708090a0b0c0d0e0f")
auth=.WLUAuthority~new(keys,.WLUMemoryLedger~new,.WLUTestTimeSource~new(1000000))
acct=.WLUAccount~new("flylo",100*MICRO); auth~addAccount(acct); auth~bindAccount("FLYLO_SHANNON","ABILITY:*",acct~accountId)
card=.WLURateCard~new("ai-common","2026-08"); card~addRule(.WLURateRule~new("AI_INPUT_TOKEN",1000)); card~addRule(.WLURateRule~new("AI_OUTPUT_TOKEN",1000)); card~seal; auth~addRateCard(card); auth~bindRateCard("FLYLO_SHANNON","ABILITY:*",card~rateCardId,card~version)
importer=.WLUExternalPlanImporter~new(auth)
gemma=importer~importPlan("FLYLO_SHANNON","GEMMA",makePlan("ABILITY:SHANNON.GEMMA",1000,500,.nil,3,30,"gemma"))~value
grok=importer~importPlan("FLYLO_SHANNON","GROK",makePlan("ABILITY:SHANNON.GROK",1200,1000,2500000,2,45,"grok"))~value
openai=importer~importPlan("FLYLO_SHANNON","OPENAI",makePlan("ABILITY:SHANNON.OPENAI",1500,1500,3500000,2,45,"openai"))~value
plan=.WLUJobPlan~new("flylo.shannon.provider-route","1"); plan~addStage(gemma~stage,.true); plan~addStage(grok~stage); plan~addStage(openai~stage); plan~addFallback("GEMMA","GROK"); plan~addFallback("GEMMA","OPENAI"); plan~seal
say "Gemma expected WLU:" .WLUUnits~format(gemma~expectedMicroWlu)
say "Grok expected WLU:" .WLUUnits~format(grok~expectedMicroWlu)
say "OpenAI expected WLU:" .WLUUnits~format(openai~expectedMicroWlu)
say "Worst credible route ceiling WLU:" .WLUUnits~format(plan~strategyCeilingMicroWlu)
say "Pinned rate card:" gemma~rateCardId || "@" || gemma~rateCardVersion
say "No provider was invoked by this planning/import step."
exit 0
makePlan: procedure
  use strict arg scope,inputTokens,outputTokens,ceiling,target,ttl,requestId
  return .DemoPlan~new(scope,.array~of(.DemoFact~new("AI_INPUT_TOKEN",inputTokens),.DemoFact~new("AI_OUTPUT_TOKEN",outputTokens)),ceiling,target,ttl,requestId)
::class DemoFact
::attribute factType get
::attribute quantity get
::attribute source get
::attribute dimensions get
::method init
  expose factType quantity source dimensions
  use strict arg factType,quantity
  source="demo-plan"; dimensions=.table~new
::class DemoPlan
::attribute scope get
::attribute ceilingMicroWlu get
::attribute targetSeconds get
::attribute ttlSeconds get
::attribute requestId get
::method init
  expose scope facts ceilingMicroWlu targetSeconds ttlSeconds requestId
  use strict arg scope,facts,ceilingMicroWlu,targetSeconds,ttlSeconds,requestId
::method plannedFacts
  expose facts
  return facts
::requires "WLUExternalPlan.cls"
