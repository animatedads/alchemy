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
exit \ck~finish
::requires 'HeelTurnEngine.cls'
::requires 'HeelTurnCheck.cls'
::requires 'HeelTurnFixture.cls'
