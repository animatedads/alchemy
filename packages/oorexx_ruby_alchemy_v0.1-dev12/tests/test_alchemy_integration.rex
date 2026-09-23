/* Construction/evidence smoke against authoritative Alchemy classes. */
obj = .AlchemyRubyObject~new(.BridgeStub~new, 77)
if obj~foreignRuntime \== "RUBY" then exit 81
if obj~rubyHandle \== 77 then exit 82
state = obj~alchemyForeignState
if state["alchemy_initialized"] \== .true then exit 83
if state["unknown_composed"] \== .true then exit 84
if state["runtime"] \== "RUBY" then exit 85
composition = obj~foreignUnknownCompositionState
if composition["bridge_selector"] \== "RUBYUNKNOWN" then exit 86
base = obj~alchemyBaseState
if base["initialized"] \== .true then exit 87
if base["method_contract_count"] < 2 then exit 88
say "PASS dev12 authoritative Alchemy integration"
exit 0

::class BridgeStub
/* Deliberately unused: validates construction/composition, not dispatch. */
::method dispatch
  use strict arg handle, messageName, arguments
  raise syntax 98.900 array("BridgeStub dispatch is not used")
::requires "AlchemyRubyObject.cls"
