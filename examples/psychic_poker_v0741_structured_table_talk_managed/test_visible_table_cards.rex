text = charin("poker.cls",1,chars("poker.cls"))
call charin "poker.cls",1,0

showPos = text~caselessPos("::method showStacks")
if showPos = 0 then raise syntax 93.900 array("showStacks method missing")
agentPos = text~caselessPos("::method agentPrompt", showPos)
if agentPos = 0 then raise syntax 93.900 array("agentPrompt marker missing")
showText = text~substr(showPos, agentPos - showPos)

if showText~caselessPos("p~holeString") = 0 then
  raise syntax 93.900 array("stack display lacks hole cards")

dealPos = text~caselessPos('self~log("dealer="')
if dealPos = 0 then raise syntax 93.900 array("dealer display missing")
betPos = text~caselessPos("self~bettingRound", dealPos)
if betPos = 0 then raise syntax 93.900 array("betting round marker missing")
dealText = text~substr(dealPos, betPos - dealPos)

if dealText~caselessPos("seat") = 0 | dealText~caselessPos("p~holeString") = 0 then
  raise syntax 93.900 array("initial table display lacks player hole cards")

/* The blind-prompt regression separately verifies that opponent cards are not
   leaked into GROK's API prompt. */
say "PASS visible console table cards"
exit 0
