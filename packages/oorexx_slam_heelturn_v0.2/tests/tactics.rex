/* tactics.rex - directed positions: Heel Turn's orders, adjudicated by the
   framework referee against scripted orders for the other powers.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   Usage: rexx tests/tactics.rex HEELTURN_ROOT DIPLOMACY_ROOT WORK_DIR
   Each case is one tactic; v0.1r9 fails each (README, v0.2). */
parse arg root droot work
if work == '' then do
  say 'usage: rexx tests/tactics.rex HEELTURN_ROOT DIPLOMACY_ROOT WORK_DIR'
  exit 2
end
ck = .HeelTurnCheck~new('tactics')
b = .HeelTurnBench~new(droot, root, work'/tactics-journal.log')

-- 1. defend by strength: three Russian units on BUD need two hold supports
pos = b~position(.array~of('AUS A BUD', 'AUS A VIE', 'AUS A TRI', 'RUS A GAL', 'RUS A RUM', 'RUS A SER'))
r = play(b, 'AUS', 'Play well.', pos, b~ownership(.array~of('SER RUS', 'RUM RUS')), 'SPRING_MOVEMENT')
m = adjudicate(b, pos, 'AUS', r, 'RUS', .array~of('A GAL - BUD', 'A RUM S A GAL - BUD', 'A SER S A GAL - BUD'))
ck~that(\m~dislodged~hasIndex('BUD'), '1: BUD holds against three:' r~makeString('L', '; '))

-- 2. cut: the third unit cannot support BUD but can cut a supporter
pos = b~position(.array~of('AUS A BUD', 'AUS A VIE', 'AUS A BUL', 'RUS A GAL', 'RUS A RUM', 'RUS A SER'))
r = play(b, 'AUS', 'Play well.', pos, b~ownership(.array~of('SER RUS', 'RUM RUS', 'BUL AUS')), 'SPRING_MOVEMENT')
m = adjudicate(b, pos, 'AUS', r, 'RUS', .array~of('A GAL - BUD', 'A RUM S A GAL - BUD', 'A SER S A GAL - BUD'))
ck~that(\m~dislodged~hasIndex('BUD'), '2: BUD holds by cutting a support:' r~makeString('L', '; '))

-- 3. planned dislodge: Russian A RUM, supported by A SEV, beaten 3 to 2
pos = b~position(.array~of('AUS A BUD', 'AUS A SER', 'AUS A BUL', 'AUS F GRE', 'RUS A RUM', 'RUS A SEV'))
r = play(b, 'AUS', 'Play well.', pos, b~ownership(.array~of('RUM RUS', 'SER AUS', 'BUL AUS', 'GRE AUS')), 'FALL_MOVEMENT')
m = adjudicate(b, pos, 'AUS', r, 'RUS', .array~of('A RUM H', 'A SEV S A RUM'))
ck~that(m~dislodged~hasIndex('RUM'), '3: RUM dislodged 3 to 2:' r~makeString('L', '; '))

-- 4. deny: a designer who asks for bounces gets a spare into GAL against A WAR
pos = b~position(.array~of('AUS A BUD', 'AUS A VIE', 'AUS F TRI', 'RUS A WAR', 'RUS A MOS'))
r = play(b, 'AUS', 'Bounce enemy units out of the provinces next to your centres.', pos, b~ownership, 'SPRING_MOVEMENT')
m = adjudicate(b, pos, 'AUS', r, 'RUS', .array~of('A WAR - GAL', 'A MOS - UKR'))
ck~that(m~standoffs~hasIndex('GAL') | ownerAt(m, 'GAL') == 'AUS', '4: GAL bounced or taken, not Russian:' r~makeString('L', '; '))
r0 = play(b, 'AUS', 'Play well.', pos, b~ownership, 'SPRING_MOVEMENT')
ck~that(\hasMoveInto(r0, 'GAL') | hasMoveInto(r, 'GAL'), '4: and only because of the prompt, or it was already going')

-- 5. a fall retreat takes an unowned centre (ownership changes after fall
--    retreats) rather than going home to a centre it would block for a build
pos = b~position(.array~of('AUS A SER', 'AUS A VIE', 'AUS F TRI', 'RUS A RUM', 'RUS A BUL'))
own = b~ownership(.array~of('SER AUS', 'RUM RUS', 'BUL RUS'))
sub = .directory~new
sub['AUS'] = .array~of('A SER H', 'A VIE H', 'F TRI H')
sub['RUS'] = .array~of('A RUM - SER', 'A BUL S A RUM - SER')
m = b~move(pos, sub)
ck~that(m~dislodged~hasIndex('SER'), '5: (set-up) A SER is dislodged')
v = b~view('RETREAT', 'AUS', 'FALL_RETREATS', 1902, m~units, own, m)
reply = b~player('AUS', 'Play well.')~orders(v)
rsub = .directory~new
rsub['AUS'] = reply[2]
season = b~retreat(m, rsub)
ck~that(ownerAt(season, 'GRE') == 'AUS', '5: retreats into GRE to take it:' reply[2]~makeString('L', '; '))
-- 6. bounce by agreement: Russia proposes, Austria agrees, moves in
--    unsupported, and GAL stays empty
pos = b~position(.array~of('AUS A VIE', 'AUS A BUD', 'AUS F TRI', 'RUS A WAR', 'RUS A MOS'))
own = b~ownership
pl = b~player('AUS', 'Play well.')
mail = b~mail('1902S-R1-001', 'RUS', 'AUS', 'I propose we bounce in GAL: my A WAR moves to GAL and your A VIE moves to GAL this turn.')
pl~press(b~view('PRESS', 'AUS', 'SPRING_MOVEMENT', 1902, pos, own, .nil, .array~of(mail)))
said = b~lastReply
ck~that(said~pos('Agreed: we bounce in GAL, my A VIE moves to GAL this turn.') > 0, '6: agrees to the bounce')
r = pl~orders(b~view('MOVEMENT', 'AUS', 'SPRING_MOVEMENT', 1902, pos, own))[2]
ck~that(r~hasItem('A VIE - GAL') & \supportsInto(r, 'GAL'), '6: moves in, unsupported:' r~makeString('L', '; '))
m = adjudicate(b, pos, 'AUS', r, 'RUS', .array~of('A WAR - GAL', 'A MOS H'))
ck~that(m~standoffs~hasIndex('GAL'), '6: GAL bounced, empty')

-- 7. the bounce broken: Russia supports its move into GAL; Austria's next
--    call catches it (DOCUMENTARY: the published orders)
pos = b~position(.array~of('AUS A VIE', 'AUS A BUD', 'AUS F TRI', 'RUS A WAR', 'RUS A UKR'))
pl = b~player('AUS', 'Play well.')
mail = b~mail('1902S-R1-001', 'RUS', 'AUS', 'I propose we bounce in GAL: my A WAR moves to GAL and your A VIE moves to GAL this turn.')
pl~press(b~view('PRESS', 'AUS', 'SPRING_MOVEMENT', 1902, pos, own, .nil, .array~of(mail)))
r = pl~orders(b~view('MOVEMENT', 'AUS', 'SPRING_MOVEMENT', 1902, pos, own))[2]
m = adjudicate(b, pos, 'AUS', r, 'RUS', .array~of('A WAR - GAL', 'A UKR S A WAR - GAL'))
pl~press(b~view('PRESS', 'AUS', 'FALL_MOVEMENT', 1902, m~units, own, m, .array~new, 'SPRING_MOVEMENT'))
ck~that(b~lastReply~pos('BROKE_BOUNCE') > 0, '7: the supported "bounce" is recorded as a lie')

-- 8. dislodge by agreement, Austria the victim: Russia (its ally) dislodges
--    A GAL with support; A GAL holds, unsupported, and retreats to BOH as
--    agreed; the dislodge is not recorded as an attack
ally = 'Ally with your neighbours.'
-- a board where Russia is Austria's one natural ally: no German or Italian
-- ground near, and Russia not ahead on centres
own = b~ownership(.array~of('SER AUS', 'BER N', 'KIE N', 'MUN N', 'VEN N', 'ROM N', 'NAP N'))
pos = b~position(.array~of('AUS A GAL', 'AUS A VIE', 'AUS F TRI', 'RUS A WAR', 'RUS A UKR'))
pl = b~player('AUS', ally)
mail = b~mail('1902S-R1-001', 'RUS', 'AUS', 'I propose a dislodge by agreement: A WAR - GAL, A UKR S A WAR - GAL, and your A GAL holds, then A GAL R BOH.')
pl~press(b~view('PRESS', 'AUS', 'SPRING_MOVEMENT', 1902, pos, own, .nil, .array~of(mail)))
ck~that(b~lastReply~pos('Agreed, a dislodge by agreement: A WAR - GAL') > 0, '8: agrees')
r = pl~orders(b~view('MOVEMENT', 'AUS', 'SPRING_MOVEMENT', 1902, pos, own))[2]
ck~that(r~hasItem('A GAL H') & \supportsHold(r, 'GAL'), '8: A GAL holds, unsupported:' r~makeString('L', '; '))
m = adjudicate(b, pos, 'AUS', r, 'RUS', .array~of('A WAR - GAL', 'A UKR S A WAR - GAL'))
ck~that(m~dislodged~hasIndex('GAL'), '8: (referee) GAL dislodged')
rr = pl~orders(b~view('RETREAT', 'AUS', 'SPRING_RETREATS', 1902, m~units, own, m))[2]
rsub = .directory~new
rsub['AUS'] = rr
season = b~retreat(m, rsub)
ck~that(ownerAt(season, 'BOH') == 'AUS', '8: retreats to BOH as agreed:' rr~makeString('L', '; '))
ck~that(b~lastReply~pos('ATTACKED_BY') = 0 & b~lastReply~pos('LIE|RUS') = 0, '8: not an attack, not a lie')

-- 9. the trap refused: Russia also has a unit that could take BOH
pos = b~position(.array~of('AUS A GAL', 'AUS A VIE', 'AUS F TRI', 'RUS A WAR', 'RUS A UKR', 'RUS A SIL'))
pl = b~player('AUS', ally)
pl~press(b~view('PRESS', 'AUS', 'SPRING_MOVEMENT', 1902, pos, own, .nil, .array~of(mail)))
ck~that(b~lastReply~pos('I cannot agree to a dislodge in GAL this turn.') > 0, '9: refuses when the retreat could be taken')

-- 10. Austria the attacker, asked by its ally: honest, it dislodges and keeps
--     the retreat clear; a liar who stabs springs the trap
pos = b~position(.array~of('AUS A VIE', 'AUS A BUD', 'AUS A RUM', 'RUS A GAL'))
mail = b~mail('1902S-R1-001', 'RUS', 'AUS', 'I propose a dislodge by agreement: A VIE - GAL, A BUD S A VIE - GAL, and my A GAL holds, then A GAL R UKR.')
pl = b~player('AUS', ally)
pl~press(b~view('PRESS', 'AUS', 'SPRING_MOVEMENT', 1902, pos, own, .nil, .array~of(mail)))
ck~that(b~lastReply~pos('Agreed, a dislodge by agreement: A VIE - GAL, A BUD S A VIE - GAL') > 0, '10: honest: agrees')
r = pl~orders(b~view('MOVEMENT', 'AUS', 'SPRING_MOVEMENT', 1902, pos, own))[2]
ck~that(r~hasItem('A VIE - GAL') & r~hasItem('A BUD S A VIE - GAL') & \hasMoveInto(r, 'UKR'), '10: honest: dislodges, UKR left clear:' r~makeString('L', '; '))
pl = b~player('AUS', 'Ally with your neighbours. Lie freely. Stab your allies.')
pl~press(b~view('PRESS', 'AUS', 'SPRING_MOVEMENT', 1902, pos, own, .nil, .array~of(mail)))
r = pl~orders(b~view('MOVEMENT', 'AUS', 'SPRING_MOVEMENT', 1902, pos, own))[2]
m = adjudicate(b, pos, 'AUS', r, 'RUS', .array~of('A GAL H'))
opts = b~judge~retreatOptions(m)
ck~that(m~dislodged~hasIndex('GAL') & hasMoveInto(r, 'UKR'), '10: liar: dislodges and takes UKR:' r~makeString('L', '; '))
ck~that(\retreatOpen(opts, 'GAL', 'UKR'), '10: (referee) the agreed retreat is gone')

-- 11. Austria proposes, as the attacker: its ally's unit in GAL stands on
--     its way to a centre it is after (WAR, Turkish on this board), on no
--     supply centre, with a retreat no one else can reach
own11 = b~ownership(.array~of('SER AUS', 'BER N', 'KIE N', 'MUN N', 'VEN N', 'ROM N', 'NAP N', 'WAR TUR'))
pos = b~position(.array~of('AUS A VIE', 'AUS A BUD', 'RUS A GAL'))
pl = b~player('AUS', ally)
pl~press(b~view('PRESS', 'AUS', 'SPRING_MOVEMENT', 1902, pos, own11))
said = b~lastReply
ck~that(said~pos('I propose a dislodge by agreement: A') > 0 & said~pos('- GAL, A') > 0, '11: proposes the dislodge of A GAL')
q = retreatOf(said)
-- the attacker goes into GAL; no other unit of Austria's can reach the retreat
atk = said~substr(said~pos('agreement: ') + 11, 5)
others = .array~new
do u over .array~of('A VIE', 'A BUD')
  if u \== atk then others~append(u)
end
ok = q \== ''
do u over others
  if b~board~adjacent(u~word(2), q, 'A') then ok = .false
end
ck~that(ok, '11: to a retreat none of its other units can reach:' atk 'attacks,' q)
ck~that(said~pos('DMZ in' q) = 0 & said~pos('bounce in' q) = 0, '11: and no DMZ or bounce offered on the agreed retreat')
exit \ck~finish

::routine retreatOf
  use strict arg text
  at = text~pos('A GAL R ')
  if at = 0 then return ''
  return text~substr(at + 8, 3)
::routine retreatOpen
  use strict arg opts, from, to
  if \opts~hasIndex(from) then return .false
  do d over opts[from]
    if d~left(3) == to then return .true
  end
  return .false
::routine supportsInto
  use strict arg lines, prov
  do l over lines
    if l~word(3) == 'S' then if l~words >= 7 then if l~word(7)~left(3) == prov then return .true
  end
  return .false
::routine supportsHold
  use strict arg lines, prov
  do l over lines
    if l~word(3) == 'S' then if l~words = 5 then if l~word(5) == prov then return .true
  end
  return .false
::routine play
  -- Heel Turn's orders for one power, through the framework player
  use strict arg b, power, prompt, pos, own, phase
  year = 1902
  v = b~view('MOVEMENT', power, phase, year, pos, own)
  reply = b~player(power, prompt)~orders(v)
  if reply[1] \== 'OK' then return .array~new
  return reply[2]
::routine adjudicate
  use strict arg b, pos, me, mine, other, theirs
  sub = .directory~new
  sub[me] = mine
  sub[other] = theirs
  return b~move(pos, sub)
::routine ownerAt
  use strict arg m, prov
  if \m~units~hasIndex(prov) then return ''
  return m~units[prov]~owner
::routine hasMoveInto
  use strict arg lines, prov
  do l over lines
    if l~word(3) == '-' then if l~word(4)~left(3) == prov then return .true
  end
  return .false
::requires 'HeelTurnBench.cls'
::requires 'HeelTurnCheck.cls'
