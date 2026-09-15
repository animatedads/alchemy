#!/usr/bin/env rexx
/* Psychic Poker v0.1 - ooRexx 5.3.0
 * No-limit Texas Hold'em experiment with ordinary and privileged psychic players.
 */

config = .GameConfig~new(5, 10, 1000, 20)
casino = .Casino~new("HardWorld Casino")
table = .PokerTable~new("Table-1", config)
casino~addTable(table)

/* Standard players: same decision machinery, differing risk and bluff posture. */
table~addPlayer(.Player~new("Alice", 1000, .PlayerStrategy~new("Tight", 0.20, 0.04, 1.25)))
table~addPlayer(.Player~new("Bob",   1000, .PlayerStrategy~new("Balanced", 0.45, 0.10, 1.00)))
table~addPlayer(.Player~new("Carol", 1000, .PlayerStrategy~new("Loose", 0.72, 0.18, 0.82)))

/* Psychic teammates can exchange hole-card information and inspect ordinary players. */
table~addPlayer(.PsychicPlayer~new("Psi-1", 1000, .PlayerStrategy~new("Psi-A", 0.48, 0.08, 0.95), "RED"))
table~addPlayer(.PsychicPlayer~new("Psi-2", 1000, .PlayerStrategy~new("Psi-B", 0.60, 0.14, 0.88), "RED"))

say "==" casino~name "=="
say "Blinds:" config~smallBlind "/" config~bigBlind " starting stack:" config~startingStack
say

do handNo = 1 to 2
    say "--- hand" handNo "---"
    table~playHand
    table~showStacks
    say
end

exit 0

::requires "poker.cls"
