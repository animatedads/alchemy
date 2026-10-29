/* SLAM writes ooRexxUnit (ooTest) groups for standalone ooRexx routines, and a random-input group of
 * the same size for each, for comparison.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 * Args: alchemy repo root | pool file (lines: path-under-repo routine) | output directory | summary file
 * Summary lines: UNIT name path cases written predicted right wrong  |  SKIP name reason
 */
signal on syntax name onSyntax
parse arg repo '|' poolFile '|' outDir '|' summary
call SysMkDir outDir
parse source . . me
here = me~left(me~lastPos('/') - 1)
w = .SlamTestWriter~new
c = .SlamComposer~new
rr = .SlamRuleReader~new
call SysFileDelete summary
call SysFileDelete outDir || '/cases.txt'
k = 0
unitCache = .directory~new
textCache = .directory~new
do while lines(poolFile) > 0
  parse value linein(poolFile) with path name .
  if name = '' then iterate
  k += 1
  file = repo || '/' || path
  if \unitCache~hasIndex(file) then do
    text = charin(file, 1, chars(file)); call stream file, 'C', 'CLOSE'
    textCache[file] = text
    unitCache[file] = .SlamUnitSplitter~new~split(text)
  end
  lifted = liftOne(c, file, name, 'U' || k, unitCache[file], textCache[file])
  if lifted == .nil then do
    call lineout summary, 'SKIP' name 'not liftable'
    iterate
  end
  unit = unitOf(file, name, unitCache)
  nd = w~nondeterministic(unit~tokens)
  if nd \== '' then do
    call lineout summary, 'SKIP' name 'reads random numbers or the clock (' || nd || ')'
    iterate
  end
  rules = rr~rexxUnit(unit, file)
  kn = w~knobs(name, lifted~contract, rules)
  if kn == .nil then do
    call lineout summary, 'SKIP' name w~notes[name]
    iterate
  end
  kn['LITERALS'] = w~literalsOf(unit~tokens)
  kn['NUMBERS'] = w~numbersOf(unit~tokens)
  cases = w~cases(name, kn)
  pr = observe(w, file, name, cases, outDir, here)
  n = w~countWritten(cases)
  cls = 'SLAM_' || name~upper || '.testGroup'
  grp = w~ooTestGroup(cls, file, name, cases, 'SLAM-chosen cases for' name)
  if grp == .nil then do
    call lineout summary, 'SKIP' name 'no case gives the same outcome twice'
    iterate
  end
  call writeLines outDir || '/' || cls, grp
  rnd = w~randomCases(kn, n, 20261029)
  prr = observe(w, file, name, rnd, outDir, here)
  cls = 'RAND_' || name~upper || '.testGroup'
  grp = w~ooTestGroup(cls, file, name, rnd, 'Random cases (the comparison) for' name)
  if grp \== .nil then call writeLines outDir || '/' || cls, grp
  call dumpCases outDir || '/cases.txt', name, 'SLAM', cases
  call dumpCases outDir || '/cases.txt', name, 'RAND', rnd
  call lineout summary, 'UNIT' name path cases~items n w~countWritten(rnd) pr[1] pr[2]
  say left(name, 32) 'cases' cases~items ' written' n ' predicted right' pr[1] ' wrong' pr[2]
end
call stream summary, 'C', 'CLOSE'
exit 0

/* Run the cases in a child process, twice, each run under a time limit: a case still running at the
   limit is marked TIMEOUT and the run starts again after it (an input can send a loop on for ever). */
observe: procedure
  use arg w, file, name, cases, outDir, here
  cf = outDir || '/observe_cases.txt'
  call SysFileDelete cf
  do c over cases
    ln = c~args~items
    do a over c~args; ln = ln a~c2x || '.'; end
    call lineout cf, ln
  end
  call stream cf, 'C', 'CLOSE'
  first = runChild(file, name, cf, cases~items, outDir, here)
  second = runChild(file, name, cf, cases~items, outDir, here)
  return w~observeLines(cases, first, second)

runChild: procedure
  use arg file, name, cf, n, outDir, here
  out = outDir || '/observe_out.txt'
  lines = .array~new
  start = 1
  do while start <= n
    call SysFileDelete out
    address system 'timeout -s KILL 20 rexx "' || here || '/observe_runner.rex" "' || file || '|' || name || '|' || cf || '|' || start || '" >' out '2>/dev/null'
    last = start - 1
    do while lines(out) > 0
      ln = linein(out)
      if ln~word(1) \== '@@SLAM' then iterate
      lines~append(ln)
      last = ln~word(2)
    end
    call stream out, 'C', 'CLOSE'
    if last >= n then leave
    lines~append('@@SLAM' (last + 1) 'TIMEOUT')
    start = last + 2
  end
  return lines

liftOne: procedure
  use arg c, file, name, alias, units, text
  signal on syntax name liftFailed
  return c~lift(file, name, alias, units, text)
liftFailed:
  return .nil

unitOf: procedure
  use arg file, name, cache
  if \cache~hasIndex(file) then do
    text = charin(file, 1, chars(file)); call stream file, 'C', 'CLOSE'
    cache[file] = .SlamUnitSplitter~new~split(text)
  end
  do u over cache[file]
    if u~kind == 'ROUTINE' then if u~selector == name~upper then return u
  end
  return .nil

/* The cases as data, for the mutant runner: CASE unit suite kind expected-hex n arg-hex ... */
dumpCases: procedure
  use arg f, name, suite, cases
  do c over cases
    if c~kind == 'OTHER' then iterate
    ln = 'CASE' name suite c~kind c~expected~c2x || '.' c~args~items
    do a over c~args; ln = ln a~c2x || '.'; end
    call lineout f, ln
  end
  call stream f, 'C', 'CLOSE'
  return

writeLines: procedure
  use arg f, lines
  call SysFileDelete f
  do l over lines; call lineout f, l; end
  call stream f, 'C', 'CLOSE'
  return

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~traceback~makeArray~makeString('L', ' | ')
  exit 1

::requires 'SlamTestWriter.cls'
