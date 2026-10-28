/* FDSqrt before and after the change (ChatGPT's fourth letter to SLAM: "the bug is in FDSqrt — the code
 * can stop too soon").  SLAM found it: in test_choose the chosen path and its second way disagreed on large
 * numbers, and the tested root anchor said FDSqrt was the false node.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.  Door code (FDSqrt): ChatGPT.
 * Args: scratch dir | FDDoorMicroMotion.cls | Vision.cls | phase (BEFORE, AFTER or CHECK) | store path | label
 *
 * Every value goes through three ways: FDSqrt, rx_vision_sqrt (a second routine, another package), and
 * SlamMaths~sqrtOf (the root anchor, 30 digits, TESTED by grounding).  Each result is kept, true or false.
 * A result is true when FDSqrt is within 1e-8 (relative) of the anchor AND of rx_vision_sqrt.
 *
 * BEFORE: small values must be true; large values are run and kept as they are (some are false).
 * AFTER:  small values must give the same output as BEFORE, character for character; large values must be
 *         true; timing is stored next to BEFORE's.
 * CHECK:  no BEFORE needed (the change is in the repository): every value must be true.
 * Both routines are lifted on their own at the default NUMERIC DIGITS 9, as they run in their own files.
 */
signal on syntax name onSyntax
parse arg work '|' doorFile '|' visionFile '|' phase '|' db '|' label
phase = phase~upper
checks = 0
c = .SlamComposer~new
fd = c~lift(doorFile, 'FDSqrt', 'FDSQRT')
vs = c~lift(visionFile, 'rx_vision_sqrt', 'VSQRT')
store = .SlamStore~new(db)
node = store~codeNode('FDSqrt' label)
small = .array~of(0.0004, 0.25, 0.5, 1, 2, 3, 9, 10, 99.5, 144, 1000, 12345.678, 65025, 250000, 999999, 1000000)
large = .array~of(1000001, 10000000, 12345678.9, 99999999, 100000000, 330000000, 1000000000, 2000000000, 10000000000, 777000000000, 1000000000000, 1E15, 4E18)

say '==' phase label
store~begin
falseLarge = 0
do pass = 1 to 2
  if pass = 1 then do; set = small; kind = 'small'; end
  else do; set = large; kind = 'large'; end
  do x over set
    r = c~callOne(fd~routine, .array~of(x))
    v = c~callOne(vs~routine, .array~of(x))
    a = .SlamMaths~sqrtOf(x)
    out = r['STATUS']; if r['STATUS'] == 'OK' then out = r['VALUE']
    second = v['STATUS']; if v['STATUS'] == 'OK' then second = v['VALUE']
    ok = r['STATUS'] == 'OK' & v['STATUS'] == 'OK'
    if ok then ok = close(out, a) & close(out, second)
    data = 'x=' || x 'out=' || out 'second=' || second 'anchor=' || a
    store~lesson(node, node, ok, phase, kind label, data)
    line = '      ' kind x~right(14) '->' out~string~left(18) 'second' second~string~left(18) 'anchor' a~string~left(22) ok
    if phase == 'BEFORE' & kind == 'large' then do
      say line
      if \ok then falseLarge += 1
    end
    else if phase == 'BEFORE' then call check ok, kind 'x=' || x~left(12) '->' out
    if phase == 'CHECK' then call check ok, kind 'x=' || x~left(16) '->' out~string~left(18) '(agrees with rx_vision_sqrt and the anchor)'
    if phase == 'AFTER' & kind == 'small' then do
      before = store~scalar("SELECT data AS d FROM lesson WHERE predicted = 'BEFORE' AND reason = ? AND data LIKE ? ORDER BY id LIMIT 1", store~binds('small' label, 'x=' || x 'out=%'))
      parse var before . 'out=' bOut .
      call check bOut == out & ok, 'small x=' || x~left(12) 'same output as before (' || out || ') and true'
    end
    if phase == 'AFTER' & kind == 'large' then do
      before = store~scalar("SELECT data AS d FROM lesson WHERE predicted = 'BEFORE' AND reason = ? AND data LIKE ? ORDER BY id LIMIT 1", store~binds('large' label, 'x=' || x 'out=%'))
      parse var before . 'out=' bOut .
      call check ok, 'large x=' || x~left(13) '->' out~string~left(16) 'agrees with the second way and the anchor (before:' bOut~string~left(16) || ')'
    end
  end
end
if phase == 'BEFORE' then call check falseLarge > 0, falseLarge 'of' large~items 'large values are false before the change (the bug, shown with data)'

/* how many steps the new loop takes, and that it ends for every size: count the halvings of a copy */
if phase \== 'BEFORE' then do
  do x over .array~of(0.0004, 1000000, 1E12, 4E18, 1E40)
    r = c~callOne(fd~routine, .array~of(x))
    call check r['STATUS'] == 'OK' & close(r['VALUE'], .SlamMaths~sqrtOf(x)), 'ends, and is true, for x=' || x '(' || stepsFor(x) 'steps)'
  end
end

/* timing: 3000 calls on door-sized values (variance of pixel steps, gradient sizes) */
call time 'R'
do i = 1 to 1000
  ignored = fd~routine~call(i / 7)
  ignored = fd~routine~call(i * 13.25)
  ignored = fd~routine~call(i * i + 0.5)
end
secs = time('E')
store~lesson(node, node, .true, phase, 'timing' label, '3000 calls' format(secs, , 4) 's')
store~commit
say '      timing:' phase '3000 calls' format(secs, , 4) 's'
if phase == 'AFTER' then do
  b = store~scalar("SELECT data AS d FROM lesson WHERE predicted = 'BEFORE' AND reason = ? ORDER BY id DESC LIMIT 1", store~binds('timing' label))
  say '      timing before:' b
end
store~close
say 'FDSQRT' phase 'TEST: PASS (' || checks || ' checks)'
exit 0

/* relative closeness at 1e-8: nine digits (the routine's NUMERIC DIGITS) less one */
close: procedure
  use arg got, want
  numeric digits 30
  if \datatype(got, 'N') then return .false
  if want = 0 then return got = 0
  return abs(got - want) / want <= 0.00000001

/* the same loop as the changed FDSqrt, counting steps (for the report only) */
stepsFor: procedure
  use arg x
  guess = x; if guess < 1 then guess = 1
  steps = 0
  do forever
    next = (guess + (x / guess)) / 2; steps += 1
    if next >= guess then leave
    guess = next
  end
  return steps

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
::requires 'SlamGround.cls'
