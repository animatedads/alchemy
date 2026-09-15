normal = .Player~new("Normal", 1000, .PlayerStrategy~new("N", 0.5, 0.1, 1.0))
psiA = .PsychicPlayer~new("PsiA", 1000, .PlayerStrategy~new("PA", 0.5, 0.1, 1.0), "RED")
psiB = .PsychicPlayer~new("PsiB", 1000, .PlayerStrategy~new("PB", 0.5, 0.1, 1.0), "RED")
psiEnemy = .PsychicPlayer~new("PsiX", 1000, .PlayerStrategy~new("PX", 0.5, 0.1, 1.0), "BLUE")

normal~receiveCard(.Card~new(14,"S")); normal~receiveCard(.Card~new(14,"H"))
psiB~receiveCard(.Card~new(13,"S")); psiB~receiveCard(.Card~new(13,"H"))
psiEnemy~receiveCard(.Card~new(12,"S")); psiEnemy~receiveCard(.Card~new(12,"H"))
psiA~receiveTeamIntel(psiB)

if psiA~knownCardsFor(normal) == .nil then do; say "FAIL cannot read normal cards"; exit 1; end
if psiA~knownCardsFor(psiB) == .nil then do; say "FAIL cannot read teammate intel"; exit 1; end
if psiA~knownCardsFor(psiEnemy) <> .nil then do; say "FAIL can read hostile psychic cards"; exit 1; end
if psiA~inspectStrategy(normal) == .nil then do; say "FAIL cannot inspect normal strategy"; exit 1; end
if psiA~inspectStrategy(psiEnemy) <> .nil then do; say "FAIL can inspect psychic strategy"; exit 1; end
if normal~knownCardsFor(psiA) <> .nil then do; say "FAIL normal player has psychic knowledge"; exit 1; end
say "PASS psychic information boundaries"
exit 0

::requires "poker.cls"
