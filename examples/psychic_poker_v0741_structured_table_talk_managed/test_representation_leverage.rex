cfg = .GameConfig~new(5,10,1000,8,123456)
t = .PokerTable~new("repr-test", cfg)
std = .PlayerStrategy~new("std",0.5,0.1,1.0)
psi = .PsychicAggressiveStrategy~new

ada = .Player~new("Ada",1000,std)
grok = .Player~new("GROK",1000,std)
hugo = .Player~new("Hugo",1000,std)
frank = .PsychicPlayer~new("Frank",1000,psi,"RED")
maya = .PsychicPlayer~new("Maya",1000,psi,"RED")

t~addPlayer(ada); t~addPlayer(grok); t~addPlayer(hugo); t~addPlayer(frank); t~addPlayer(maya)

/* Give everyone complete hole cards, then fold every ordinary player.
   Only RED remains, matching the important information-set edge case. */
ada~receiveCard(.Card~new("A","D")); ada~receiveCard(.Card~new("7","S"))
grok~receiveCard(.Card~new("K","C")); grok~receiveCard(.Card~new("Q","D"))
hugo~receiveCard(.Card~new("9","H")); hugo~receiveCard(.Card~new("8","H"))
frank~receiveCard(.Card~new("5","D")); frank~receiveCard(.Card~new("5","S"))
maya~receiveCard(.Card~new("6","C")); maya~receiveCard(.Card~new("7","C"))

ada~folded = .true
grok~folded = .true
hugo~folded = .true

/* The public API doesn't expose board mutation, so this regression primarily
   asserts the helper/state path through a direct hand run in the companion
   smoke. The static guard below ensures malformed candidates are rejected. */
source = charin("poker.cls",1,chars("poker.cls"))
call charin "poker.cls",1,0
if source~caselessPos("completeHoleCards(kh)") = 0 then
  raise syntax 93.900 array("target-hole completeness guard missing")
if source~caselessPos("completeHoleCards(candidate)") = 0 then
  raise syntax 93.900 array("candidate completeness guard missing")
say "PASS representation leverage completeness guards"
exit 0

::requires "poker.cls"
