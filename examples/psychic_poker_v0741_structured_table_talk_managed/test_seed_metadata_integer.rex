parse arg root
if root = "" then root = "/tmp/hardworld-seed-integer-test"

cfg = .GameConfig~new(5,10,1000,4,999999999)
strategy = .PlayerStrategy~new("test",0.5,0,1)
players = .array~of(.Player~new("A",1000,strategy), .Player~new("B",1000,strategy))
store = .PokerExperimentStore~new(root,players)
store~beginExperiment("seed-integer-test")
store~recordExperimentContext(cfg~seed,"TEST","SEED_INTEGER_V1","A,B")
r = store~execute("SELECT casino_seed FROM experiment_context WHERE experiment_id=" || store~experimentId)
if r~status \= .Error~SUCCESS then raise syntax 93.900 array("seed metadata query failed")
if r~rows~items \= 1 then raise syntax 93.900 array("seed metadata row missing")
if r~rows[1]["casino_seed"] \= 999999999 then raise syntax 93.900 array("seed metadata value changed")
say "PASS INTEGER-safe casino seed metadata"
exit 0

::requires "poker.cls"
::requires "experiment_store.cls"
