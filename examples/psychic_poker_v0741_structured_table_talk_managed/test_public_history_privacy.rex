source=charin("poker.cls",1,chars("poker.cls"))
call charin "poker.cls",1,0

if source~caselessPos('self~observerLog("  seat"')=0 then
  raise syntax 93.900 array("seat card display is not observer-only")
if source~caselessPos('self~log("  seat"')>0 then
  raise syntax 93.900 array("seat hole cards leak into public hand log")
if source~caselessPos('self~log("TALK"')=0 then
  raise syntax 93.900 array("table talk is not public hand history")
if source~caselessPos('observer~hasMethod("TABLETALK")')=0 then
  raise syntax 93.900 array("table-talk observer callback is not backward compatible")

/* Runtime boundary check: observer seat-card narration happens before betting,
   while constrained talk is public before the speaker's decision prompt. */
cfg=.GameConfig~new(5,10,100,10,12345)
t=.PokerTable~new("privacy-runtime",cfg)
t~verbose=.false
s1=.CaptureTalkStrategy~new
s2=.CaptureTalkStrategy~new
t~addPlayer(.Player~new("A",100,s1))
t~addPlayer(.Player~new("B",100,s2))
t~playHand
prompt=s1~lastPrompt
if prompt="" then prompt=s2~lastPrompt
if prompt="" then raise syntax 93.900 array("runtime prompt was not captured")
if prompt~caselessPos("PUBLIC HAND HISTORY")=0 then
  raise syntax 93.900 array("runtime prompt lacks public hand history")
if prompt~caselessPos("TALK ")=0 then
  raise syntax 93.900 array("public table talk did not reach runtime prompt")
if prompt~caselessPos("  seat")>0 then
  raise syntax 93.900 array("observer seat narration leaked into runtime prompt")

say "PASS public history separates observer cards from table talk"
exit 0

::class CaptureTalkStrategy public subclass PlayerStrategy
::attribute lastPrompt get
::method init
  expose lastPrompt
  forward class (super) array("capture-talk",0.5,0,1.0) continue
  lastPrompt=""
::method chooseTalk
  use arg player, table, toCall=0
  return table~talkLibrarian~entryAt(1)
::method decide
  expose lastPrompt
  use arg player, table, toCall, minRaise, canRaise=.true
  lastPrompt=table~agentPrompt(player,toCall,minRaise,canRaise)
  if toCall>0 then return .Decision~new("FOLD",0,0.5,0)
  return .Decision~new("CHECK",0,0.5,0)

::requires "poker.cls"
