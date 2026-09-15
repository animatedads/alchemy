obs = .TestObserver~new
cfg = .GameConfig~new(5, 10, 100, 10)
t = .PokerTable~new("short-raise", cfg)
a = .Player~new("A", 100, .ScriptStrategy~new("A"))
b = .Player~new("B", 40, .ScriptStrategy~new("B"))
c = .Player~new("C", 100, .ScriptStrategy~new("C"))
t~addPlayer(a); t~addPlayer(b); t~addPlayer(c)
t~observer(obs)
t~playHand

/* A opens to 30. B can only make a short all-in raise to 40.
   C has not yet acted since the full raise and may respond normally.
   When action comes back to A, the short raise must not reopen raising;
   A's scripted second RAISE request is normalized to CALL. */
if \obs~hasAction("PREFLOP", "A", "RAISE") then call fail "A did not make opening full raise"
if \obs~hasAction("PREFLOP", "B", "RAISE") then call fail "B did not make short all-in raise"
if \obs~hasAction("PREFLOP", "A", "CALL") then call fail "short all-in incorrectly reopened A's raise right"

/* A separate heads-up all-in must run the board without post-flop actions. */
obs2 = .TestObserver~new
u = .PokerTable~new("allin-runout", .GameConfig~new(5,10,30,10))
x = .Player~new("X", 30, .JamStrategy~new)
y = .Player~new("Y", 30, .JamStrategy~new)
u~addPlayer(x); u~addPlayer(y); u~observer(obs2)
u~playHand
if obs2~postFlopActions > 0 then call fail "betting continued after all remaining players were all-in"

say "PASS betting reopen and all-in runout rules"
exit 0

fail: procedure
  use arg message
  say "FAIL" message
  exit 1

::class ScriptStrategy public subclass PlayerStrategy
::attribute role get
::attribute count
::method init
  expose role count
  use arg role
  forward class (super) array("script",0.5,0,1.0) continue
  count = 0
::method decide
  expose role count
  use arg player, table, toCall, minRaise, canRaise = .true
  count += 1
  if table~street = "PREFLOP" then do
    if role = "A" then do
      if count = 1 then return .Decision~new("RAISE",20,0.5,0)
      if toCall > 0 then return .Decision~new("RAISE",20,0.5,0)
    end
    if role = "B" then return .Decision~new("RAISE",20,0.5,0)
    if role = "C" then do
      if toCall > 0 then return .Decision~new("CALL",toCall,0.5,0)
    end
  end
  if toCall > 0 then return .Decision~new("CALL",toCall,0.5,0)
  return .Decision~new("CHECK",0,0.5,0)

::class JamStrategy public subclass PlayerStrategy
::method init
  forward class (super) array("jam",0.5,0,1.0)
::method decide
  use arg player, table, toCall, minRaise, canRaise = .true
  if canRaise then return .Decision~new("RAISE",1000,1.0,0)
  if toCall > 0 then return .Decision~new("CALL",toCall,1.0,0)
  return .Decision~new("CHECK",0,1.0,0)

::class TestObserver public
::method init
  expose actions postFlopActions
  actions = .array~new
  postFlopActions = 0
::method handStarted
  use arg table
::method capabilitiesCaptured
  use arg table
::method actionTaken
  expose actions postFlopActions
  use arg table, player, decision, toCall
  key = table~street || "|" || player~name || "|" || decision~action
  actions~append(key)
  if table~street \= "PREFLOP" then postFlopActions += 1
::method hasAction
  expose actions
  use arg street, name, action
  key = street || "|" || name || "|" || action
  do i = 1 to actions~items
    if actions[i] = key then return .true
  end
  return .false
::method postFlopActions
  expose postFlopActions
  return postFlopActions
::method uncalledReturned
  use arg table, player, amount
::method potSettled
  use arg table, potIndex, potType, amount, cap, winner, winnerShare, eligibleCount
::method handCompleted
  use arg table, finishType
::method psychicObservation
  use arg table, viewer, target, observationType, detail

::requires "poker.cls"
