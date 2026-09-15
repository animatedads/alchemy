cfg=.GameConfig~new(5,10,1000,4,12345)
t=.PokerTable~new("talk-test",cfg)
s=.PlayerStrategy~new("test",0.5,0.1,1)
p=.Player~new("Target",1000,s)
e=t~talkLibrarian~classify("NERVOUS")
p~receiveTableTalk(e)
if p~psychologicalPressure <= 0 then raise syntax 93.900 array("pressure not applied")
if p~provocation <= 0 then raise syntax 93.900 array("provocation not applied")
say "PASS table-talk psychology state"
exit 0
::requires "poker.cls"
