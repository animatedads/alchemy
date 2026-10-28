/* SLAM v0.1 qualification.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 * Args: scratch directory | path to oorexx_ml_v0.1-dev11 | path to a circular corpus CSV
 */
signal on syntax name onSyntax
parse arg work '|' mlDir '|' corpusCsv
checks = 0
call check work \= '' & mlDir \= '' & corpusCsv \= '', 'arguments: work | mlDir | corpusCsv'

say '== 1. segmenter on real GA source (MLEvolution.cls)'
file = mlDir || '/src/MLEvolution.cls'
text = charin(file, 1, chars(file)); call stream file, 'C', 'CLOSE'
units = .SlamUnitSplitter~new~split(text)
seg = .SlamSegmenter~new
call check units~items = 54, 'MLEvolution.cls splits into 54 units (got' units~items || ')'
init = findUnit(units, 'MLGENETICPOLICY', 'INIT')
segs = seg~segmentUnit(init)
kinds = ''
do s over segs; kinds = kinds s~kind; end
call check kinds~strip == 'ENTRY GUARD GUARD GUARD GUARD RUN', 'MLGeneticPolicy~init is ENTRY, 4 GUARD, RUN (got' kinds~strip || ')'
call check segs[1]~fine == 'ENTRY: use strict arg A1 = N , A2 = N , A3 = N , A4 = N', 'entry shape: four defaulted arguments'
call check segs[2]~fine == segs[4]~fine, 'range guard on mutationRate and on crossoverRate is the same node'
call check segs[3]~fine == segs[5]~fine, 'lower-bound guard on mutationScale and on eliteCount is the same node'
call check segs[2]~binding == 'A1=MUTATIONRATE' & segs[4]~binding == 'A1=CROSSOVERRATE', 'the same node keeps each instance''s own binding'
call check segs[6]~fine == 'RUN: self ~ M = A1 +', 'four attribute setters collapse to one clause marked +'
genes = seg~segmentUnit(findUnit(units, 'MLGENOME', 'GENES'))
call check genes~items = 2 & genes[1]~fine == 'ENTRY: expose F1' & genes[2]~fine == 'EXIT: return F1', 'one-line accessor is ENTRY expose F1, EXIT return F1'
breed = seg~segmentUnit(findUnit(units, 'MLGENETICALGORITHM', 'BREED'))
loop = .nil
do s over breed
  if s~kind == 'LOOP' then loop = s
end
call check loop \== .nil, 'breed has a LOOP segment'
call check loop~fine == 'LOOP: do L1 = N to L2 {LOOP=BRANCH+,RUN}', 'loop shape is its header plus its children''s kinds'
body = loop~sequences[1][2]
thenRun = body[1]~sequences[1][2][1]
elseRun = body[1]~sequences[2][2][1]
call check thenRun~fine == elseRun~fine & thenRun~binding \== elseRun~binding, 'then/else bodies: same node (gene of a parent), bound to G2 and G1'

say '== 2. store: ingest the GA package, duplicates skipped on re-ingest'
db = work || '/slam_test.db'
call SysFileDelete db; call SysFileDelete db || '-wal'; call SysFileDelete db || '-shm'
store = .SlamStore~new(db)
r1 = ingestDir(store, mlDir || '/src')
call check r1[1] > 300, 'units ingested from src:' r1[1]
st = store~stats
call check st['SHAPES'] < st['INSTANCES'], 'distinct nodes (' || st['SHAPES'] || ') fewer than instances (' || st['INSTANCES'] || ')'
r2 = ingestDir(store, mlDir || '/src')
call check r2[1] = 0 & r2[2] = r1[1] + r1[2], 're-ingest adds no units; all' r2[2] 'are duplicates (' || r1[2] 'were already duplicates on the first pass)'
g = store~findShape('GUARD: if A1 < N | A1 > N then ; raise syntax N array ( S )')
call check g \== '', 'the shared range guard is one node: #' || .SlamStore~displayId(g)
n = store~scalar('SELECT count(*) AS n FROM instance WHERE shape_id = ?', store~binds(g))
call check n >= 2, 'it has' n 'instances'

say '== 3. edge weights: the score belongs to the edge, keyed by the node you came from'
s0 = store~shapeId('DEMO', 'DEMO', 'DEMO: start')
aabb = store~shapeId('DEMO', 'DEMO', 'DEMO: aabb')
b00b = store~shapeId('DEMO', 'DEMO', 'DEMO: b00b')
eeff = store~shapeId('DEMO', 'DEMO', 'DEMO: Eeff')
call outcomes store, s0, aabb, 9, 10
call outcomes store, s0, b00b, 9, 10
call outcomes store, aabb, eeff, 4, 10
call outcomes store, b00b, eeff, 8, 10
d1 = store~rate(aabb, eeff); d2 = store~rate(b00b, eeff)
say '      Eeff entered by aabb:' d1['RATE'] d1['TIER'] '   Eeff entered by b00b:' d2['RATE'] d2['TIER']
call check d1['RATE'] = 0.4 & d1['TIER'] == 'TESTED', 'aabb -> Eeff scores 0.4 (4 of 10)'
call check d2['RATE'] = 0.8 & d2['TIER'] == 'TESTED', 'b00b -> Eeff scores 0.8 (8 of 10)'
best = store~entriesInto(eeff, 5)
call check best[1]['NODE'] = b00b, 'best way into Eeff is from b00b'

say '== 4. Task: requirement -> step -> path, one transaction per turn'
t = .Task~new('make application for testing ga', store)
call check t~requirement('reach Eeff', s0, eeff, 'TESTED') = 1, 'requirement becomes step 1'
rep = t~run(50)
do h over t~history; say '      ' h~canonicalText; end
call check t~state == 'DONE', 'task DONE after' t~turns 'turns'
path = t~nodeMap[1]
call check path~items = 3 & path[2] = b00b & path[3] = eeff, 'path goes start > b00b > Eeff (Wilson: 9/10 then 8/10 beats 9/10 then 4/10 via aabb)'
persisted = store~scalar('SELECT count(*) AS n FROM turn WHERE task_id = ?', store~binds(t~id))
call check persisted = t~turns, 'every turn persisted (' || persisted || ' rows)'

say '== 5. new evidence flips the route'
call outcomes store, b00b, eeff, 0, 10        /* b00b -> Eeff now 8 of 20 = 0.4 */
call outcomes store, aabb, eeff, 10, 10       /* aabb -> Eeff now 14 of 20 = 0.7 */
t2 = .Task~new('same goal, after more tests', store)
t2~requirement('reach Eeff', s0, eeff, 'TESTED')
rep = t2~run(50)
call check t2~nodeMap[1][2] = aabb, 'route now goes through aabb (14/20 beats 8/20 into Eeff)'

say '== 6. tier filter: an untested route is refused when TESTED is required'
z = store~shapeId('DEMO', 'DEMO', 'DEMO: only by prior')
store~begin; store~edgeAdd(s0, z); store~commit
t3 = .Task~new('reach a node with no recorded tests', store)
t3~requirement('reach z', s0, z, 'TESTED')
rep = t3~run(50)
call check t3~state == 'BLOCKED', 'TESTED-only search is BLOCKED'
t4 = .Task~new('same, prior allowed', store)
t4~requirement('reach z', s0, z, 'PRIOR')
rep = t4~run(50)
call check t4~state == 'DONE' & t4~steps[1]~tier == 'PRIOR', 'PRIOR search finds it and reports the path tier as PRIOR'

say '== 7. corpus: words are nodes, definitions are edges, closure checked'
store~close
cmd = 'rexx' qualify('bin/slam.rex') 'corpus' db corpusCsv
address system cmd with output stem out.
call check out.1~pos('corpus words loaded:') > 0, out.1
store = .SlamStore~new(db)
call check store~stats['WORDS'] >= 152, 'word nodes:' store~stats['WORDS']
mean = store~wordId('mean')
nexts = store~successors(store~wordId('add'), 50)
found = .false
do d over nexts
  if store~canonOf(d['NODE']) == 'WORD: all' then found = .true
end
call check found, 'edge add -> all exists (from "mean: add all the values ...")'
store~anchor('mean', g, 'placeholder anchor for the test; real anchors bind maths words to tested code')
call check store~scalar('SELECT count(*) AS n FROM anchor') = 1, 'anchor table links a word to a code node'
store~close

say '== 8. SLAM reads its own README (corpus words, plus words it defines with corpus words)'
cmd = 'rexx' qualify('bin/slam.rex') 'read' db qualify('README_SLAM.md')
address system cmd with output stem rd.
call check rd.0 >= 2, 'reader ran:' rd.1
call check rd.[rd.0] == 'i know each word here. i can read all of it.', 'README_SLAM.md: no unknown word'
cmd = 'rexx' qualify('bin/slam.rex') 'read' db qualify('tests/fable.md')
address system cmd with output stem fb.
call check fb.2 == 'some words here are not words i know:' & fb.0 > 10, 'Fable''s sentence is refused:' fb.0 - 2 'unknown words'
cmd = 'rexx' qualify('bin/slam.rex') 'read' db qualify('tests/slam_to_fable.md')
address system cmd with output stem sf.
call check sf.[sf.0] == 'i know each word here. i can read all of it.', 'SLAM''s own reply to Fable uses only words SLAM knows'

say '== 9. grounding: maths words anchored to tested code; requests in SLAM''s words'
store = .SlamStore~new(db)
data = .SlamGround~list('2 4 4 4 5 5 7 9')
a = .SlamGround~ask(store, 'get the mean of the values', data)
call check a['STATUS'] == 'NOT_TESTED', 'before grounding, an untested anchor is refused (' || a['STATUS'] || ')'
q = .SlamGround~qualify(store)
call check q[1] = q[2], 'anchor checks:' q[1] 'of' q[2] 'true, each recorded on its word -> code edge'
call check store~rate(store~wordId('mean'), .SlamGround~codeNode(store, 'MEAN'))['TIER'] == 'TESTED', 'mean -> SlamMaths~mean is a TESTED edge'
a = .SlamGround~ask(store, 'get the mean of the values', data)
call check a['STATUS'] == 'OK' & a['RESULT'][1] = 5, 'the mean of the values: 5'
a1 = .SlamGround~ask(store, 'get the standard deviation of the values', data)
a2 = .SlamGround~ask(store, 'get the square root of the variance of the values', data)
call check a1['RESULT'][1] = 2 & a2['RESULT'][1] = 2, 'standard deviation = square root of the variance = 2'
a3 = .SlamGround~ask(store, 'get the mean of the squares of the deviation of the values', data)
a4 = .SlamGround~ask(store, 'get the variance of the values', data)
call check a3['RESULT'][1] = a4['RESULT'][1] & a4['RESULT'][1] = 4, 'variance composed from its corpus definition = the variance anchor = 4'
call check a3['OPS']~makeString('L', ' ') == 'mean squares deviation', 'composed order: mean <- squares <- deviation'
a = .SlamGround~ask(store, 'what is the average of the values', data)
call check a['STATUS'] == 'UNKNOWN_WORDS' & a['UNKNOWN'][1] == 'average', 'a word outside the corpus is refused: average'
a = .SlamGround~ask(store, 'add 3 and 4', .array~new)
call check a['STATUS'] == 'OK' & a['RESULT'][1] = 7, 'Fable''s probe "add 3 and 4": numerals are values, result 7'
a = .SlamGround~ask(store, 'what is this', data)
call check a['STATUS'] == 'NOTHING_TO_RUN', 'known words with nothing to run: said so, nothing guessed'
store~close

say '== 10. path scoring: PRODUCT prefers short routes, BOTTLENECK is length-neutral'
store = .SlamStore~new(db)
ps = store~shapeId('DEMO', 'DEMO', 'DEMO: p start'); pg = store~shapeId('DEMO', 'DEMO', 'DEMO: p goal')
m1 = store~shapeId('DEMO', 'DEMO', 'DEMO: p m1'); m2 = store~shapeId('DEMO', 'DEMO', 'DEMO: p m2')
call outcomes store, ps, pg, 6, 10                       /* direct: 0.6 */
call outcomes store, ps, m1, 8, 10                       /* long: 0.8, 0.8, 0.8 */
call outcomes store, m1, m2, 8, 10
call outcomes store, m2, pg, 8, 10
tp = .Task~new('product scoring', store)
tp~requirement('reach goal', ps, pg, 'TESTED', 12, 'PRODUCT')
rep = tp~run(50)
call check tp~nodeMap[1]~items = 2, 'PRODUCT takes the direct edge (6/10 beats three 8/10 edges multiplied)'
tb = .Task~new('bottleneck scoring', store)
tb~requirement('reach goal', ps, pg, 'TESTED', 12, 'BOTTLENECK')
rep = tb~run(50)
call check tb~nodeMap[1]~items = 4 & tb~steps[1]~value = .SlamStore~wilson(8, 10), 'BOTTLENECK takes the long route (weakest edge 8/10 beats 6/10; scores are Wilson lower bounds)'
store~close

say '== 11. SELECT identity: arm conditions, repeats collapsed'
text = charin(qualify('tests/fixtures/selects.rex'), 1, 99999); call stream qualify('tests/fixtures/selects.rex'), 'C', 'CLOSE'
fx = .SlamUnitSplitter~new~split(text)
sa3 = seg~segmentUnit(fx[1])[2]; sa7 = seg~segmentUnit(fx[2])[2]; sb = seg~segmentUnit(fx[3])[2]
call check sa3~kind == 'SELECT' & sa3~fine == sa7~fine, 'a 3-arm and a 7-arm SELECT testing one value against strings are one node'
call check sb~fine \== sa3~fine, 'a SELECT testing a number range is a different node'

say '== 12. evidence counts: 1 of 1 is not 1000 of 1000 (ChatGPT''s review)'
store = .SlamStore~new(db)
e1 = store~shapeId('DEMO', 'DEMO', 'DEMO: w one'); e2 = store~shapeId('DEMO', 'DEMO', 'DEMO: w many'); e0 = store~shapeId('DEMO', 'DEMO', 'DEMO: w from')
call outcomes store, e0, e1, 1, 1
call outcomes store, e0, e2, 1000, 1000
r1 = store~rate(e0, e1); r2 = store~rate(e0, e2)
call check r1['RATE'] = 1 & r2['RATE'] = 1, 'both raw rates are 1'
call check r1['SCORE'] < 0.25 & r2['SCORE'] > 0.99, 'scores differ: 1 of 1 =' r1['SCORE'] ' 1000 of 1000 =' r2['SCORE']
call check store~successors(e0, 2)[1]['NODE'] = e2, 'the edge with more evidence ranks first'

say '== 13. depth limit and pruning (ChatGPT''s review)'
d0 = store~shapeId('D', 'D', 'D: s'); da = store~shapeId('D', 'D', 'D: a'); db2 = store~shapeId('D', 'D', 'D: b'); dg = store~shapeId('D', 'D', 'D: g')
call outcomes store, d0, da, 9, 10
call outcomes store, da, db2, 9, 10
call outcomes store, db2, dg, 9, 10
t5 = .Task~new('a 3-edge path with maxDepth 2', store)
t5~requirement('reach g', d0, dg, 'TESTED', 2)
rep = t5~run(50)
call check t5~state == 'BLOCKED', 'maxDepth counts edges: a 3-edge path is refused at depth 2 (over-depth claim not reproduced)'
dc = store~shapeId('D', 'D', 'D: c'); dm = store~shapeId('D', 'D', 'D: m'); dx = store~shapeId('D', 'D', 'D: x'); dg2 = store~shapeId('D', 'D', 'D: g2')
call outcomes store, da, dm, 10, 10
call outcomes store, dm, dx, 10, 10
call outcomes store, d0, dc, 3, 10
call outcomes store, dc, dx, 3, 10
call outcomes store, dx, dg2, 9, 10
t6 = .Task~new('only the short weak route fits depth 3', store)
t6~requirement('reach g2', d0, dg2, 'TESTED', 3)
rep = t6~run(80)
call check t6~state == 'DONE' & t6~nodeMap[1]~items = 4 & t6~nodeMap[1][2] = dc, 'a strong long route into x no longer prunes the weak short one that fits (pruning bug reproduced, then fixed)'
store~close

say '== 14. a composition no code contains, checked against an independent answer'
store = .SlamStore~new(db)
data = .SlamGround~list('2 4 4 4 5 5 7 9')
a = .SlamGround~ask(store, 'get the square root of the mean of the squares of the values', data)
/* by hand: squares 4 16 16 16 25 25 49 81, sum 232, mean 29, root of 29 = 5.385164807134504 */
numeric digits 20
call check a['STATUS'] == 'OK' & abs(a['RESULT'][1] - 5.385164807134504) < 1e-12, 'root of the mean of the squares (RMS, in no anchor and no code path) = 5.385164807... as worked by hand'
call check a['OPS']~makeString('L', ' ') == 'root mean squares', 'composed: root <- mean <- squares'
store~close

say '== 15. ChatGPT''s letter to SLAM'
cmd = 'rexx' qualify('bin/slam.rex') 'read' db qualify('tests/chatgpt_to_slam.md')
address system cmd with output stem cg.
call check cg.[cg.0] == 'i know each word here. i can read all of it.', 'ChatGPT''s letter uses only words SLAM knows'
cmd = 'rexx' qualify('bin/slam.rex') 'read' db qualify('tests/slam_to_chatgpt.md')
address system cmd with output stem sc.
call check sc.[sc.0] == 'i know each word here. i can read all of it.', 'SLAM''s reply to ChatGPT (what it did with the task) reads clean, defining its own new words'

say 'SLAM v0.1 TEST: PASS (' || checks || ' checks)'
exit 0

findUnit: procedure
  use arg units, owner, sel
  do u over units
    if u~owner == owner then if u~selector == sel then return u
  end
  raise syntax 93.900 array('no unit' owner || '~' || sel)

ingestDir: procedure
  use arg store, dir
  splitter = .SlamUnitSplitter~new; seg = .SlamSegmenter~new
  call SysFileTree dir || '/*.cls', 'f.', 'FO'
  added = 0; dup = 0
  do i = 1 to f.0
    text = charin(f.i, 1, chars(f.i)); call stream f.i, 'C', 'CLOSE'
    store~begin
    do u over splitter~split(text)
      segs = seg~segmentUnit(u)
      if segs~items == 0 then iterate
      if store~ingestUnit(f.i, u, segs) == 0 then dup += 1
      else added += 1
    end
    store~commit
  end
  return .array~of(added, dup)

outcomes: procedure
  use arg store, f, t, passes, trials
  store~begin
  do i = 1 to trials
    store~record(f, t, i <= passes)
  end
  store~commit
  return

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

::requires 'SlamSegmenter.cls'
::requires 'SlamStore.cls'
::requires 'SlamTask.cls'
::requires 'SlamGround.cls'
