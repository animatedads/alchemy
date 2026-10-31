/* test_piledriver_gemini_jvm.rex - Gemini's four tasks on jvm_startup.log, by Piledriver and SLAM's rules.
 *
 * The problem: Gemini (tests/gemini_to_slam_jvm.md, the log in tests/fixtures/piledriver/jvm_startup.log).
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-30.
 *
 * Arg: the log (default: tests/fixtures/piledriver/jvm_startup.log, from this package's directory).
 * Each answer is computed, printed, then checked against the answer worked out by hand from the 29 lines.
 */
parse arg path
if path == '' then path = 'tests/fixtures/piledriver/jvm_startup.log'
signal on syntax name failed
.local['GJPASS'] = 0
.local['GJFAIL'] = 0
log = .PiledriverLog~new
log~readFile(path)
say 'read' log~lineCount 'lines,' log~records~items 'records,' log~counts~items 'patterns; no model'

say ''
say '== first: threads, their states, and the path attached -> blocked_on_lock'
ep = log~entityPaths('id', 'name', 'state')
do id over ep['ORDER']
  say '  ' id ep['NAMES'][id]~left(20) 'START ->' ep['PATHS'][id]~makeString('L', ' -> ') '(lines' ep['LINES'][id]~makeString('L', ',') || ')'
end
say '  edges:'
do e over ep['EDGES']~allIndexes~sort
  say '    ' ep['EDGES'][e]~right(3) e
end
blocked = .array~new
do id over ep['ORDER']
  p = ep['PATHS'][id]
  do i = 2 to p~items
    if p[i - 1] == 'attached' then if p[i] == 'blocked_on_lock' then blocked~append(id '(' || ep['NAMES'][id] || ')')
  end
end
say '  threads with attached -> blocked_on_lock:' blocked~makeString('L', ', ')
say '  rule "the count of that path is one":' tf(blocked~items == 1) '(count' blocked~items || ')'
call check ep['ORDER']~items == 10, '10 threads (ids 1024 to 1033)'
call check ep['EDGES']['START -> attached'] == 10, 'START -> attached: 10'
call check ep['EDGES']['attached -> blocked_on_lock'] == 2, 'attached -> blocked_on_lock: 2'
call check ep['EDGES']['blocked_on_lock -> deadlock_risk_detected'] == 2, 'blocked_on_lock -> deadlock_risk_detected: 2'
call check blocked~items == 2, 'the path is taken by 1031 and 1032, so "count is one" is false'

say ''
say '== second: patterns and variables in the os,thread lines; where an edge count drops to one'
osr = .array~new
do r over log~records
  if r~tags == 'os,thread' then osr~append(r)
end
pc = .directory~new
do r over osr
  if pc~hasIndex(r~template) then pc[r~template] = pc[r~template] + 1
  else pc[r~template] = 1
end
do t over pc~allIndexes~sort
  say '  ' pc[t]~right(3) t
end
kinds = .directory~new
do r over osr
  do k over r~fieldOrder
    key = k r~fieldKinds[k]
    if kinds~hasIndex(key) then kinds[key] = kinds[key] + 1
    else kinds[key] = 1
  end
end
say '  variables (Gemini''s rule: in half the lines or more, seen twice or more: a code; new: a name):'
do k over kinds~allIndexes~sort
  say '    ' k~word(1)~left(6) k~word(2)~left(5) 'x' || kinds[k]
end
oe = .directory~new; dropLine = 0; dropText = ''
do i = 2 to osr~items
  e = osr[i - 1]~template || '0a'x || osr[i]~template
  if oe~hasIndex(e) then oe[e] = oe[e] + 1
  else oe[e] = 1
end
do i = 2 to osr~items
  e = osr[i - 1]~template || '0a'x || osr[i]~template
  if dropLine == 0 then if oe[e] == 1 then if i > 2 then if oe[osr[i - 2]~template || '0a'x || osr[i - 1]~template] > 1 then do
    dropLine = osr[i]~lineNo; dropText = osr[i]~head
  end
end
say '  edges between os,thread patterns, in order:'
do e over oe~allIndexes~sort
  parse var e a '0a'x b
  say '    ' oe[e]~right(3) word(a, 3) '->' word(b, 3)
end
say '  the edge count drops to one at line' dropLine || ':' dropText
call check pc['[os,thread] Thread attached (id: <id>, name: <name>)'] == 10, 'pattern: Thread attached (id: <id>, name: <name>), 10 lines'
call check pc['[os,thread] Thread state anomaly detected (id: <id>, state: BLOCKED_ON_LOCK)'] == 2, 'pattern: Thread state anomaly detected (id: <id>, state: BLOCKED_ON_LOCK), 2 lines'
call check kinds['id NAME'] == 12 & kinds['name NAME'] == 10 & kinds['state CODE'] == 2, 'id and name are names (new in each line); BLOCKED_ON_LOCK is a code (2 of 2)'
call check dropLine == 24, 'the edge count drops to one at line 24 (attached x9, then anomaly)'

say ''
say '== third: the safepoint rule'
pr = log~pairRule('Entering safepoint region', 'Leaving safepoint region')
say '  rule: an entering safepoint line has a leaving safepoint line after it, before the next entering line or the end'
say '  result:' tf(pr['RESULT'])
say '  proof:' pr['PROOF']
call check pr['RESULT'] & pr['PAIRS']~items == 3, 'true: 3 pairs (10 13, 22 23, 27 28)'
call check pr['PAIRS']~makeString('L', ',') == '10 13,22 23,27 28', 'the pairs are lines 10-13, 22-23, 27-28'

say ''
say '== fourth: where each class comes from; does the error at the end come from one of them?'
g = log~groupBy('source')
do v over g~allIndexes~sort
  say '  ' v~left(16) g[v]~items 'classes:' g[v]~makeString('L', ', ')
end
named = .array~new
errs = log~errors
do r over errs
  do v over g~allIndexes
    do item over g[v]
      cls = item~word(2)
      short = cls~substr(cls~lastPos('.') + 1)
      words = ' ' || r~message~translate('  ', '(),:') || ' '
      if words~pos(' ' || cls || ' ') > 0 | words~pos(' ' || short || ' ') > 0 then named~append(r~lineNo cls v)
    end
  end
end
say '  error lines:' errs~items
do r over errs
  say '    line' r~lineNo || ':' r~message
end
say '  classes named in an error line:' named~items
say '  "the error comes from a class in jrt":  i do not know (no error line names a class)'
say '  "the error comes from a class in file": i do not know (no error line names a class)'
say '  the order (a prior, not a test): file classes load at lines 16-17, the pool threads attach at 18-21,'
say '  two of them block (24-25) and the deadlock names them (26).  The name pool-1-thread-N is made by'
say '  java.util.concurrent, a jrt class, and the log has no class,load line for it: this log is not all of it.'
call check g['jrt:/java.base']~items == 3 & g['file:/app/bin/']~items == 2, 'jrt: Object, String, Class; file: CoreEngine, PipelineWorker'
call check named~items == 0, 'no error line names a class: neither rule is proved, the answer is "i do not know"'
call check errs~items == 2, 'two errors: the deadlock (26) and the abort (29)'
call check log~recordAt(26)~reasons~index('LEVEL ERROR') \== .nil, 'the deadlock line is an error by its [error] level'

say ''
say 'GEMINI JVM TEST:' word('PASS FAIL', 1 + (.local['GJFAIL'] > 0)) '(' || .local['GJPASS'] 'passed,' .local['GJFAIL'] 'failed)'
exit .local['GJFAIL'] > 0

tf: procedure
  if arg(1) then return 'true'
  return 'false'

check: procedure
  use arg ok, text
  if ok then do
    .local['GJPASS'] = .local['GJPASS'] + 1
    say 'PASS ' text
  end
  else do
    .local['GJFAIL'] = .local['GJFAIL'] + 1
    say 'FAIL ' text
  end
  return

failed:
  say 'GEMINI JVM TEST: ERROR' condition('C') 'rc' rc 'line' sigl || ':' condition('D')
  exit 2

::requires 'PiledriverLog.cls'
