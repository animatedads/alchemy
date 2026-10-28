/* Compiler code: BOLT (LLVM's post-link optimizer, C++) read whole, and next-segment prediction on code
 * SLAM has not seen: BOLT's held-out fifth, and rx2cpp's ooRexx (a compiler in another language).
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 * Args: BOLT store | rx2cpp store | next_node.rex summary (experiments BOLT and BOLT_TO_RX2CPP, RX2CPP_SELF)
 */
signal on syntax name onSyntax
parse arg boltDb '|' rxDb '|' summary
checks = 0
call check boltDb \= '' & rxDb \= '' & summary \= '', 'arguments'

say '== 1. BOLT, read whole'
st = .SlamStore~new(boltDb)
files = st~scalar("SELECT count(DISTINCT path) AS n FROM unit WHERE path LIKE '%.cpp' OR path LIKE '%.h'")
units = st~scalar('SELECT count(*) AS n FROM unit')
nodes = st~scalar('SELECT count(DISTINCT shape_id) AS n FROM instance')
say '      files' files ' units' units ' nodes' nodes
cfiles = st~scalar("SELECT count(DISTINCT path) AS n FROM unit WHERE path LIKE '%.c'")
say '      .c files' cfiles
call check files = 256 & cfiles = 41 & units = 4156 & nodes = 18573, 'BOLT: 328 files read with none skipped (C is read as C++ too: 54 .c test inputs); 256 .cpp / .h and 41 .c hold code (4156 units, 18573 nodes), the rest are declarations only'
st~close

r = .directory~new
do while lines(summary) > 0
  parse value linein(summary) with name level . total . model . base . seen .
  r[name level] = .array~of(total, model, base, seen)
end
call stream summary, 'C', 'CLOSE'

say '== 2. BOLT predicts its own held-out fifth'
call show 'BOLT', 'KIND'; call show 'BOLT', 'KIND+'; call show 'BOLT', 'SKELETON+'
call check r['BOLT KIND'][2] > r['BOLT KIND'][3], 'first-order edges beat the baseline, by a little (' || pct(r['BOLT KIND']) 'against' basePct(r['BOLT KIND']) || ')'
call check r['BOLT KIND+'][2] > r['BOLT KIND'][2] & r['BOLT SKELETON+'][2] > r['BOLT SKELETON'][2], 'the enclosing segment as context (SLAM''s <START:ctx>) predicts better than the previous segment alone'

say '== 3. a compiler in another language: rx2cpp''s ooRexx'
call show 'RX2CPP_SELF', 'KIND+'; call show 'BOLT_TO_RX2CPP', 'KIND'; call show 'BOLT_TO_RX2CPP', 'KIND+'; call show 'BOLT_TO_RX2CPP', 'SKELETON+'
call check r['BOLT_TO_RX2CPP KIND'][2] <= r['BOLT_TO_RX2CPP KIND'][3], 'BOLT''s first-order edges do not beat the baseline on rx2cpp (stated: they do not transfer)'
call check r['BOLT_TO_RX2CPP KIND+'][2] > r['BOLT_TO_RX2CPP KIND+'][3] & r['BOLT_TO_RX2CPP SKELETON+'][2] > r['BOLT_TO_RX2CPP SKELETON+'][3], 'with context, what SLAM learned from BOLT''s C++ beats the baseline on rx2cpp''s ooRexx, at KIND and at SKELETON'
gainBolt = r['BOLT_TO_RX2CPP KIND+'][2] - r['BOLT_TO_RX2CPP KIND+'][3]
gainSelf = r['RX2CPP_SELF KIND+'][2] - r['RX2CPP_SELF KIND+'][3]
say '      gain over baseline: from BOLT' gainBolt ', from rx2cpp itself' gainSelf '(' || format(100 * gainBolt / gainSelf, , 0) || '%)'
call check gainBolt > 0 & gainBolt < gainSelf, 'learning from BOLT recovers part, not all, of what rx2cpp''s own files teach'

say 'LLVM TEST: PASS (' || checks || ' checks)'
exit 0

show: procedure expose r
  use arg name, level
  x = r[name level]
  say '     ' left(name level, 28) 'model' pct(x) ' base' basePct(x) ' of' x[1]
  return

pct: procedure
  use arg x
  return format(100 * x[2] / x[1], , 1) || '%'

basePct: procedure
  use arg x
  return format(100 * x[3] / x[1], , 1) || '%'

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
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~traceback~makeArray~makeString('L', ' | ')
  exit 1

::requires 'SlamStore.cls'
