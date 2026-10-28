/* PROVED: a tier above TESTED (SlamProof.cls, on ooRexx Maths v0.8's exact rationals).
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.  Maths v0.8: see its package.
 * Args: scratch dir | FDDoorMicroMotion.cls (now) | fixtures/fdsqrt_fixed14.cls (before) | Vision.cls |
 *       crypto.cls | AdbAuth.cls
 *
 *  1. each certificate says PROVED for a true claim and DISPROVED for a false one, and a tampered
 *     certificate does not check
 *  2. FDSqrt now: every result PROVED within 1e-8; "rounded to 9 digits" decided for each, either way
 *  3. FDSqrt before: the 12 false results DISPROVED, by a certificate, not by a vote; and Maths rule 9,
 *     "agreement is not accuracy": on the 7 probe values that made it rx_vision_sqrt's twin it agrees and
 *     is PROVED on each, yet "for every x" stays INDETERMINATE, and 1e8 is DISPROVED
 *  4. rx_mod_inverse: each valid result PROVED; each refusal backed by a DISPROVED claim of the need it names
 *  5. the gate on concrete data: before a path runs, a COPRIME proof predicts the failure the contract kinds
 *     could not (test_compose 6B), and a PROVED one predicts success, checked after the run
 *  6. proofs are kept apart from lessons: two tables, two facts
 */
signal on syntax name onSyntax
parse arg work '|' doorFile '|' oldFile '|' visionFile '|' cryptoFile '|' adbFile
checks = 0
numeric digits 2000
c = .SlamComposer~new
fdNow = c~lift(doorFile, 'FDSqrt', 'FDNOW')
fdOld = c~lift(oldFile, 'FDSqrt', 'FDOLD')
vs = c~lift(visionFile, 'rx_vision_sqrt', 'VSQRT')
inv = c~lift(cryptoFile, 'rx_mod_inverse', 'RXINV')
pow = c~lift(cryptoFile, 'rx_pow_mod', 'POWMOD')
adb = c~lift(adbFile, '_adbModInverse', 'ADBINV')
db = work || '/proof.db'
call SysFileDelete db; call SysFileDelete db || '-wal'; call SysFileDelete db || '-shm'
store = .SlamStore~new(db)
nNow = store~codeNode('FDSqrt (now)'); nOld = store~codeNode('FDSqrt (before 3761f57c)')
nInv = store~codeNode('rx_mod_inverse (crypto)'); nAdb = store~codeNode('_adbModInverse (adb)'); nPow = store~codeNode('rx_pow_mod (crypto)')
tol = 0.00000001
values = .array~of(0.0004, 0.25, 0.5, 1, 2, 3, 9, 10, 99.5, 144, 1000, 12345.678, 65025, 250000, 999999, 1000000, -
                   1000001, 10000000, 12345678.9, 99999999, 100000000, 330000000, 1000000000, 2000000000, -
                   10000000000, 777000000000, 1000000000000, 1E15, 4E18)
store~begin

say '== 1. a certificate proves a true claim, disproves a false one, and a tampered one does not check'
call check .SlamCertify~sqrtWithin(2, 1.41421356, tol)~outcome == 'PROVED', 'sqrt(2) within 1e-8 of 1.41421356: PROVED'
call check .SlamCertify~sqrtWithin(2, 1.4142136, tol)~outcome == 'DISPROVED', 'sqrt(2) within 1e-8 of 1.4142136: DISPROVED'
call check .SlamCertify~sqrtNearest(10, 3.16227766, 9)~outcome == 'PROVED' & .SlamCertify~sqrtNearest(10, 3.16227767, 9)~outcome == 'DISPROVED', 'sqrt(10) to 9 digits is 3.16227766, not 3.16227767'
call check .SlamCertify~modInverse(3, 7, 5)~outcome == 'PROVED' & .SlamCertify~modInverse(3, 7, 4)~outcome == 'DISPROVED', '3 * 5 = 1 mod 7; 3 * 4 is not'
call check .SlamCertify~gcdIs(4, 6, 2, -1, 1)~outcome == 'PROVED' & .SlamCertify~gcdIs(4, 6, 2, 1, 1)~outcome == 'DISPROVED', 'gcd(4, 6) = 2 with s = -1, t = 1; the same claim with a tampered s does not check'
call check .SlamCertify~gcdIs(4, 6, 1, -1, 1)~outcome == 'DISPROVED', 'gcd(4, 6) = 1 does not check: s*a + t*m is 2, not 1'
p = .SlamCertify~forAll('FDSqrt ends for every x')
call check p~outcome == 'INDETERMINATE', 'a claim about every input: INDETERMINATE (' || p~notes[1]~left(60) || '...)'
ignored = store~proof(nNow, p, 'every x > 0')

say '== 2. FDSqrt now: each result PROVED within 1e-8 (agreement with rx_vision_sqrt kept as a lesson, apart)'
within = 0; nearest = 0; notNearest = 0; agreeNow = 0; offButAgreed = 0
do x over values
  r = fdNow~routine~call(x)
  v = vs~routine~call(x)
  agree = r = v
  if agree then agreeNow += 1
  store~lesson(nNow, nNow, agree, 'AGREES', 'FDSqrt now and rx_vision_sqrt give the same number', 'x=' || x 'out=' || r 'second=' || v)
  if store~proof(nNow, .SlamCertify~sqrtWithin(x, r, tol), 'x=' || x 'out=' || r) == 'PROVED' then within += 1
  o = store~proof(nNow, .SlamCertify~sqrtNearest(x, r, 9), 'x=' || x 'out=' || r)
  if o == 'PROVED' then nearest += 1
  if o == 'DISPROVED' then do
    notNearest += 1
    if agree then offButAgreed += 1
    say '       not the nearest 9-digit number: x=' || x 'out=' || r '(within 1e-8 all the same)'
  end
end
call check within = values~items, within 'of' values~items 'results PROVED within 1e-8 of the true root'
call check nearest + notNearest = values~items, 'rounded to 9 digits: decided for all' values~items '(' || nearest 'PROVED,' notNearest 'DISPROVED), none INDETERMINATE'
say '       agreement with rx_vision_sqrt, kept as lessons:' agreeNow 'of' values~items 'give the same number'
call check notNearest > 0 & offButAgreed = notNearest, 'agreement is not accuracy, in the last digit: at all' notNearest 'values that are not the nearest 9-digit root, rx_vision_sqrt gives the same number'

say '== 3. FDSqrt before: false results DISPROVED by certificate; agreement is not accuracy'
wrong = 0; right = 0
do x over values
  r = fdOld~routine~call(x)
  o = store~proof(nOld, .SlamCertify~sqrtWithin(x, r, tol), 'x=' || x 'out=' || r)
  if o == 'DISPROVED' then wrong += 1
  if o == 'PROVED' then right += 1
end
call check wrong = 12 & right = 17, 'before the change: 12 results DISPROVED, 17 PROVED (the same split as the three-way vote, now each one certified)'
probe = .array~of(1, 2, 3, 10, 255, 1000, 65535)
agreeProbe = 0; provedProbe = 0
do x over probe
  r = fdOld~routine~call(x); v = vs~routine~call(x)
  if r = v then agreeProbe += 1
  if store~proof(nOld, .SlamCertify~sqrtWithin(x, r, tol), 'probe x=' || x 'out=' || r) == 'PROVED' then provedProbe += 1
end
call check agreeProbe = 7 & provedProbe = 7, 'on the 7 probe values that made it the twin of rx_vision_sqrt: agrees 7 of 7, PROVED 7 of 7'
p = .SlamCertify~forAll('the old FDSqrt is right for every x')
ignored = store~proof(nOld, p, 'every x > 0')
q = .SlamCertify~sqrtWithin(100000000, fdOld~routine~call(100000000), tol)
call check p~outcome == 'INDETERMINATE' & q~outcome == 'DISPROVED', 'yet "right for every x" is INDETERMINATE, and x=1e8 is DISPROVED:' q~notes[1]

say '== 4. rx_mod_inverse: valid results PROVED; each refusal backed by a DISPROVED claim of the need it names'
p25519 = 2**255 - 19
p448 = 2**448 - 2**224 - 1
valid = .array~of(.array~of(3, 7), .array~of(-3, 7), .array~of(121666, p25519), .array~of(5, p25519), .array~of(65537, 3120), .array~of(123456789, 1000000007), .array~of(2**200 + 1, p448), .array~of(1, 2))
invalid = .array~of(.array~of(0, 7), .array~of(7, 7), .array~of(14, 7), .array~of(4, 6), .array~of(1, 1), .array~of(5, 0), .array~of(5, -7), .array~of(0, p25519))
proved = 0
do v over valid
  y = inv~routine~call(v[1], v[2])
  if store~proof(nInv, .SlamCertify~modInverse(v[1], v[2], y), 'a=' || v[1]~left(20) 'm=' || v[2]~left(20) 'y=' || y~left(20)) == 'PROVED' then proved += 1
end
call check proved = valid~items, proved 'of' valid~items 'inverses PROVED: (a*y - 1) / m is whole, in exact rationals (the 448-bit one too)'
backed = 0
do v over invalid
  r = c~callOne(inv~routine, v)
  if r['STATUS'] == 'OK' then iterate
  if r['ERROR']~pos('gcd(value, modulus) = 1') > 0 then pr = .SlamCertify~coprime(v[1], v[2])
  else pr = .SlamCertify~above(v[2], 1)
  o = store~proof(nInv, pr, 'refused a=' || v[1]~left(12) 'm=' || v[2]~left(12))
  if o == 'DISPROVED' then backed += 1
  say '       a=' || v[1]~left(6) 'm=' || v[2]~left(6) pr~claim~kind~left(8) o~left(10) pr~notes[1]~left(80)
end
call check backed = invalid~items, 'all' invalid~items 'refusals backed: the need each error names is DISPROVED for that input'

say '== 5. the gate on concrete data: prove the need before the path runs'
do m over .array~of(2000006, 1000003)
  b = 123456; e = 77
  x = pow~routine~call(b, e, m)
  pr = .SlamCertify~coprime(x, m)
  o = store~proof(nAdb, pr, 'x=' || x 'm=' || m)
  if o == 'PROVED' then predicted = 'can run'; else predicted = 'will fail:' pr~notes[1]
  kinds = c~canFollow('POWMOD', 'ADBINV', 1)
  r = c~run(.array~of(.array~of('POWMOD', .array~of(b, e, m)), .array~of('ADBINV', .array~of('PREV', m))))
  say '       m=' || m~left(8) 'kinds:' kinds['OK']~left(2) 'proof:' o~left(10) 'prediction:' predicted~left(70)
  say '       ' r['STATUS'] '-' r['ERROR']~string~left(90)
  if o == 'DISPROVED' then call check kinds['OK'] & r['STATUS'] == 'FAILED', 'm=' || m || ': the kinds said it can run; the COPRIME proof said it will fail, before it ran, and it failed'
  else do
    after = .SlamCertify~modInverse(x, m, r['RESULT'])
    ignored = store~proof(nAdb, after, 'x=' || x 'm=' || m 'y=' || r['RESULT'])
    call check r['STATUS'] == 'OK' & after~outcome == 'PROVED', 'm=' || m || ': COPRIME PROVED before the run; after it, the result is a PROVED inverse'
  end
  store~lesson(nPow, nAdb, r['STATUS'] == 'OK', predicted, 'gate on data: coprime' o, 'b=' || b 'e=' || e 'm=' || m)
end

say '== 6. two tables, two facts'
store~commit
nP = store~scalar('SELECT count(*) AS n FROM proof')
nL = store~scalar('SELECT count(*) AS n FROM lesson')
nPr = store~scalar("SELECT count(*) AS n FROM proof WHERE outcome = 'PROVED'")
nDi = store~scalar("SELECT count(*) AS n FROM proof WHERE outcome = 'DISPROVED'")
nIn = store~scalar("SELECT count(*) AS n FROM proof WHERE outcome = 'INDETERMINATE'")
call check nP = nPr + nDi + nIn & nIn = 2 & nL = values~items + 2, nP 'proofs (' || nPr 'PROVED,' nDi 'DISPROVED,' nIn 'INDETERMINATE) and' nL 'lessons, kept apart'
store~close
say 'PROOF TEST: PASS (' || checks || ' checks)'
exit 0

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
::requires 'SlamProof.cls'
