strategy = .PlayerStrategy~new("alchemy-v07",0.4,0.1,1.0)
base = strategy~alchemyBaseState
construction = base["construction_provenance"]
if construction["entrypoint"] \= "INIT" then
  raise syntax 93.900 array("PokerAlchemyObject did not enter Alchemy through INIT:SUPER")
if construction["base_version"] \= "0.7" then
  raise syntax 93.900 array("wrong Alchemy base version " || construction["base_version"])
if \construction["completed"] then
  raise syntax 93.900 array("Alchemy construction provenance incomplete")
if strategy~alchemyInheritanceIntegrity["ok"] \= .true then
  raise syntax 93.900 array("Alchemy inheritance integrity failed")
say "PASS PokerAlchemyObject uses Alchemy v0.7 construction provenance"
exit 0
::requires "poker.cls"
