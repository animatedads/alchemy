/* Gemini's two questions to SLAM (2026-10-29), as rules with tests.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5).  Questions: Gemini.
 * Args: scratch dir
 *
 *  1. "when two edges have the same score, how do you take one edge before the other edge?"
 *     Before: the frontier took the first entry found, and edges came back in whatever order SQLite gave.
 *     Now a stated rule: the higher value; on a tie, fewer edges; then more test results behind the path;
 *     then the lower node number.  Edge lists are ORDER BY node, so nothing depends on storage order.
 *  2. "when an edge has a result that is false, do you change the score ... or take the edge out?"
 *     The score changes; the edge stays.  Before: once an edge had any test result its prior was dropped,
 *     so one false result on an untested edge took its score from the prior to 0.  Now the prior counts as
 *     priorWeight test(s) (default 1), passing at the prior chance, and test results add to it.
 */
signal on syntax name onSyntax
parse arg work
checks = 0

say '== 1a. same value, different length (BOTTLENECK): fewer edges first'
st = fresh(work, 'tie_a')
s = st~codeNode('start'); a = st~codeNode('a'); g = st~codeNode('goal')
call outcomes st, s, g, 5, 5
call outcomes st, s, a, 5, 5
call outcomes st, a, g, 5, 5
path = route(st, s, g, 'BOTTLENECK')
call check path~items = 2, 'start > goal (1 edge) taken before start > a > goal (2 edges), both scoring' st~rate(s, g)['SCORE']
st~close

say '== 1b. same value, same length: more test results behind the path first'
st = fresh(work, 'tie_b')
s = st~codeNode('start'); p = st~codeNode('p'); q = st~codeNode('q'); g = st~codeNode('goal')
call outcomes st, s, p, 5, 5                      /* lower node number, less evidence */
call outcomes st, p, g, 5, 5
call outcomes st, s, q, 40, 40                    /* more evidence, and its weakest edge is the same 5/5 */
call outcomes st, q, g, 5, 5
path = route(st, s, g, 'BOTTLENECK')
call check path[2] = q, 'start > q > goal (45 results) taken before start > p > goal (10 results), the same weakest score'
st~close

say '== 1c. all equal: the lower node number, whatever order the results were stored in'
do order over .array~of('p first', 'q first')
  st = fresh(work, 'tie_c' || order~word(1))
  s = st~codeNode('start'); p = st~codeNode('p'); q = st~codeNode('q'); g = st~codeNode('goal')
  if order == 'p first' then do
    call outcomes st, s, p, 5, 5; call outcomes st, p, g, 5, 5
    call outcomes st, s, q, 5, 5; call outcomes st, q, g, 5, 5
  end
  else do
    call outcomes st, q, g, 5, 5; call outcomes st, s, q, 5, 5
    call outcomes st, p, g, 5, 5; call outcomes st, s, p, 5, 5
  end
  path = route(st, s, g, 'PRODUCT')
  call check path[2] = p & p < q, 'stored' order || ': start > p > goal (p is node' p || ', q is node' q || ')'
  st~close
end

say '== 1d. lists of edges: tested before prior, then score, then count in the code, then the lower node'
st = fresh(work, 'tie_d')
s = st~codeNode('start'); x = st~codeNode('x'); y = st~codeNode('y')
call outcomes st, s, y, 5, 5
call outcomes st, s, x, 5, 5
succ = st~successors(s)
call check succ[1]['NODE'] = x & succ[2]['NODE'] = y & x < y, 'equal edges list in node order (x' x 'before y' y || '), not in the order they were stored'
st~close

say '== 2. a false result lowers the score; the edge stays, and its prior is not wiped'
st = fresh(work, 'prior')
s = st~codeNode('start'); e = st~codeNode('e'); f = st~codeNode('f'); g = st~codeNode('goal')
st~begin
st~q('INSERT INTO edge (from_id, to_id, freq) VALUES (?, ?, ?)', st~binds(s, e, 3))   /* prior: 3 of 5 */
st~q('INSERT INTO edge (from_id, to_id, freq) VALUES (?, ?, ?)', st~binds(s, f, 2))
st~q('INSERT INTO edge (from_id, to_id, freq) VALUES (?, ?, ?)', st~binds(e, g, 1))
st~commit
prior = st~rate(s, e)
call check prior['TIER'] == 'PRIOR' & prior['SCORE'] > 0, 'start > e from the code alone: PRIOR, score' prior['SCORE'] '(3 of 5)'
call outcomes st, s, e, 0, 1
one = st~rate(s, e)
st~priorWeight = 0
old = st~rate(s, e)
st~priorWeight = 1
call check old['SCORE'] = 0, 'the old rule: one false result and the score is 0 (the prior is dropped)'
call check one['TIER'] == 'TESTED' & one['SCORE'] > 0 & one['SCORE'] < prior['SCORE'], 'now: one false result lowers it from' prior['SCORE'] 'to' one['SCORE'] || ', and the edge stays'
st~priorWeight = 0
t0 = .Task~new('old rule', st); ignored = t0~requirement('reach goal', s, g, 'PRIOR')
ignored = t0~run(50)
st~priorWeight = 1
t1 = .Task~new('new rule', st); ignored = t1~requirement('reach goal', s, g, 'PRIOR')
ignored = t1~run(50)
call check t0~state == 'BLOCKED' & t1~state == 'DONE', 'start > e > goal is the only route: BLOCKED under the old rule, found under the new one (state' t0~state '->' t1~state || ')'
call outcomes st, s, e, 1, 1
up = st~rate(s, e)
call check up['SCORE'] > one['SCORE'], 'a true result after it raises the score again:' one['SCORE'] '->' up['SCORE']
gapFew = abs(up['SCORE'] - .SlamStore~wilson(up['PASSES'], up['TRIALS']))
call outcomes st, s, e, 40, 40
many = st~rate(s, e)
plain = .SlamStore~wilson(many['PASSES'], many['TRIALS'])
gapMany = abs(many['SCORE'] - plain)
call check gapMany < gapFew / 4, 'the prior counts less as results come in: it moves the score by' format(gapFew, , 4) 'at 2 results, by' format(gapMany, , 4) 'at 42'
madeS = st~codeNode('made'); madeT = st~codeNode('made target')
call outcomes st, madeS, madeT, 0, 1
call check st~rate(madeS, madeT)['SCORE'] = 0, 'an edge with no prior (made from contracts) is scored by tests alone, as before: 0 of 1 is 0'
st~close
say 'TIES TEST: PASS (' || checks || ' checks)'
exit 0

fresh: procedure
  use arg work, name
  db = work || '/' || name || '.db'
  call SysFileDelete db; call SysFileDelete db || '-wal'; call SysFileDelete db || '-shm'
  return .SlamStore~new(db)

outcomes: procedure
  use arg store, f, t, passes, trials
  store~begin
  do i = 1 to trials
    store~record(f, t, i <= passes)
  end
  store~commit
  return

route: procedure
  use arg store, f, t, scoring
  task = .Task~new('route', store)
  ignored = task~requirement('reach goal', f, t, 'PRIOR', 12, scoring)
  ignored = task~run(100)
  if task~state \== 'DONE' then return .array~new
  return task~nodeMap[1]

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

::requires 'SlamTask.cls'
