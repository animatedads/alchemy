/* The door code that uses FDSqrt, before and after the change (ChatGPT's fourth letter to SLAM).
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.  Door code: ChatGPT.
 * Args: scratch dir | phase (BEFORE, AFTER or CHECK) | store path | label
 * REXX_PATH picks which FDDoorMicroMotion.cls is loaded (its src first).
 *
 * The callers, by their place in FDDoorMicroMotion.cls (v0.2-dev8):
 *   FDNoiseModel~globalSigma, ~doorSigma          standard deviation of quiet frame steps
 *   FDNightDoorGeometryModel~photometricStats     standard deviation of sampled pixel values
 *   gmag=FDSqrt((gdx*gdx)+(gdy*gdy))               gradient size, inline in FDDoorMicroMotionWorker~run;
 *                                                  gmag is then fed to FDNoiseModel~add (the chain)
 *   doorAppearanceContrast is private, and is the same pixel standard deviation as photometricStats.
 *
 * Each result is checked against the root anchor (SlamMaths~sqrtOf, 30 digits) of the same variance the
 * door code holds, so the test measures the root, not the rounding of the running sums.
 * BEFORE: small data must be true; large data is run and kept as it is.
 * AFTER:  small data must give the same output as BEFORE; large data must be true.
 * CHECK:  every result must be true.
 */
signal on syntax name onSyntax
parse arg work '|' phase '|' db '|' label
phase = phase~upper
checks = 0
store = .SlamStore~new(db)
node = store~codeNode('FDSqrt callers' label)
say '==' phase label
store~begin
falseLarge = 0

say '-- standard deviation: FDNoiseModel (quiet frame steps)'
do kind over .array~of('small', 'large')
  n = .FDNoiseModel~new
  do i = 1 to 240
    if kind == 'small' then n~add(((i * 37) // 11) / 10, ((i * 53) // 7) / 20)       /* pixel steps */
    else n~add(20000 + (i * 7919) // 30001, 5000 + (i * 104729) // 12007)              /* large steps */
  end
  call keep kind, 'noise global sigma', n~globalSigma, n~globalM2 / (n~count - 1)
  call keep kind, 'noise door sigma', n~doorSigma, n~doorM2 / (n~count - 1)
end

say '-- standard deviation: FDNightDoorGeometryModel~photometricStats (pixel values)'
g = .FDNightDoorGeometryModel~new(.nil)
w = 320; h = 200
kinds = .array~of('flat', 'busy')
if \g~hasMethod('PHOTOMETRICSTATS') then do
  say '      (this version has no photometricStats; its pixel standard deviation is doorAppearanceContrast, private)'
  kinds = .array~new
end
do kind over kinds
  plane = ''
  do y = 0 to h - 1
    row = ''
    do x = 0 to w - 1
      if kind == 'flat' then v = 100 + (x + y) // 5
      else v = (x * 7 + y * 13) // 256
      row = row || d2c(v)
    end
    plane = plane || row
  end
  st = g~photometricStats(plane, w, h, w)
  /* the variance photometricStats holds, from the same samples, in 30 digits */
  numeric digits 30
  stepX = w % 80; if stepX < 4 then stepX = 4
  stepY = h % 50; if stepY < 4 then stepY = 4
  cnt = 0; sum = 0; sq = 0
  do y = trunc(h * 0.08) to trunc(h * 0.92) by stepY
    do x = trunc(w * 0.05) to trunc(w * 0.95) by stepX
      v = c2d(plane~substr(y * w + 1 + x, 1)); cnt += 1; sum += v; sq += v * v
    end
  end
  var = (sq - sum * sum / cnt) / (cnt - 1)
  numeric digits 9
  call keep 'small', 'photometric sigma' kind, st['SIGMA'], var, 0.000001
end

say '-- gradient size: gmag=FDSqrt((gdx*gdx)+(gdy*gdy)), then noise~add(gmag,dmag)'
pairs = .directory~new
pairs['small'] = .array~of(.array~of(3, 4), .array~of(0.5, 1.2), .array~of(-1.122, 0.4), .array~of(0, 0.75), .array~of(12, -35))
pairs['large'] = .array~of(.array~of(6000, 8000), .array~of(-2400, 7000), .array~of(300000, 400000), .array~of(12345, 6789))
do kind over .array~of('small', 'large')
  chain = .FDNoiseModel~new
  do p over pairs[kind]
    gdx = p[1]; gdy = p[2]
    gmag = FDSqrt((gdx * gdx) + (gdy * gdy))
    call keep kind, 'gradient size' gdx || ',' || gdy, gmag, (gdx * gdx) + (gdy * gdy)
    chain~add(gmag, 0)
  end
  call keep kind, 'noise sigma of gradient sizes', chain~globalSigma, chain~globalM2 / (chain~count - 1)
end

if phase == 'BEFORE' then call check falseLarge > 0, falseLarge 'large results are false before the change'
store~commit
store~close
say 'FDSQRT DOOR' phase 'TEST: PASS (' || checks || ' checks)'
exit 0

/* keep one result; check it by phase.  want is the variance (or square) the door code holds. */
keep:
  use arg kKind, kWhat, kGot, kSquare, kTol
  if arg(5, 'O') then kTol = 0.00000001
  kAnchor = .SlamMaths~sqrtOf(kSquare)
  kOk = closeTo(kGot, kAnchor, kTol)
  store~lesson(node, node, kOk, phase, kKind label, kWhat || ': out=' || kGot 'anchor=' || kAnchor)
  kLine = kWhat '->' kGot '(anchor' kAnchor~string~left(20) || ')'
  select
    when phase == 'BEFORE' & kKind == 'large' then do
      say '      large' kLine kOk
      if \kOk then falseLarge += 1
    end
    when phase == 'BEFORE' then call check kOk, kKind kLine
    when phase == 'AFTER' & kKind \== 'large' then do
      kBefore = store~scalar("SELECT data AS d FROM lesson WHERE predicted = 'BEFORE' AND reason = ? AND data LIKE ? ORDER BY id LIMIT 1", store~binds(kKind label, kWhat || ': out=%'))
      parse var kBefore . 'out=' kB .
      call check kB == kGot & kOk, kKind kLine 'same as before'
    end
    otherwise call check kOk, kKind kLine
  end
  return

closeTo: procedure
  use arg got, want, tol
  numeric digits 30
  if \datatype(got, 'N') then return .false
  if want = 0 then return got = 0
  return abs(got - want) / want <= tol

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

::requires 'FDDoorMicroMotion.cls'
::requires 'SlamStore.cls'
::requires 'SlamGround.cls'
