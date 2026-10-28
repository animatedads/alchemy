/* Ability before score, on real contracts. Rule proposed by Claude (Opus 4.8) from the Reasoned Thought
 * side (its standalone needs_gives_demo.rex, 7/7); asked for by ChatGPT ("a path must first be able to do
 * the work. only then should its score help you choose").
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.
 * Args: scratch dir | crypto.cls | AdbAuth.cls
 */
signal on syntax name onSyntax
parse arg work '|' cryptoFile '|' adbFile
checks = 0
numeric digits 40
c = .SlamComposer~new
pow = c~lift(cryptoFile, 'rx_pow_mod', 'POWMOD')
adb = c~lift(adbFile, '_adbModInverse', 'ADBINV')
rxi = c~lift(cryptoFile, 'rx_mod_inverse', 'RXINV')
hex = c~lift(cryptoFile, 'rx_le_hex_encode', 'HEXENC')
db = work || '/needs.db'
call SysFileDelete db; call SysFileDelete db || '-wal'; call SysFileDelete db || '-shm'
store = .SlamStore~new(db)
nStart = store~codeNode('task start')
nPow = store~codeNode('rx_pow_mod (crypto)'); nAdb = store~codeNode('_adbModInverse (adb)')
nRx = store~codeNode('rx_mod_inverse (crypto)'); nHex = store~codeNode('rx_le_hex_encode (crypto)')
store~begin
store~putContract(nPow, pow~contract); store~putContract(nAdb, adb~contract)
store~putContract(nRx, rxi~contract); store~putContract(nHex, hex~contract)
store~commit

say '== 1. an edge can run when the first node gives what the next node needs'
k = store~canRun(nPow, nAdb)
call check k['OK'], 'rx_pow_mod -> _adbModInverse can run:' k['REASON']
k = store~canRun(nHex, nAdb)
call check \k['OK'] & k['REASON']~pos('needs NUMBER at argument 1') > 0 & k['REASON']~pos('gives STRING') > 0, 'rx_le_hex_encode -> _adbModInverse can not run, and the need is named:' k['REASON']
call check store~canRun(nStart, nAdb)['OK'], 'a node with no contract is not judged (the gate refuses only what it can explain)'

say '== 2. ability before score: the higher score loses when its path cannot run'
call outcomes store, nStart, nPow, 9, 10
call outcomes store, nStart, nHex, 9, 10
call outcomes store, nHex, nAdb, 10, 10          /* a recorded score that is high, on an edge that cannot run */
call outcomes store, nPow, nAdb, 8, 10
hs = store~rate(nHex, nAdb)['SCORE']; ps = store~rate(nPow, nAdb)['SCORE']
call check hs > ps, 'by score alone the hex route wins (' || hs '>' ps || ')'
t = .Task~new('reach the inverse', store)
t~requirement('reach _adbModInverse', nStart, nAdb, 'TESTED')
rep = t~run(50)
refusedSeen = .false
do h over t~history
  say '      ' h~canonicalText~left(170)
  if h~detail~pos('refused=1') > 0 then refusedSeen = .true
end
call check t~state == 'DONE' & t~nodeMap[1][2] = nPow, 'the path goes through rx_pow_mod: the route that can run'
call check refusedSeen, 'the refused edge is in the turn record, with its reason'

say '== 3. a path that cannot run says why'
call outcomes store, nHex, nRx, 10, 10
t2 = .Task~new('reach the crypto inverse through hex only', store)
t2~requirement('reach rx_mod_inverse', nStart, nRx, 'TESTED')
rep = t2~run(50)
say '      ' rep~canonicalText~left(170)
last = t2~history[t2~history~items - 1]
call check t2~state == 'BLOCKED' & last~detail~pos('cannot run:') > 0 & last~detail~pos('gives STRING') > 0, 'BLOCKED, and the last turn names the node, the need and the give that is not there'

say '== 4. new work from old: edges the code never had, scored only by tests'
store~begin
made = store~makeEdges(.array~of(nPow, nAdb, nRx, nHex))
store~commit
call check made > 0, made 'edges made from contracts'
call check store~scalar('SELECT count(*) AS n FROM edge WHERE from_id = ? AND to_id = ? AND freq = 0', store~binds(nPow, nRx)) = 1, 'rx_pow_mod -> rx_mod_inverse is a made edge (never next in any code)'
bad = store~scalar('SELECT count(*) AS n FROM edge WHERE from_id = ? AND freq = 0', store~binds(nHex))
call check bad = 0, 'no edge is made from rx_le_hex_encode: it gives STRING and every node here needs NUMBER'
d = store~rate(nPow, nRx)
call check d['TIER'] \== 'TESTED' & d['SCORE'] = 0, 'a made edge has no prior and scores nothing before a test (tier' d['TIER'] || ')'
t3 = .Task~new('reach rx_mod_inverse by a made edge, untested', store)
t3~requirement('reach rx_mod_inverse', nPow, nRx, 'PRIOR')
rep = t3~run(50)
call check t3~state == 'BLOCKED', 'untested, the made edge is not used'
/* test it for real: run rx_pow_mod then rx_mod_inverse on new data, check x*y mod p = 1 */
store~begin
p = 1000000007
do i = 1 to 6
  b = 1000 + i * 7919; e = 65537 + i
  r = c~run(.array~of(.array~of('POWMOD', .array~of(b, e, p)), .array~of('RXINV', .array~of('PREV', p))))
  x = pow~routine~call(b, e, p)
  ok = r['STATUS'] == 'OK' & (x * r['RESULT']) // p = 1
  store~lesson(nPow, nRx, ok, r['PREDICTION'], 'x*y mod p = 1:' ok, 'b=' || b 'e=' || e 'p=' || p)
end
store~commit
t4 = .Task~new('reach rx_mod_inverse by a made edge, tested', store)
t4~requirement('reach rx_mod_inverse', nPow, nRx, 'TESTED')
rep = t4~run(50)
call check t4~state == 'DONE' & store~rate(nPow, nRx)['PASSES'] = 6, 'after 6 real runs (x*y mod p = 1 each time) the made edge is TESTED and the path is used'
store~close
say 'NEEDS TEST: PASS (' || checks || ' checks)'
exit 0

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

::requires 'SlamCompose.cls'
::requires 'SlamTask.cls'
