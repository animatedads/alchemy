/* Paladin owns public table-talk psychology without generic double-processing. */

/* Pressure must be able to tighten a marginal call using only public Player state. */
s1 = .PaladinStrategy~new
if \s1~handlesTableTalkPsychology then raise syntax 93.900 array("Paladin must own table-talk psychology")
t1 = .PaladinProbeTable~new(0.35, 100, "TURN", 41)
h1 = .Player~new("Paladin", 500, s1)
v1 = .Player~new("Needler", 500, .PlayerStrategy~new("plain",0.5,0,1.0))
t1~addPlayer(h1)
t1~addPlayer(v1)
pressureTalk = .PokerTableTalkEntry~new("HARD_WORD", "You sure about that?", "PRESSURE", 1.0, 0)
h1~receiveTableTalk(pressureTalk, v1)
d1 = h1~act(t1, 100, 20, .true)
if d1~action \= "FOLD" then raise syntax 93.900 array("Paladin did not tighten a marginal call under pressure")
if abs(h1~psychologicalPressure - 0.92) > 0.000001 then raise syntax 93.900 array("Paladin psychology did not decay exactly once")

/* Provocation must not buy a raise from Paladin.  A generic postprocessor
   would raise here because this probe returns 1 for a 1..100 chance roll. */
s2 = .PaladinStrategy~new
t2 = .PaladinProbeTable~new(0.50, 100, "FLOP", 42)
h2 = .Player~new("Paladin", 500, s2)
v2 = .Player~new("Challenger", 500, .PlayerStrategy~new("plain",0.5,0,1.0))
t2~addPlayer(h2)
t2~addPlayer(v2)
challengeTalk = .PokerTableTalkEntry~new("CALL_OUT", "I don't believe you.", "CHALLENGE", 0, 1.0)
h2~receiveTableTalk(challengeTalk, v2)
d2 = h2~act(t2, 0, 20, .true)
if d2~action \= "CHECK" then raise syntax 93.900 array("provocation improperly bought Paladin aggression")
if abs(h2~provocation - 0.90) > 0.000001 then raise syntax 93.900 array("Paladin provocation did not decay exactly once")

/* Raise amount is an increment above the call.  In shallow-SPR shove mode,
   cap the increment to effective chips behind rather than adding toCall twice. */
s3 = .PaladinStrategy~new
t3 = .PaladinProbeTable~new(0.80, 1000, "TURN", 43)
h3 = .Player~new("Paladin", 500, s3)
v3 = .Player~new("ShortVillain", 200, .PlayerStrategy~new("plain",0.5,0,1.0))
t3~addPlayer(h3)
t3~addPlayer(v3)
d3 = s3~decide(h3, t3, 100, 50, .true)
if d3~action \= "RAISE" then raise syntax 93.900 array("Paladin did not raise strong shallow-SPR holding")
if d3~amount \= 200 then raise syntax 93.900 array("Paladin shallow-SPR raise increment is wrong; expected 200 got" d3~amount)
if d3~amount + 100 > h3~stack then raise syntax 93.900 array("Paladin raise plus call exceeds available stack")

say "PASS Paladin public pressure discipline, provocation resistance, and raise-increment cap"
exit 0

::class PaladinProbeTable public
::attribute pot get
::attribute street get
::attribute handNumber get
::attribute players get
::method init
  expose fixedEquity pot street handNumber players
  use arg fixedEquity, pot, street, handNumber
  players = .array~new
::method addPlayer
  expose players
  use arg p
  players~append(p)
::method estimateEquity
  expose fixedEquity
  use arg player
  return fixedEquity
::method randomInt
  use arg lo, hi
  if hi = 100 then return 1
  if hi = 200 then return 100
  if hi = 10000 then return 10000
  return lo

::requires "poker.cls"
