/* rx_mod_inverse before and after the condition check (ChatGPT's third letter to SLAM).
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 * Args: scratch dir | crypto.cls | phase (BEFORE or AFTER) | store path (kept between phases) | label
 *
 * BEFORE: run valid inputs (store each output), invalid inputs (store what happens), time 600 calls.
 * AFTER:  the same; every valid output must equal its BEFORE output exactly, every invalid input must
 *         raise an error that says the condition is false, and the timing is stored next to BEFORE's.
 * CHECK:  no BEFORE needed (the fix is in the repository): valid input gives a * y = 1 mod m, invalid
 *         input raises an error that says the condition is false.
 * The routine is lifted on its own (nothing else in crypto.cls runs).
 */
signal on syntax name onSyntax
parse arg work '|' cryptoFile '|' phase '|' db '|' label
phase = phase~upper
checks = 0
numeric digits 2000
c = .SlamComposer~new
inv = c~lift(cryptoFile, 'rx_mod_inverse', 'RXINV')
store = .SlamStore~new(db)
node = store~codeNode('rx_mod_inverse' label)
p25519 = 2**255 - 19
p448 = 2**448 - 2**224 - 1
valid = .array~of(.array~of(3, 7), .array~of(-3, 7), .array~of(121666, p25519), .array~of(5, p25519), .array~of(65537, 3120), .array~of(123456789, 1000000007), .array~of(2**200 + 1, p448), .array~of(1, 2))
invalid = .array~of(.array~of(0, 7), .array~of(7, 7), .array~of(14, 7), .array~of(4, 6), .array~of(1, 1), .array~of(5, 0), .array~of(5, -7), .array~of(0, p25519))

say '==' phase label
store~begin
do v over valid
  r = c~callOne(inv~routine, v)
  out = r['STATUS']
  if r['STATUS'] == 'OK' then out = r['VALUE']
  ok = .false
  if r['STATUS'] == 'OK' then ok = (v[1] * r['VALUE'] - 1) // v[2] = 0
  store~lesson(node, node, ok, phase, 'valid' label, 'a=' || v[1] 'm=' || v[2] 'out=' || out)
  if phase == 'CHECK' then call check ok, 'a * y = 1 mod m for a=' || v[1]~left(12) 'm=' || v[2]~left(12)
  if phase == 'AFTER' then do
    before = store~scalar("SELECT data AS d FROM lesson WHERE predicted = 'BEFORE' AND reason = ? AND data LIKE ? ORDER BY id LIMIT 1", store~binds('valid' label, 'a=' || v[1] 'm=' || v[2] 'out=%'))
    call check before == 'a=' || v[1] 'm=' || v[2] 'out=' || out, 'unchanged output for a=' || v[1]~left(12) 'm=' || v[2]~left(12) || ' (' || out~string~left(20) || ')'
  end
  if phase == 'BEFORE' then call check ok, 'a * y = 1 mod m for a=' || v[1]~left(12) 'm=' || v[2]~left(12)
end
do v over invalid
  r = c~callOne(inv~routine, v)
  if r['STATUS'] == 'OK' then what = 'returned' r['VALUE'] '(a number that is false)'
  else what = 'error' r['ERROR']
  store~lesson(node, node, r['STATUS'] \== 'OK', phase, 'invalid' label, 'a=' || v[1]~left(20) 'm=' || v[2]~left(20) what~left(160))
  if phase \== 'BEFORE' then call check r['STATUS'] == 'FAILED' & r['ERROR']~pos('condition false') > 0, 'a=' || v[1]~left(6) 'm=' || v[2]~left(6) ':' r['ERROR']~substr(r['ERROR']~pos(':') + 2)~left(90)
  else say '      a=' || v[1]~left(6) 'm=' || v[2]~left(6) ':' what~left(110)
end
/* timing: 600 calls on valid input (curve-size and RSA-size) */
call time 'R'
do i = 1 to 200
  ignored = inv~routine~call(121666 + i, p25519)
  ignored = inv~routine~call(65537, 3120 + 2 * i * 3)
  ignored = inv~routine~call(2**200 + i * 2 + 1, p448)
end
secs = time('E')
store~lesson(node, node, .true, phase, 'timing' label, '600 calls' format(secs, , 4) 's')
store~commit
say '      timing:' phase '600 calls' format(secs, , 4) 's'
if phase == 'AFTER' then do
  b = store~scalar("SELECT data AS d FROM lesson WHERE predicted = 'BEFORE' AND reason = ? ORDER BY id DESC LIMIT 1", store~binds('timing' label))
  say '      timing before:' b
end
store~close
say 'MODINV' phase 'TEST: PASS (' || checks || ' checks)'
exit 0

check: procedure expose checks
  use arg ok, label
  checks += 1
  if ok then say 'PASS ' label
  else do
    say 'FAIL ' label
    exit 1
  end
  return

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D')
  exit 1

::requires 'SlamCompose.cls'
