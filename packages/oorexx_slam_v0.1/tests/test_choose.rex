/* SLAM chooses a path itself (ChatGPT's third letter: "make a path that is not in the code you read. do
 * not take the path from me. first test if each call in the path can run. then use the scores to take one
 * path. run it with data that is not in the first test. get the same result in an other way. store both").
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 * Args: scratch dir | alchemy repo root | pool file (lines: path-under-repo routine-name)
 *
 * No path is given. SLAM reads the routines, takes their contracts from the code, makes edges only where
 * a give fits a need (ability first) and only between different files (so the path is not in the code),
 * runs each edge on probe data to score it, finds a second way for each node (a routine in another file
 * with the same contract that gives the same output on the probes), takes the highest-scoring path that
 * has a second way, runs it on new data, and checks it the second way. Every result is kept, true or false.
 * When the two ways disagree, a third way decides: a grounded maths anchor (TESTED in SlamGround) that gave
 * the same output as the routine on every probe value.
 */
signal on syntax name onSyntax
parse arg work '|' repo '|' poolFile
checks = 0
numeric digits 30
probe = .array~of(1, 2, 3, 10, 255, 1000, 65535)
fresh = .array~of(7, 42, 4097, 31337, 99991)
c = .SlamComposer~new
db = work || '/choose.db'
call SysFileDelete db; call SysFileDelete db || '-wal'; call SysFileDelete db || '-shm'
store = .SlamStore~new(db)

say '== 1. read the routines, take each contract from the code'
pool = .array~new; fileOf = .directory~new; nodeOf = .directory~new; lifted = 0
do while lines(poolFile) > 0
  parse value linein(poolFile) with path name .
  if name = '' then iterate
  alias = name~upper
  u = liftOne(c, repo || '/' || path, name, alias)
  if u == .nil then iterate
  lifted += 1
  if u~contract~args~items \= 1 then iterate
  pool~append(alias)
  fileOf[alias] = path
  nodeOf[alias] = store~codeNode(name '(' || path~substr(10)~left(path~substr(10)~pos('/') - 1) || ')')
end
call stream poolFile, 'C', 'CLOSE'
call check pool~items >= 10, lifted 'routines lifted;' pool~items 'take one argument'
input = .SlamContract~new('', 'INPUT', 'INPUT'); input~gives['NUMBER'] = .true
nIn = store~codeNode('number input')
store~begin
store~putContract(nIn, input)
do a over pool
  store~putContract(nodeOf[a], c~units[a]~contract)
end
store~commit

say '== 2. make edges where a give fits a need, only between different files'
nodes = .array~of(nIn); do a over pool; nodes~append(nodeOf[a]); end
store~begin
made = store~makeEdges(nodes)
store~commit
aliasOf = .directory~new; do a over pool; aliasOf[nodeOf[a]] = a; end
cand = .array~new
do a over pool
  do b over pool
    if a == b then iterate
    if fileOf[a] == fileOf[b] then iterate
    if \store~canRun(nodeOf[a], nodeOf[b])['OK'] then iterate
    if \store~canRun(nIn, nodeOf[a])['OK'] then iterate
    cand~append(.array~of(a, b))
  end
end
call check made > 0 & cand~items > 0, made 'edges made from contracts;' cand~items 'two-routine paths can run by contract, across files'

say '== 3. first test if each call can run: probe every edge on' probe~items 'values'
out1 = .directory~new
store~begin
do a over pool
  if \store~canRun(nIn, nodeOf[a])['OK'] then iterate
  res = .array~new
  do x over probe
    r = c~callOne(c~units[a]~routine, .array~of(x))
    ok = r['STATUS'] == 'OK'
    if ok then ok = kindOk(r['VALUE'], c~units[a]~contract)
    store~record(nIn, nodeOf[a], ok)
    if ok then res~append(r['VALUE']); else res~append('<error>')
  end
  out1[a] = res
end
do pr over cand
  a = pr[1]; b = pr[2]
  do i = 1 to probe~items
    if out1[a][i] == '<error>' then do
      store~record(nodeOf[a], nodeOf[b], .false)
      iterate
    end
    r = c~callOne(c~units[b]~routine, .array~of(out1[a][i]))
    ok = r['STATUS'] == 'OK'
    if ok then ok = kindOk(r['VALUE'], c~units[b]~contract)
    store~record(nodeOf[a], nodeOf[b], ok)
  end
end
store~commit
probed = store~scalar('SELECT count(*) AS n FROM weight')
call check probed > 0, probed 'edges now carry TESTED scores from the probe runs'

say '== 4. a second way: another routine, another file, same contract, same output on the probes'
twin = .directory~new
do a over pool
  if \out1~hasIndex(a) then iterate
  do b over pool
    if a == b then iterate
    if fileOf[a] == fileOf[b] then iterate
    if \out1~hasIndex(b) then iterate
    if c~units[a]~contract~canonicalText~substr(c~units[a]~contract~canonicalText~pos('|')) \== c~units[b]~contract~canonicalText~substr(c~units[b]~contract~canonicalText~pos('|')) then if \sameKinds(c~units[a]~contract, c~units[b]~contract) then iterate
    same = .true
    do i = 1 to probe~items
      if out1[a][i] == '<error>' | out1[b][i] == '<error>' then same = .false
      else if out1[a][i] \= out1[b][i] then same = .false
    end
    if same then do
      if \twin~hasIndex(a) then twin[a] = .array~new
      twin[a]~append(b)
    end
  end
end
twins = 0; do a over twin~allIndexes; twins += 1; say '      ' a~left(30) 'same as' twin[a]~makeString('L', ', '); end
call check twins > 0, twins 'routines have a second way'

say '== 5. use the scores to take one path (it must run, and it must have a second way)'
best = .nil; bestV = -1
do pr over cand
  a = pr[1]; b = pr[2]
  if \twin~hasIndex(a) then if \twin~hasIndex(b) then iterate
  v = store~rate(nIn, nodeOf[a])['SCORE'] * store~rate(nodeOf[a], nodeOf[b])['SCORE']
  if v > bestV then do
    bestV = v
    best = pr
  end
end
call check best \== .nil, 'chosen: input >' best[1] '(' || fileOf[best[1]] || ') >' best[2] '(' || fileOf[best[2]] || '), score' format(bestV, , 4)
a = best[1]; b = best[2]
alt = .nil
if twin~hasIndex(b) then alt = .array~of(a, twin[b][1])
else alt = .array~of(twin[a][1], b)
say '       second way: input >' alt[1] '(' || fileOf[alt[1]] || ') >' alt[2] '(' || fileOf[alt[2]] || ')'
call check \fileHas(repo || '/' || fileOf[a], b) & \fileHas(repo || '/' || fileOf[b], a), 'not in the code: neither file names the other routine'

say '== 6. run it with data not in the first test; check it the second way; keep both, true or false'
/* a third way for the node that has a twin: a maths anchor that matched it on every probe value */
twinNode = b; if \twin~hasIndex(b) then twinNode = a
anchorM = ''
do m over .array~of('ROOT', 'SQUARE')
  same = .true; compared = 0
  do i = 1 to probe~items
    inVal = probe[i]                               /* the same probe values the twin relation was found on */
    sig = c~callOne(c~units[twinNode]~routine, .array~of(inVal))
    if sig['STATUS'] \== 'OK' then iterate
    ref = .SlamMaths~send(m, .array~of(inVal))[1]
    compared += 1
    if \near(sig['VALUE'], ref) then same = .false
  end
  if same then if compared >= 3 then do
    anchorM = m
    leave
  end
end
say '       third way for' twinNode || ':' anchorM~lower 'anchor (SlamMaths, TESTED by grounding)'
agree = 0; decided = 0; disagree = 0; wrongCount = .directory~new
store~begin
do x over fresh
  r1 = c~run(.array~of(.array~of(a, .array~of(x)), .array~of(b, .array~of('PREV'))))
  r2 = c~run(.array~of(.array~of(alt[1], .array~of(x)), .array~of(alt[2], .array~of('PREV'))))
  both = r1['STATUS'] == 'OK' & r2['STATUS'] == 'OK'
  ok = .false
  if both then ok = r1['RESULT'] = r2['RESULT']
  v1 = r1['STATUS']; if v1 == 'OK' then v1 = r1['RESULT']
  v2 = r2['STATUS']; if v2 == 'OK' then v2 = r2['RESULT']
  verdict = ''
  if ok then agree += 1
  if \ok then if both then disagree += 1
  if \ok then if both then if anchorM \== '' then do
    if twinNode == b then inVal = c~units[a]~routine~call(x); else inVal = x
    ref = .SlamMaths~send(anchorM, .array~of(inVal))[1]
    rightA = near(v1, ref); rightB = near(v2, ref)
    if rightA \= rightB then do
      decided += 1
      loserName = twinNode; if rightA then do; if twinNode == b then loserName = alt[2]; else loserName = alt[1]; end
      verdict = '| third way:' format(ref, , 6) '->' loserName 'is wrong'
      if \wrongCount~hasIndex(loserName) then wrongCount[loserName] = 0
      wrongCount[loserName] = wrongCount[loserName] + 1
      gotV = v1
      if rightA then gotV = v2
      store~lesson(nodeOf[loserName], nodeOf[loserName], .false, 'THIRD_WAY', loserName 'differs from the' anchorM~lower 'anchor', 'input=' || inVal 'got=' || gotV 'anchor=' || ref)
    end
  end
  say '      ' x~right(6) '->' v1~string~left(14) ' second way ->' v2~string~left(14) ok verdict
  store~lesson(nodeOf[a], nodeOf[b], ok, r1['PREDICTION'], 'chosen path vs second way:' ok, 'x=' || x 'path=' || v1 'second=' || v2)
  store~lesson(nodeOf[alt[1]], nodeOf[alt[2]], ok, r2['PREDICTION'], 'second way vs chosen path:' ok, 'x=' || x 'second=' || v2 'path=' || v1)
end
store~commit
kept = store~scalar("SELECT count(*) AS n FROM lesson")
call check kept >= 2 * fresh~items, kept 'results stored (' || agree 'agree,' disagree 'disagree), true and false'
call check decided = disagree, 'every disagreement decided by the third way (' || decided 'of' disagree || ')'
do w over wrongCount~allIndexes
  say '       wrong on new data:' w '(' || fileOf[w] || ')' wrongCount[w] 'of' fresh~items 'values'
end
store~close
say 'CHOOSE TEST: PASS (' || checks || ' checks)'
exit 0

liftOne: procedure
  use arg c, file, name, alias
  signal on syntax name liftFailed
  return c~lift(file, name, alias)
liftFailed:
  return .nil

kindOk: procedure
  use arg v, k
  g = .SlamContract~keys(k~gives)
  select
    when g == 'NUMBER' then return datatype(v, 'N')
    when g == 'BOOLEAN' then return v == 0 | v == 1
    when g == 'ARRAY' then return v~isA(.array)
    otherwise return .true
  end

near: procedure
  use arg v, ref
  numeric digits 30
  if \datatype(v, 'N') then return .false
  if ref = 0 then return abs(v) < 1e-9
  return abs(v - ref) / abs(ref) < 1e-8

sameKinds: procedure
  use arg k1, k2
  if .SlamContract~keys(k1~gives) \== .SlamContract~keys(k2~gives) then return .false
  if k1~args~items \= k2~args~items then return .false
  do i = 1 to k1~args~items
    if .SlamContract~keys(k1~args[i]['KINDS']) \== .SlamContract~keys(k2~args[i]['KINDS']) then return .false
  end
  return .true

fileHas: procedure
  use arg file, needle
  text = charin(file, 1, chars(file)); call stream file, 'C', 'CLOSE'
  return text~caselessPos(needle) > 0

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
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')['MESSAGE']
  exit 1

::requires 'SlamCompose.cls'
::requires 'SlamGround.cls'
