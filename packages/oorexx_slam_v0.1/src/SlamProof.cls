/* SlamProof.cls - a tier above TESTED.  A claim about a result is PROVED, DISPROVED or INDETERMINATE by a
 * certificate, and every check of the certificate is done in exact rationals (.MathRational, ooRexx Maths
 * v0.8, its CERTIFIED route: pure ooRexx, no provider).  Each answer is a Maths .MathProof, so its status,
 * outcome, checks and notes mean what they mean in Maths.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.  Maths v0.8: see its package.
 *
 * Maths rule 9: "Agreement is not accuracy."  A lesson says two ways agreed (or not); a proof says a claim
 * holds for one stated input.  SLAM keeps them apart, and a proof about values is never a proof about all
 * values: forAll gives INDETERMINATE, and says why.
 *
 * Certificates here (each one cheap to check, whatever it cost to find):
 *   sqrtWithin    sqrt(x) lies in [r - d, r + d], d = r * tol:     (r-d)**2 <= x <= (r+d)**2
 *   sqrtNearest   r is sqrt(x) rounded to n significant digits:   (r-u/2)**2 <= x <= (r+u/2)**2, u = one unit
 *                 in the n-th digit of r
 *   modInverse    y is the inverse of a modulo m:                 m > 1 and (a*y - 1) / m is whole
 *   gcdIs         g = gcd(a, m):                                   s*a + t*m = g, and g divides a and m
 *                 (any common divisor divides s*a + t*m = g; g is one, so it is the greatest)
 *   coprime       gcd(a, m) = 1: gcdIs, with the Bezout pair found here; a g > 1 that divides both is the
 *                 certificate that the claim is false
 *   above         v > bound
 *   forAll        no route: a claim about every input is an argument about the code, not a value
 */
::requires 'Maths.cls'

::class SlamCertify public

::method q class private
  use strict arg v
  return .MathRational~coerce(v~string, .MathContext~rational)

::method whole class private
  use strict arg r
  return r~denominator = 1

::method answer class private
  use strict arg ok, claim, checks, notes, evidence
  if ok then return .MathProof~new('EXACT_BOUND_CERTIFIED', evidence, .nil, checks, notes, claim, .nil, 'PROVED')
  return .MathProof~new('DISPROVED', evidence, .nil, checks, notes, claim, .nil, 'DISPROVED')

::method undecided class private
  use strict arg claim, checks, note
  return .MathProof~new('UNVERIFIED', .nil, .nil, checks, .array~of(note), claim, .nil, 'INDETERMINATE')

::method sqrtWithin class
  use strict arg x, r, tol
  numeric digits max(60, length(x) + length(r) + 10)
  claim = .MathClaim~new('SQRT_WITHIN_RELATIVE', r, tol, 'sqrt(x) lies within r*tol of r')
  checks = .directory~new; checks['x'] = x; checks['r'] = r; checks['tol'] = tol
  if \datatype(x, 'N') | \datatype(r, 'N') then return self~undecided(claim, checks, 'x or r is not a number')
  xq = self~q(x); rq = self~q(r); D = (rq * self~q(tol))~abs
  if xq < 0 then return self~undecided(claim, checks, 'x < 0: no real square root to bound')
  lo = rq - D; hi = rq + D
  if lo < 0 then lo = self~q(0)
  lo2 = lo * lo; hi2 = hi * hi
  checks['lower**2'] = lo2~canonical; checks['upper**2'] = hi2~canonical
  ok = lo2 <= xq & xq <= hi2
  notes = .array~new
  if \ok & xq < lo2 then notes~append('x < (r-d)**2: r is too high')
  if \ok & xq > hi2 then notes~append('x > (r+d)**2: r is too low')
  if ok then notes~append('(r-d)**2 <= x <= (r+d)**2, decided in exact rationals')
  return self~answer(ok, claim, checks, notes, hi2~evidence)

::method sqrtNearest class
  use strict arg x, r, n
  numeric digits max(60, length(x) + length(r) + 10)
  claim = .MathClaim~new('SQRT_NEAREST', r, n, 'r is sqrt(x) rounded to' n 'significant digits')
  checks = .directory~new; checks['x'] = x; checks['r'] = r; checks['digits'] = n
  if \datatype(x, 'N') | \datatype(r, 'N') then return self~undecided(claim, checks, 'x or r is not a number')
  xq = self~q(x); rq = self~q(r)
  if xq < 0 | rq <= 0 then return self~undecided(claim, checks, 'needs x >= 0 and r > 0')
  parse value format(r, , , , 0) with . 'E' e
  if e = '' then e = 0
  if e - n + 1 >= 0 then unit = self~q(10 ** (e - n + 1))   /* one unit in the n-th significant digit of r */
  else unit = self~q(1) / self~q(10 ** (n - 1 - e))
  half = unit / 2
  lo = rq - half; hi = rq + half
  lo2 = lo * lo; hi2 = hi * hi
  checks['unit'] = unit~canonical; checks['lower**2'] = lo2~canonical; checks['upper**2'] = hi2~canonical
  ok = lo2 <= xq & xq <= hi2
  notes = .array~new
  if ok then notes~append('(r-u/2)**2 <= x <= (r+u/2)**2: no number with' n 'digits is nearer')
  else if xq < lo2 then notes~append('x < (r-u/2)**2: r is high by at least half a unit in the last digit')
  else notes~append('x > (r+u/2)**2: r is low by at least half a unit in the last digit')
  return self~answer(ok, claim, checks, notes, hi2~evidence)

::method modInverse class
  use strict arg a, m, y
  numeric digits max(60, length(a) + length(m) + length(y) + 10)   /* so 'whole' means whole for big numbers */
  claim = .MathClaim~new('MOD_INVERSE', y, m, 'a*y = 1 modulo m, m > 1')
  checks = .directory~new; checks['a'] = a; checks['m'] = m; checks['y'] = y
  if \datatype(a, 'W') | \datatype(m, 'W') | \datatype(y, 'W') then return self~undecided(claim, checks, 'a, m and y must be whole numbers')
  mq = self~q(m)
  if mq <= 1 then return self~answer(.false, claim, checks, .array~of('m <= 1: no inverse is defined'), mq~evidence)
  k = (self~q(a) * self~q(y) - 1) / mq
  checks['(a*y-1)/m'] = k~canonical
  ok = self~whole(k)
  if ok then note = '(a*y - 1) / m is whole'; else note = '(a*y - 1) / m is not whole'
  return self~answer(ok, claim, checks, .array~of(note), k~evidence)

::method gcdIs class
  use strict arg a, m, g, s, t
  numeric digits max(60, length(a) + length(m) + length(s) + length(t) + 10)
  claim = .MathClaim~new('GCD_EQUALS', g, .nil, 'gcd(a, m) = g, with Bezout pair s, t')
  checks = .directory~new; checks['a'] = a; checks['m'] = m; checks['g'] = g; checks['s'] = s; checks['t'] = t
  gq = self~q(g)
  if gq <= 0 then return self~answer(.false, claim, checks, .array~of('g <= 0'), gq~evidence)
  combo = self~q(s) * self~q(a) + self~q(t) * self~q(m)
  da = self~q(a) / gq; dm = self~q(m) / gq
  checks['s*a+t*m'] = combo~canonical
  ok = combo = gq & self~whole(da) & self~whole(dm)
  notes = .array~new
  if ok then notes~append('s*a + t*m = g and g divides a and m: every common divisor divides g, so g is the greatest')
  else notes~append('the certificate does not check')
  return self~answer(ok, claim, checks, notes, combo~evidence)

/* gcd(a, m) = 1?  Finds g, s, t (extended Euclid, plain Rexx: the finding is not trusted), then checks. */
::method coprime class
  use strict arg a, m
  numeric digits max(60, length(a) + length(m) + 10)
  claim = .MathClaim~new('COPRIME', 1, .nil, 'gcd(a, m) = 1')
  if \datatype(a, 'W') | \datatype(m, 'W') then return self~undecided(claim, .directory~new, 'a and m must be whole numbers')
  parse value self~bezout(abs(a), abs(m)) with g s t
  if a < 0 then s = -s
  if m < 0 then t = -t
  cert = self~gcdIs(a, m, g, s, t)
  checks = cert~checks
  if cert~outcome \== 'PROVED' then return self~undecided(claim, checks, 'the gcd certificate did not check')
  if g = 1 then return self~answer(.true, claim, checks, .array~of('s*a + t*m = 1: certified coprime'), cert~primaryEvidence)
  return self~answer(.false, claim, checks, .array~of('gcd(a, m) =' g '> 1, certified: s*a + t*m =' g 'and' g 'divides both'), cert~primaryEvidence)

::method bezout class private
  use strict arg a, b
  numeric digits max(60, 2 * (length(a) + length(b)) + 10)   /* each method has its own NUMERIC DIGITS */
  r0 = a; r1 = b; s0 = 1; s1 = 0; t0 = 0; t1 = 1
  do while r1 \= 0
    qq = r0 % r1
    parse value r1 (r0 - qq * r1) with r0 r1
    parse value s1 (s0 - qq * s1) with s0 s1
    parse value t1 (t0 - qq * t1) with t0 t1
  end
  return r0 s0 t0

::method above class
  use strict arg v, bound
  numeric digits max(60, length(v) + length(bound) + 10)
  claim = .MathClaim~new('ABOVE', bound, .nil, 'v >' bound)
  checks = .directory~new; checks['v'] = v; checks['bound'] = bound
  if \datatype(v, 'N') then return self~undecided(claim, checks, 'v is not a number')
  vq = self~q(v)
  return self~answer(vq > self~q(bound), claim, checks, .array~of('decided in exact rationals'), vq~evidence)

::method forAll class
  use strict arg description
  claim = .MathClaim~new('FOR_ALL', .nil, .nil, description)
  return self~undecided(claim, .directory~new, 'a claim about every input is an argument about the code, not a value: no certificate route checks it (proofs of single values do not add up to it)')

/* one line for a store or a log */
::method text class
  use strict arg proof
  c = proof~claim
  out = proof~outcome proof~status c~kind
  if c~expected \== .nil then out = out 'expected=' || c~expected~string
  if c~parameter \== .nil then out = out 'parameter=' || c~parameter~string
  do note over proof~notes
    out = out '|' note
  end
  return out
