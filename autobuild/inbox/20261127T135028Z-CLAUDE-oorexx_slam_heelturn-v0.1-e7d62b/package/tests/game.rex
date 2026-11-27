/* game.rex - the full-game gate: seven Heel Turn players, 1901-1905.
   Architecture: Tom Dyer. Code: Claude (Opus 5.5).
   Every call OK, no invalid orders, the same seed gives the same bytes,
   and the framework's own replay of the journal is byte-identical.
   Usage: rexx tests/game.rex HEELTURN_ROOT DIPLOMACY_ROOT WORK_DIR */
parse arg root droot work
if work == '' then do
  say 'usage: rexx tests/game.rex HEELTURN_ROOT DIPLOMACY_ROOT WORK_DIR'
  exit 2
end
ck = .HeelTurnCheck~new('game')
g = .HeelTurnGame~new
r1 = g~run(droot, root, root'/prompts/seats', 1905, 7, work'/game-a.log', work'/heelturn-a.log')
ck~that(r1['STATUS'] == 'FINISHED', 'game finished:' r1['STATUS'])
ck~that(r1['INVALID'] = 0, 'no invalid orders:' r1['INVALID'])
ck~that(r1['ORDER_CALLS'] > 0 & r1['PRESS_CALLS'] > 0, 'orders and press both called:' r1['ORDER_CALLS'] r1['PRESS_CALLS'])
st = g~callStatuses(work'/game-a.log.operator.log')
ck~that(st~items = 1 & st~hasIndex('OK'), 'every call OK:' heelTurnShow(st))
ck~that(st['OK'] = r1['ORDER_CALLS'] + r1['PRESS_CALLS'], 'call count matches')
log = heelTurnGameRead(work'/heelturn-a.log')
ck~that(pos('|FAULT|', log) = 0, 'no engine faults')
ck~that(pos('MEMORY_LINE_NOT_READ', log) = 0, 'every memory line read back')
ck~that(pos('ORDER_CHECK_FAIL', log) = 0, 'no order failed its own check')
ck~that(pos('EVENT|LIE ', log) > 0, 'some lie was caught at DOCUMENTARY')
ck~that(pos('EVENT|TOLD_LIE ', log) > 0, 'some prompt that allows lying told one')
ck~that(pos('SETTLED', log) > 0, 'some promise was settled as kept')
r2 = g~run(droot, root, root'/prompts/seats', 1905, 7, work'/game-b.log', work'/heelturn-b.log')
ck~that(.SHA512~new(heelTurnGameRead(work'/game-a.log'))~digest == .SHA512~new(heelTurnGameRead(work'/game-b.log'))~digest, 'same seed, same journal bytes')
ck~that(.SHA512~new(log)~digest == .SHA512~new(heelTurnGameRead(work'/heelturn-b.log'))~digest, 'same seed, same Heel Turn log bytes')
ck~that(g~replay(droot, work'/game-a.log', work'/game-a-replay.log'), 'framework replay byte-identical')
say 'game-a sha512' .SHA512~new(heelTurnGameRead(work'/game-a.log'))~digest~left(32)
exit \ck~finish
::routine heelTurnShow
  use strict arg d
  out = ''
  do k over d~allIndexes~sort
    out = out k'='d[k]
  end
  return out~strip
::requires 'HeelTurnGame.cls'
::requires 'HeelTurnCheck.cls'
::requires 'crypto.cls'
