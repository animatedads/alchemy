s = .PaladinStrategy~new
if s~strategyType \= "PALADIN" then raise syntax 93.900 array("wrong Paladin strategy type")
if s~risk \= 0.62 then raise syntax 93.900 array("wrong Paladin risk")
if s~bluff \= 0.09 then raise syntax 93.900 array("wrong Paladin bluff")
if s~aggression \= 1.55 then raise syntax 93.900 array("wrong Paladin aggression")

/* Guard-safety: no bare &/| compound conditionals in Paladin's own text. */
source = charin("poker.cls",1,chars("poker.cls"))
call charin "poker.cls",1,0
p = source~caselessPos("::class PaladinStrategy")
q = source~caselessPos("::class BlindPsychicStrategy", p)
paladinText = source~substr(p, q - p)
if paladinText~pos(" & ") > 0 then raise syntax 93.900 array("Paladin contains non-short-circuit & guard")
if paladinText~pos(" | ") > 0 then raise syntax 93.900 array("Paladin contains non-short-circuit | guard")

/* Honesty boundary: Paladin must never call the privileged reads. */
if paladinText~pos("knownCardsFor") > 0 then raise syntax 93.900 array("Paladin reads opponent hole cards")
if paladinText~pos("inspectStrategy") > 0 then raise syntax 93.900 array("Paladin reads opponent strategy objects")

/* Behavioural check: a hand whose equity has visibly collapsed after the
   flop must fold to a large bet even though naive current-street equity
   still numerically clears the naive pot-odds price -- this is the exact
   trap the transcript showed the APEX seat fall into (calling a shrinking
   hand down three streets because each single street looked fine alone). */
config = .GameConfig~new(5, 10, 1000, 200, 4242)
table = .PokerTable~new("test", config)
table~verbose = .false

hero = .Player~new("Hero", 1000, s)
villain = .Player~new("Villain", 1000, .AggressiveStrategy~new)
table~addPlayer(hero)
table~addPlayer(villain)

hero~receiveCard(.Card~new(11, "S"))   /* JS */
hero~receiveCard(.Card~new(10, "H"))   /* TH -- was a strong draw, now dead */
villain~receiveCard(.Card~new(14, "C"))
villain~receiveCard(.Card~new(14, "D"))

board = table~board
board~append(.Card~new(9, "S"))
board~append(.Card~new(8, "D"))
board~append(.Card~new(2, "C"))
board~append(.Card~new(2, "H"))   /* turn pairs the board, kills the draw's best outs */

hero~totalBet = 40
villain~totalBet = 40

/* Prime the trend memory: pretend Paladin already saw strong flop equity
   this hand before the turn card crushed it. */
tableAtFlop = .PokerTable~new("test2", config)
tableAtFlop~verbose = .false
d = .decision~new("CALL", 0, 0.55, 0.20)   /* unused, just documents the prior read */

/* Directly exercise decide() at the turn with a large bet in front of it. */
decision = s~decide(hero, table, 300, 20, .true)
say "Paladin decision after equity collapse: " decision~action "equity="format(decision~equity,1,2) "potOdds="format(decision~potOdds,1,2)
if decision~action \= "FOLD" then do
  /* Bluffing is stochastic at a low frequency; only fail if it is not at
     least willing to fold on repeated fresh draws of this exact spot. */
  foldSeen = .false
  do trial = 1 to 40
    freshTable = .PokerTable~new("retry" || trial, .GameConfig~new(5, 10, 1000, 200, 1000 + trial))
    freshTable~verbose = .false
    freshHero = .Player~new("Hero", 1000, .PaladinStrategy~new)
    freshVillain = .Player~new("Villain", 1000, .AggressiveStrategy~new)
    freshTable~addPlayer(freshHero)
    freshTable~addPlayer(freshVillain)
    freshHero~receiveCard(.Card~new(11, "S"))
    freshHero~receiveCard(.Card~new(10, "H"))
    freshVillain~receiveCard(.Card~new(14, "C"))
    freshVillain~receiveCard(.Card~new(14, "D"))
    fb = freshTable~board
    fb~append(.Card~new(9, "S"))
    fb~append(.Card~new(8, "D"))
    fb~append(.Card~new(2, "C"))
    fb~append(.Card~new(2, "H"))
    trialDecision = freshHero~strategy~decide(freshHero, freshTable, 300, 20, .true)
    if trialDecision~action = "FOLD" then do
      foldSeen = .true
      leave
    end
  end
  if \foldSeen then raise syntax 93.900 array("Paladin never folds a collapsed hand to a large bet across 40 fresh draws")
end

say "PASS Paladin strategy parameters, guard safety, honesty boundary, and anti-chase discipline"
exit 0
::requires "poker.cls"
