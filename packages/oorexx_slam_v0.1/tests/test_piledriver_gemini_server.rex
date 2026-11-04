/* test_piledriver_gemini_server.rex - Gemini's second problem: server_crash.log, four questions.
 *
 * The problem: Gemini (tests/gemini_to_slam_server.md; the log in tests/fixtures/piledriver/server_crash.log).
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-30.
 * Each answer is computed, printed, then checked against the answer worked out by hand from the 11 lines.
 */
parse arg path
if path == '' then path = 'tests/fixtures/piledriver/server_crash.log'
signal on syntax name failed
.local['GSPASS'] = 0
.local['GSFAIL'] = 0
log = .PiledriverLog~new
log~readFile(path)
say 'read' log~lineCount 'lines,' log~records~items 'records,' log~counts~items 'patterns,' log~errors~items 'errors; no model'

say ''
say '== first: the URIs of the request lines; one pattern or two?'
uris = .directory~new; uriOrder = .array~new; uriPatterns = .directory~new; reqPatterns = .directory~new
do r over log~records
  do d over r~tokens
    if d['KEY'] \== 'uri' then iterate
    v = d['CORE']
    if \uris~hasIndex(v) then do
      uris[v] = .array~new
      uriOrder~append(v)
    end
    uris[v]~append(r~lineNo r~body~word(2))
    uriPatterns[.PiledriverWords~pathMask(v)] = 1
    reqPatterns[r~template] = 1
  end
end
do v over uriOrder
  say '  ' v~left(20) uris[v]~makeString('L', ', ')
end
say '  request patterns:' reqPatterns~items '(START, END, FAIL)'
do t over reqPatterns~allIndexes~sort
  say '    ' t
end
say '  URI patterns:' uriPatterns~items '-' uriPatterns~allIndexes~makeString('L', ' ')
say '  the id: by Gemini''s rule inside each request pattern it is new, so a name. Over the four uri lines'
say '  together, each id is in two of four (half): the rule says code. Four lines are too few for the rule;'
say '  a number in a path is a value (a name), as Gemini''s first letter says.'
call check uriOrder~items == 2, 'two URIs: /api/v1/user/101 and /api/v1/user/102'
call check uriPatterns~items == 1 & uriPatterns~hasIndex('/api/v1/user/#'), 'one URI pattern: /api/v1/user/#'
call check log~counts['INFO [http-nio-#-exec-#] c.a.s.RequestHandler - Request START uri=/api/v1/user/#'] == 2, 'the two START lines are one pattern'

say ''
say '== second: the pool''s active count; was active: 1 missed for exec-2?'
series = log~fieldSeries('active')
idle = log~fieldSeries('idle')
prev = 0; stepsOk = .true; sumOk = .true; missed = .array~new
do i = 1 to series~items
  s = series[i]
  verb = s['BODY']~word(1)
  want = prev + 1
  if verb == 'Return' then want = prev - 1
  ok = s['VALUE'] = want
  if \ok then stepsOk = .false
  if s['VALUE'] + idle[i]['VALUE'] \= 10 then sumOk = .false
  say '   line' s['LINE']~right(2) s['CONTEXT']~left(22) verb~left(7) 'active' s['VALUE'] 'idle' idle[i]['VALUE'] ' (' || verb 'from' prev 'gives' want || ':' tf(ok) || ')'
  prev = s['VALUE']
end
say '  rule "a Borrow adds one to active, a Return takes one away":' tf(stepsOk)
say '  rule "active + idle = 10 on each line":' tf(sumOk)
say '  active is a count for the whole pool, not for one thread. exec-2 sees 2 (line 4), then 0 (line 11);'
say '  the step to 1 is at line 6, when exec-1 returns its connection. No line is missed.'
borrows = 0; returns = 0
do s over series
  if s['CONTEXT'] == 'http-nio-8080-exec-2' then do
    if s['BODY']~word(1) == 'Borrow' then borrows += 1
    if s['BODY']~word(1) == 'Return' then returns += 1
  end
end
say '  exec-2: borrows' borrows', returns' returns '- its connection came back after the error (no leak)'
call check series~items == 4, 'four pool lines: 3, 4, 6, 11'
call check stepsOk & sumOk, 'each step is +1 or -1, and active + idle = 10: the counts are right'
call check series[3]['LINE'] == 6 & series[3]['VALUE'] == 1 & series[3]['CONTEXT'] == 'http-nio-8080-exec-1', 'active: 1 is at line 6, by exec-1'
call check borrows == 1 & returns == 1, 'exec-2 borrows once and returns once'

say ''
say '== third: the two lines with a tab: part of the error, or new patterns?'
r8 = log~recordAt(8)
say '  lines 9 and 10 start with a time stamp, not a tab; the tab comes after "c.a.s.RequestHandler - ".'
say '  each is a stack frame logged as its own event, on the same thread as line 8, so it joins record 8.'
do x = 1 to r8~lines~items
  say '    ' (r8~lineNo + x - 1)~right(2) r8~lines[x]~translate(' ', '09'x)~space(1)~right(70)
end
say '  record 8:' r8~verdict || '/' || r8~strength r8~reasons~makeString('L', '; ')
call check log~records~items == 9, '11 lines, 9 records'
call check r8~lines~items == 3, 'record 8 holds lines 8, 9 and 10'
call check r8~reasons~index('STACK') \== .nil, 'record 8 has a STACK'
call check log~errors~items == 2, 'two errors: line 7 (FAIL, status=500) and line 8 (OutOfMemoryError)'
call check log~recordAt(9) == r8 & log~recordAt(10) == r8, 'lines 9 and 10 are not new patterns'

say ''
say '== fourth: the class of the error; does it come from DataBuffer (line 9)?'
frames = .array~new
do x = 2 to r8~lines~items
  f = log~frameText(r8~lines[x])
  if f \== '' then frames~append(f)
end
top = frames[1]~word(2)
parse var top qual '(' fileLine ')'
cls = qual~left(qual~lastPos('.') - 1)
method = qual~substr(qual~lastPos('.') + 1)
say '  the error class:' r8~body~word(1)~strip('T', ':') ' (logged by' r8~message~word(3) || ', on' r8~context || ')'
say '  the frames, top first:'
do f over frames
  say '    ' f
end
say '  the top frame:' cls || '.' || method 'at' fileLine
say '  "the error was thrown in com.app.service.DataBuffer":' tf(cls == 'com.app.service.DataBuffer') '(the top frame is where it was thrown)'
say '  "DataBuffer is the cause of the memory use": i do not know. an OutOfMemoryError is thrown by the'
say '  allocation that fails, not by the code that used the memory; the log has no heap data. and the trace'
say '  has 2 frames, with no Thread.run at the bottom: the log may not have all of it.'
call check frames~items == 2, 'two frames'
call check cls == 'com.app.service.DataBuffer' & method == 'allocate' & fileLine == 'DataBuffer.java:42', 'top frame: com.app.service.DataBuffer.allocate (DataBuffer.java:42)'
call check r8~body~word(1) == 'java.lang.OutOfMemoryError:', 'the error class: java.lang.OutOfMemoryError'

say ''
say 'GEMINI SERVER TEST:' word('PASS FAIL', 1 + (.local['GSFAIL'] > 0)) '(' || .local['GSPASS'] 'passed,' .local['GSFAIL'] 'failed)'
exit .local['GSFAIL'] > 0

tf: procedure
  if arg(1) then return 'true'
  return 'false'

check: procedure
  use arg ok, text
  if ok then do
    .local['GSPASS'] = .local['GSPASS'] + 1
    say 'PASS ' text
  end
  else do
    .local['GSFAIL'] = .local['GSFAIL'] + 1
    say 'FAIL ' text
  end
  return

failed:
  say 'GEMINI SERVER TEST: ERROR' condition('C') 'rc' rc 'line' sigl || ':' condition('D')
  exit 2

::requires 'PiledriverLog.cls'
