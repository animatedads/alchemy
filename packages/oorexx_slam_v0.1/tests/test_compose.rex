/* ChatGPT's task for SLAM, as a test.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.  Task: ChatGPT's second letter to SLAM.
 * Args: scratch dir | crypto.cls (any copy) | AdbAuth.cls
 *
 *  1. find two nodes that can work together: rx_pow_mod (crypto) gives NUMBER; _adbModInverse (ADB)
 *     needs NUMBER at argument 1
 *  2. what each needs and gives: their contracts
 *  3. a path that is not in the code: no file holds both; the two packages never refer to each other
 *  4. run it with new data: seeded random bases and exponents over four primes
 *  5. check the result a second way, two ways: x * y mod p = 1, and a different path through
 *     different nodes, rx_pow_mod(rx_mod_inverse(b, p), e, p), must give the same y
 *  6. break one part so that it should fail, and know why:
 *       A. rx_le_hex_encode in place of rx_pow_mod: the contracts say it cannot work (STRING into NUMBER)
 *       B. a modulus that shares a factor with the value: the contracts say it CAN work, and it fails;
 *          the failure teaches a need the code never stated
 *  7. keep every result, passed or failed, as a lesson in the store
 */
signal on syntax name onSyntax
parse arg work '|' cryptoFile '|' adbFile
checks = 0
numeric digits 40
c = .SlamComposer~new
powMod = c~lift(cryptoFile, 'rx_pow_mod', 'POWMOD')
adbInv = c~lift(adbFile, '_adbModInverse', 'ADBINV')
rxInv = c~lift(cryptoFile, 'rx_mod_inverse', 'RXINV')
hexEnc = c~lift(cryptoFile, 'rx_le_hex_encode', 'HEXENC')

say '== 1-2. what each needs and gives'
do u over .array~of(powMod, adbInv, rxInv, hexEnc)
  say '   ' u~alias~left(7) u~contract~canonicalText
end
f = c~canFollow('POWMOD', 'ADBINV', 1)
call check f['OK'], 'POWMOD then ADBINV can work:' f['REASON']

say '== 3. a path that is not in the code'
call check \fileHas(cryptoFile, '_adbModInverse') & \fileHas(adbFile, 'rx_pow_mod'), 'neither source file names the other routine (estate-wide grep: no composition)'

say '== 4-5. run it with new data, check it two ways'
db = work || '/compose.db'
call SysFileDelete db; call SysFileDelete db || '-wal'; call SysFileDelete db || '-shm'
store = .SlamStore~new(db)
nPow = store~codeNode('rx_pow_mod (crypto)'); nAdb = store~codeNode('_adbModInverse (adb)')
nRx = store~codeNode('rx_mod_inverse (crypto)'); nHex = store~codeNode('rx_le_hex_encode (crypto)')
primes = .array~of(1000003, 2147483647, 1000000007, 998244353)
seed = random(1, 2, 20261028)
runs = 0; agree = 0
store~begin
do p over primes
  do k = 1 to 3
    b = random(2, 99999) * 1000 + random(0, 999)
    if b >= p then b = b // (p - 2) + 2
    e = random(2, 99999)
    r = c~run(.array~of(.array~of('POWMOD', .array~of(b, e, p)), .array~of('ADBINV', .array~of('PREV', p))))
    x = powMod~routine~call(b, e, p)
    way1 = r['STATUS'] == 'OK' & (x * r['RESULT']) // p = 1
    r2 = c~run(.array~of(.array~of('RXINV', .array~of(b, p)), .array~of('POWMOD', .array~of('PREV', e, p))))
    way2 = r2['STATUS'] == 'OK' & r2['RESULT'] = r['RESULT']
    runs += 1
    if way1 & way2 then agree += 1
    data = 'b=' || b 'e=' || e 'p=' || p 'y=' || r['RESULT']
    store~lesson(nPow, nAdb, way1 & way2, r['PREDICTION'], 'x*y mod p = 1:' way1 '; second path agrees:' way2, data)
    if k = 1 then say '      ' data '  x*y mod p =' (x * r['RESULT']) // p '  second path:' r2['RESULT']
  end
end
store~commit
call check agree = runs, runs 'runs on new data; all' agree 'agree both ways (x*y mod p = 1, and (b^-1)^e mod p by another path)'

say '== 6A. break it so the contracts say it cannot work'
r = c~run(.array~of(.array~of('HEXENC', .array~of(255)), .array~of('ADBINV', .array~of('PREV', 1000003))))
say '       prediction:' r['PREDICTION']
say '       actual:    ' r['STATUS'] 'at' r['FAILED_AT'] '-' r['ERROR']
call check \r['FEASIBLE'] & r['STATUS'] == 'FAILED' & r['FAILED_AT'] == 'ADBINV', 'predicted before running, from the contracts, and it failed where predicted'
store~begin
store~lesson(nHex, nAdb, .false, r['PREDICTION'], r['ERROR'], 'HEXENC(255) into ADBINV')
store~commit

say '== 6B. break it so the contracts say it CAN work'
m = 2000006                                   /* 2 * 1000003 */
b = 123456; e = 77
r = c~run(.array~of(.array~of('POWMOD', .array~of(b, e, m)), .array~of('ADBINV', .array~of('PREV', m))))
x = powMod~routine~call(b, e, m)
say '       prediction:' r['PREDICTION']
say '       actual:    ' r['STATUS'] 'at' r['FAILED_AT'] '-' r['ERROR']
say '       why: x =' x 'and m =' m 'share the factor' gcd(x, m) || ', so x has no inverse mod m'
call check r['FEASIBLE'] & r['STATUS'] == 'FAILED' & gcd(x, m) > 1, 'the contracts did not predict it; the failure shows a need they never stated: no common factor'
rx = c~run(.array~of(.array~of('POWMOD', .array~of(b, e, m)), .array~of('RXINV', .array~of('PREV', m))))
rxText = rx['STATUS']
if rx['STATUS'] == 'OK' then rxText = 'OK, returned' rx['RESULT'] || '; x*y mod m =' (x * rx['RESULT']) // m
else rxText = rxText 'at' rx['FAILED_AT'] '-' rx['ERROR']
say '       same data through the crypto inverse:' rxText
store~begin
store~lesson(nPow, nAdb, .false, r['PREDICTION'], r['ERROR'] '| learned need: A1 and A2 have no common factor (gcd = 1)', 'b=' || b 'e=' || e 'm=' || m)
store~lesson(nPow, nRx, .false, rx['PREDICTION'], rxText, 'b=' || b 'e=' || e 'm=' || m)
store~commit

say '== 7. both results kept'
n = store~scalar('SELECT count(*) AS n FROM lesson')
nf = store~scalar('SELECT count(*) AS n FROM lesson WHERE passed = 0')
call check n = runs + 3 & nf = 3, n 'lessons kept,' nf 'of them failures'
d = store~rate(nPow, nAdb)
say '       edge rx_pow_mod -> _adbModInverse:' d['PASSES'] || '/' || d['TRIALS'] 'score' d['SCORE']
store~close
say 'COMPOSE TEST: PASS (' || checks || ' checks)'
exit 0

gcd: procedure
  use arg a, b
  numeric digits 40
  do while b \= 0
    t = a // b; a = b; b = t
  end
  return a

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
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D')
  exit 1

::requires 'SlamCompose.cls'
