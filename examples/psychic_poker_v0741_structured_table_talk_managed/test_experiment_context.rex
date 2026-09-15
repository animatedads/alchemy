parse arg root
if root = "" then root = "/tmp/hardworld-context-test"
cfg=.GameConfig~new(5,10,1000,4,777)
s=.PlayerStrategy~new("x",0.5,0,1)
ps=.array~of(.Player~new("A",1000,s),.Player~new("B",1000,s))
st=.PokerExperimentStore~new(root,ps)
st~beginExperiment("context-test")
st~recordExperimentContext(777,"grok-test","PROMPT_X","players=2;sb=5;bb=10;stack=1000","20260819T212800")
r=st~execute("SELECT casino_seed,ai_model,prompt_version,table_configuration FROM experiment_context WHERE experiment_id=" || st~experimentId)
if r~status \= .Error~SUCCESS then raise syntax 93.900 array("context query failed")
if r~rows~items \= 1 then raise syntax 93.900 array("context row missing")
row=r~rows[1]
if row["casino_seed"] \= 777 then raise syntax 93.900 array("seed mismatch")
if row["ai_model"] \= "grok-test" then raise syntax 93.900 array("model mismatch")
if row["prompt_version"] \= "PROMPT_X" then raise syntax 93.900 array("prompt mismatch")
say "PASS experiment context metadata"
exit 0
::requires "poker.cls"
::requires "experiment_store.cls"
