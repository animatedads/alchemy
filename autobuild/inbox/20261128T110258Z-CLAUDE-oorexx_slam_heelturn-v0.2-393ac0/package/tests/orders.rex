/* orders.rex - Heel Turn checks its own lines before they go out.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5). */
parse arg root
if root == '' then root = '.'
ck = .HeelTurnCheck~new('orders')
fx = .HeelTurnFixture~new(root'/tests/fixtures/spring1901_aus_press.txt')
view = .HeelTurnView~new(fx~system, fx~input(, , , 'MOVEMENT', 'SPRING_MOVEMENT', 'RUS'))
map = .HeelTurnMap~new(view~mapLines)
a = .HeelTurnAssessment~new(map, view)
cons = .directory~new
cons['NOMOVE'] = .directory~new
cons['NOATTACK'] = .directory~new
cons['SUPPORTS'] = .array~new
pl = .HeelTurnPlanner~new(map, view, a, .HeelTurnPolicy~new, .directory~new, .directory~new, cons)
good = .array~of('F STP/SC - BOT', 'A WAR - GAL', 'A MOS S A WAR - UKR', 'F SEV - BLA')
bad = .array~of('F STP - BOT', 'F STP/NC - BOT', 'A WAR - SEV', 'A MOS - STP/NC', 'F SEV S A WAR - UKR', 'A MOS S F SEV - RUM/EC', 'A KIE - HOL', 'A WAR S A BUD - TRI', 'F SEV C A MOS - ARM')
res = pl~check(good, 'MOVEMENT')
ck~that(res[2]~items = 0, 'good lines pass:' res[2]~makeString('L', '; '))
res = pl~check(bad, 'MOVEMENT')
ck~that(res[2]~items = bad~items, 'every bad line is caught:' res[2]~items 'of' bad~items)
ck~that(res[1]~hasItem('A WAR H') & res[1]~hasItem('A MOS H'), 'a failed line holds the unit instead')
res = pl~check(.array~of('A WAR S A BUD - GAL'), 'MOVEMENT')
ck~that(res[2]~items = 0, 'supporting a foreign unit is legal and passes')
do f over res[2]
  say '   ' f
end
-- every movement plan in a full spring for each power passes its own check
do p over .array~of('AUS', 'ENG', 'FRA', 'GER', 'ITA', 'RUS', 'TUR')
  v = .HeelTurnView~new(fx~system, fx~input(, , , 'MOVEMENT', 'SPRING_MOVEMENT', p))
  aa = .HeelTurnAssessment~new(map, v)
  pp = .HeelTurnPlanner~new(map, v, aa, .HeelTurnPolicy~new, .directory~new, .directory~new, cons)
  plan = pp~movement
  res = pp~check(plan['ORDERS'], 'MOVEMENT')
  ck~that(res[2]~items = 0 & res[1]~items = aa~myUnits~items, p 'plan passes its own check:' plan['ORDERS']~makeString('L', '; '))
end
-- v0.1r9: a move I said I would make is kept, unless another promise forbids it
va = .HeelTurnView~new(fx~system, fx~input(, , , 'MOVEMENT', 'SPRING_MOVEMENT', 'AUS'))
aa = .HeelTurnAssessment~new(map, va)
free = .HeelTurnPlanner~new(map, va, aa, .HeelTurnPolicy~new, .directory~new, .directory~new, cons)~movement
budFree = ''
do line over free['ORDERS']
  if line~word(2) == 'BUD' then budFree = line
end
told = .directory~new
told['NOMOVE'] = .directory~new
told['NOATTACK'] = .directory~new
told['SUPPORTS'] = .array~new
told['MOVES'] = .directory~new
told['MOVES']['BUD'] = 'RUM'
plan = .HeelTurnPlanner~new(map, va, aa, .HeelTurnPolicy~new, .directory~new, .directory~new, told)~movement
ck~that(budFree \== 'A BUD - RUM', 'left alone, Austria orders' budFree '(not RUM), so the next check means something')
ck~that(plan['ORDERS']~hasItem('A BUD - RUM'), 'told "My A BUD will move to RUM": ordered:' plan['ORDERS']~makeString('L', '; '))
-- the promised move waits for my own unit to step out: Turkey, F BLA in BLA,
-- told "My F ANK will move to BLA" (v0.1r9 game, Spring 1902: F ANK - ARM)
vt = .HeelTurnView~new(fx~system, fx~input(, , , 'MOVEMENT', 'SPRING_MOVEMENT', 'TUR'))
at = .HeelTurnAssessment~new(map, vt)
tt = .directory~new
tt['NOMOVE'] = .directory~new
tt['NOATTACK'] = .directory~new
tt['SUPPORTS'] = .array~new
tt['MOVES'] = .directory~new
tt['MOVES']['ANK'] = 'CON'
plan = .HeelTurnPlanner~new(map, vt, at, .HeelTurnPolicy~new, .directory~new, .directory~new, tt)~movement
ck~that(plan['ORDERS']~hasItem('F ANK - CON') & plan['ORDERS']~hasItem('A CON - BUL'), 'a told move into my own occupied province waits for it to clear:' plan['ORDERS']~makeString('L', '; '))
told['NOMOVE']['RUM'] = 1
plan = .HeelTurnPlanner~new(map, va, aa, .HeelTurnPolicy~new, .directory~new, .directory~new, told)~movement
ck~that(\plan['ORDERS']~hasItem('A BUD - RUM'), 'a NOMOVE RUM I also promised wins: no move into RUM')
exit \ck~finish
::requires 'HeelTurnEngine.cls'
::requires 'HeelTurnCheck.cls'
::requires 'HeelTurnFixture.cls'
