numeric digits 20
call testMain
exit 0

testMain:
  GB=1024*1024*1024
  policy=.RegisteredJobEconomicPolicy~new(0.20,0.60,0,1000,2000,.true,.true,.true,24*GB,64*GB,1)

  offers=.array~new
  offers~append(.RegisteredJobCapacityOffer~new("idle-1","existing-node",0.00,32*GB,1,.false,10,.true,500))
  offers~append(.RegisteredJobCapacityOffer~new("spot-2","commissioning",0.31,64*GB,3,.true,40,.false,1500))

  evaluator=.RegisteredJobEconomicEvaluator~new
  result=evaluator~evaluate(policy,100,offers,.nil)
  call assert result~decision=.RegisteredJobEconomicDecision~RUN_EXISTING, "idle existing capacity wins"

  offers2=.array~new
  offers2~append(.RegisteredJobCapacityOffer~new("spot-2","commissioning",0.31,64*GB,3,.true,40,.false,1500))
  forecast=.RegisteredJobPriceForecast~new(0.18,300,0.82,"price-model",100)
  result=evaluator~evaluate(policy,100,offers2,forecast)
  call assert result~decision=.RegisteredJobEconomicDecision~ECONOMIC_HOLD, "forecast can hold registered job"

  result=evaluator~evaluate(policy,1000,offers2,forecast)
  call assert result~decision=.RegisteredJobEconomicDecision~DEADLINE_RUN, "latest start overrides hold"

  cheap=.array~new
  cheap~append(.RegisteredJobCapacityOffer~new("spot-cheap","commissioning",0.18,64*GB,3,.true,40,.false,1500))
  result=evaluator~evaluate(policy,100,cheap,.nil)
  call assert result~decision=.RegisteredJobEconomicDecision~RUN_COMMISSIONED, "target price runs"

  say "PASS registered.job.economic/0.1"
  return

assert:
  use arg ok, label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
  return

::requires "../src/RegisteredJobEconomicHold.cls"
