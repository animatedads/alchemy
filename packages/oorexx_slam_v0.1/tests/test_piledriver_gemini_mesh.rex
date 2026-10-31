/* test_piledriver_gemini_mesh.rex - Gemini's third problem: mesh_network.log, four questions.
 *
 * The problem: Gemini (tests/gemini_to_slam_mesh.md; the log in tests/fixtures/piledriver/mesh_network.log).
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-31.
 * Each answer is computed, printed, then checked against the answer worked out by hand from the 10 lines.
 */
parse arg path
if path == '' then path = 'tests/fixtures/piledriver/mesh_network.log'
signal on syntax name failed
.local['GMPASS'] = 0
.local['GMFAIL'] = 0
log = .PiledriverLog~new
log~readFile(path)
say 'read' log~lineCount 'lines,' log~records~items 'records,' log~counts~items 'patterns; no model'

say ''
say '== first: the Send lines and their seq; is seq=<id> one pattern for node-2 and node-3?'
sends = .array~new
do r over log~records
  if r~body~word(1) == 'Send' then do
    sends~append(r)
    say '   line' r~lineNo~right(2) r~context~left(7) r~body~left(36) 'seq' log~valueOf(r, 'seq')
  end
end
pings = .directory~new
do r over sends
  if r~body~word(2) == 'ping' then pings[r~template] = (pings~hasIndex(r~template))~?(pings[r~template] || ',', '') || r~body~word(4)
end
do t over pings
  say '  ping pattern:' t '- for' pings[t]
end
vr = log~valueRoles('seq')
say '  what each seq is (Gemini''s rule, and LINK: new in each pattern, but in more than one):'
do v over vr~allIndexes~sort
  say '    seq' v vr[v]['ROLE'] '- in' vr[v]['COUNT'] 'lines (' || vr[v]['LINES']~makeString('L', ',') || '),' vr[v]['PATTERNS']~items 'patterns'
end
say '  by Gemini''s rule alone, seq is three things at once: a name in the ping pattern (each value once),'
say '  a code over all the seq lines for 101 (4 of 6), and neither for 102 (2 of 6). it is a LINK.'
call check sends~items == 3, 'three Send lines: 4 (ping), 6 (pong), 8 (ping)'
call check pings~items == 1, 'one ping pattern for node-2 and node-3: Send ping to node-# (seq=#)'
call check vr['101']['ROLE'] == 'LINK' & vr['102']['ROLE'] == 'LINK', 'seq 101 and 102 are LINKs'
call check vr['101']['LINES']~makeString('L', ',') == '4,5,6,7' & vr['102']['LINES']~makeString('L', ',') == '8,9', 'seq 101 ties lines 4-7, seq 102 ties lines 8-9'

say ''
say '== second: node-3 from START to DROP; does the ping at line 8 cause the timeout at line 9?'
ep = log~entityPaths('id', 'name', 'state', 2)
say '  node-3 (id 3):' ep['PATHS']['3']~makeString('L', ' -> ') '(lines' ep['LINES']['3']~makeString('L', ',') || ')'
own = .array~new
do r over log~records
  if r~context == 'node-3' then own~append(r~lineNo)
end
say '  lines node-3 writes itself:' own~makeString('L', ',')
sq = log~entityPaths('seq', 'name', 'state', 2)
do id over sq['ORDER']
  say '  seq' id || ':' sq['PATHS'][id]~makeString('L', ' -> ') '(lines' sq['LINES'][id]~makeString('L', ',') || ')'
end
answered = .array~new; unanswered = .array~new
do id over sq['ORDER']
  p = sq['PATHS'][id]
  if p~index('send_ping') \== .nil then do
    if p~index('recv_pong') \== .nil then answered~append(id)
    else unanswered~append(id)
  end
end
say '  rule "each send_ping has a recv_pong with the same seq":' tf(unanswered~items == 0) '(no pong for seq' unanswered~makeString('L', ',') || ')'
say '  "line 9 is about the ping at line 8": true. both lines hold seq=102, and line 9 waits for its pong.'
say '  "the ping causes the timeout": false. the timeout is the pong that did not come, not the ping.'
say '  "why no pong came": i do not know. node-3 writes no line after line 3: no "Recv ping" for seq 102,'
say '  so the log can not say if node-3 got the ping, or the pong was lost.'
call check ep['PATHS']['3']~makeString('L', ' -> ') == 'node_start -> send_ping -> timeout_waiting -> node_drop', 'node-3: node_start -> send_ping -> timeout_waiting -> node_drop'
call check ep['LINES']['3']~makeString('L', ',') == '3,8,9,10', '... at lines 3, 8, 9, 10'
call check own~items == 1 & own[1] == 3, 'node-3 itself writes only line 3'
call check unanswered~items == 1 & unanswered[1] == 102 & answered[1] == 101, 'seq 101 has its pong (line 7); seq 102 does not'

say ''
say '== third: a time gap of more than one second; a new interval boundary?'
gaps = log~timeGaps(1)
do d over gaps
  say '  gap: line' d['FROM'] '->' d['LINE'] || ':' d['GAP'] 's,' format(d['RATIO'], , 0) 'times the median gap'
end
say '  before this log: false. piledriver did not read time at all. now ~timeGaps(threshold) gives each gap'
say '  over the threshold (Gemini''s 1 s, the caller''s choice) and its size against the median gap.'
say '  the gap is the timeout: node-1 waits from 01.050 (the ping) to 02.051 (the timeout), 1.001 s.'
say '  no node writes a line in it, node-2 and node-3 too.'
call check gaps~items == 1, 'one gap over 1 s'
if gaps~items == 1 then do
  call check gaps[1]['FROM'] == 8 & gaps[1]['LINE'] == 9 & gaps[1]['GAP'] = 1.001, 'lines 8 -> 9: 1.001 s'
  call check gaps[1]['RATIO'] > 100, 'more than 100 times the median gap (' || format(gaps[1]['RATIO'], , 0) || ')'
end

say ''
say '== fourth: how many nodes are active after line 10?'
started = .array~new; dropped = .array~new
do r over log~records
  if r~body~word(1) == 'Node' then do
    if r~body~word(2) == 'START' then started~append(log~valueOf(r, 'id'))
    if r~body~word(2) == 'DROP' then dropped~append(log~valueOf(r, 'id'))
  end
end
lastBy = .directory~new
do r over log~records
  if r~context \== '' then lastBy[r~context] = r
end
say '  START lines:' started~items '(ids' started~makeString('L', ',') || '). Gemini says four nodes; the log has three.'
say '  DROP lines:' dropped~items '(id' dropped~makeString('L', ',') || ')'
say '  left by the log:' started~items - dropped~items
do n over lastBy~allIndexes~sort
  say '   ' n 'writes its last line at' lastBy[n]~lineNo '(' || lastBy[n]~stamp~strip('B', '[')~strip('T', ']') || ')'
end
say '  "node-1 and node-2 are active after line 10": i do not know. the log ends at line 10.'
say '  node-1 writes line 10, so it runs at line 10. node-2 writes nothing after line 6, 1.042 s before the end.'
say '  node-3 wrote nothing after line 3 too, and was dropped: a node with no lines is not shown to run.'
say '  so the log does not have enough to say they are active: false.'
call check started~items == 3, 'three START lines, not four'
call check dropped~items == 1 & dropped[1] == 3, 'one DROP: id 3'
call check started~items - dropped~items == 2, 'two left by the log: node-1 and node-2'
call check lastBy['node-1']~lineNo == 10 & lastBy['node-2']~lineNo == 6 & lastBy['node-3']~lineNo == 3, 'last lines: node-1 at 10, node-2 at 6, node-3 at 3'
call check log~recordAt(9)~verdict == 'WARN', 'line 9 is a WARN, as its level says (a weak keyword does not raise it)'
call check log~errors~items == 1 & log~errors[1]~lineNo == 10, 'one error: the DROP at line 10'

say ''
say 'GEMINI MESH TEST:' word('PASS FAIL', 1 + (.local['GMFAIL'] > 0)) '(' || .local['GMPASS'] 'passed,' .local['GMFAIL'] 'failed)'
exit .local['GMFAIL'] > 0

tf: procedure
  if arg(1) then return 'true'
  return 'false'

check: procedure
  use arg ok, text
  if ok then do
    .local['GMPASS'] = .local['GMPASS'] + 1
    say 'PASS ' text
  end
  else do
    .local['GMFAIL'] = .local['GMFAIL'] + 1
    say 'FAIL ' text
  end
  return

failed:
  say 'GEMINI MESH TEST: ERROR' condition('C') 'rc' rc 'line' sigl || ':' condition('D')
  exit 2

::requires 'PiledriverLog.cls'
