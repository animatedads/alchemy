failures = 0

loaded = .KnownStateJsonStore~load("ibmi_known_states_live.json")
call assertTrue loaded~ok, "load live IBM i catalogue"
if \loaded~ok then do; say "FAIL test_main_menu_signoff" failures; exit 1; end
catalog = loaded~value
mainState = catalog~state("IBM_I_MAIN_MENU")
call assertTrue mainState \== .nil, "main menu state present"
mainSnap = mainState~exemplars[1]~snapshot
match = catalog~match(mainSnap)
call assertEq match~status, "MATCH", "main exemplar uniquely matches"
call assertEq match~matchedStateId, "IBM_I_MAIN_MENU", "main exemplar state id"

learned = .KnownState5250Factory~ibmIMainMenu(mainSnap, "MAIN_RELEARNED", "TEST_HUMAN")
call assertTrue learned~ok, "relearn main menu from live exemplar"

mapped = .KnownState5250Factory~findMainMenuCommandField(mainSnap)
call assertTrue mapped~ok, "map main command field"
call assertEq mapped~value~row, 20, "main field row"
call assertEq mapped~value~column, 7, "main field column"
call assertEq mapped~value~length, 153, "main field length"

runtime = .TestSignoffRuntime~new("SIGNOFF-STAGE")
runtime~loadMain
stage = .TN5250Signoff~stage90(runtime, catalog, "IBM_I_MAIN_MENU")
call assertTrue stage~ok, "stage option 90 on confirmed main menu"
call assertEq stage~value~commandFieldId, "F1527", "signoff field id"
call assertEq runtime~modifiedFieldsForWire~items, 1, "one modified field"
call assertEq runtime~modifiedFieldsForWire[1]~value, "90", "trusted wire value is 90"
call assertEq stage~value~snapshot~field("F1527")~value~strip, "90", "observer may see non-secret signoff value"

/* A sign-on screen or any unknown state must not receive option 90. */
wrong = .TestSignoffRuntime~new("SIGNOFF-WRONG")
wrong~loadSignonLike
before = wrong~modifiedFieldsForWire~items
refused = .TN5250Signoff~stage90(wrong, catalog, "IBM_I_MAIN_MENU")
call assertTrue \refused~ok, "wrong semantic state refused"
call assertEq wrong~modifiedFieldsForWire~items, before, "wrong state remains untouched"

if failures > 0 then do
  say "FAIL test_main_menu_signoff" failures
  exit 1
end
say "PASS test_main_menu_signoff"
exit 0

assertEq: procedure expose failures
  use arg actual, expected, label
  if actual == expected then return
  failures += 1
  say "ASSERT_EQ FAIL:" label "expected="expected "actual="actual
  return

assertTrue: procedure expose failures
  use arg condition, label
  if condition then return
  failures += 1
  say "ASSERT_TRUE FAIL:" label
  return

::class TestSignoffRuntime
::attribute model get
::attribute trace get

::method init
  expose model session agent client trace
  use arg sessionIdArg
  model = .PresentationSpace5250~new
  session = .TerminalSession~new(sessionIdArg, model)
  trace = session~trace
  agent = .Terminal5250AgentPort~new(session, model)
  client = .TN5250AutomationSession~new(sessionIdArg, "IBM-3179-2", "", session, .nil, agent, self)

::method loadMain
  expose model session
  model~writeText(1,3,"MAIN                           IBM i Main Menu")
  model~writeText(2,61,"System:   PUB400")
  model~writeText(3,3,"Select one of the following:")
  model~writeText(17,6,"90. Sign off")
  model~writeText(19,3,"Selection or command")
  model~writeText(20,3,"===>")
  ignore = model~defineField("F1527",20,7,153,"",.true,.false,.false)
  model~setCursor(20,7)
  model~setKeyboardState("UNLOCKED")
  model~setSessionState("OPERATOR_WAIT")
  model~hostCommit
  return session~commit

::method loadSignonLike
  expose model session
  model~writeText(1,10,"Welcome")
  ignore = model~defineField("USER",5,25,10,"",.true,.false,.false)
  ignore = model~defineField("PASS",6,25,128,"",.true,.false,.true)
  model~setCursor(5,25)
  model~setKeyboardState("UNLOCKED")
  model~setSessionState("OPERATOR_WAIT")
  model~hostCommit
  return session~commit

::method snapshot
  expose agent
  return agent~snapshot

::method automationPort
  expose client
  return client

::method modifiedFieldsForWire
  expose model
  return model~modifiedFieldsForWire

::requires "TN5250Signoff.cls"
