/* SLAM writes ooRexxUnit (ooTest) groups for standalone ooRexx routines, and a random-input group of
 * the same size for each, for comparison.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 * Args: alchemy repo root | pool file (lines: path-under-repo routine [class]) | output directory | summary file
 *   A line with a class names a method of that class: one that uses nothing of its object (no SELF,
 *   SUPER or EXPOSE), lifted and run alone like a routine.
 * Summary lines: UNIT name path cases written predicted right wrong  |  SKIP name reason
 *   name is ROUTINE, or CLASS~METHOD for a method
 */
signal on syntax name onSyntax
parse arg repo '|' poolFile '|' outDir '|' summary
address system 'mkdir -p "' || outDir || '"'
parse source . . me
here = me~left(me~lastPos('/') - 1)
w = .SlamTestWriter~new
x = .SlamContractExtractor~new
rr = .SlamRuleReader~new
call SysFileDelete summary
call SysFileDelete outDir || '/cases.txt'
k = 0
unitCache = .directory~new
textCache = .directory~new
do while lines(poolFile) > 0
  parse value linein(poolFile) with path rname owner .
  if rname = '' then iterate
  k += 1
  name = rname
  if owner \== '' then name = owner || '~' || rname
  file = repo || '/' || path
  if \unitCache~hasIndex(file) then do
    text = charin(file, 1, chars(file)); call stream file, 'C', 'CLOSE'
    textCache[file] = text~makeArray('0a'x)
    unitCache[file] = .SlamUnitSplitter~new~split(text)
  end
  unit = unitOf(file, rname, owner, unitCache)
  if unit == .nil then do
    call lineout summary, 'SKIP' name 'not found'
    iterate
  end
  contract = x~extract(unit)
  if \contract~standalone then do
    call lineout summary, 'SKIP' name 'not standalone'
    iterate
  end
  if owner \== '' then if \slamLiftableMethod(unit, textCache[file][unit~line]) then do
    call lineout summary, 'SKIP' name 'uses its object (SELF, SUPER or EXPOSE)'
    iterate
  end
  if slamLiftFile(file, rname, owner) == .nil then do
    call lineout summary, 'SKIP' name 'not liftable'
    iterate
  end
  nd = w~nondeterministic(unit~tokens)
  if nd \== '' then do
    call lineout summary, 'SKIP' name 'reads random numbers or the clock (' || nd || ')'
    iterate
  end
  rules = rr~rexxUnit(unit, file)
  kn = w~knobs(name, contract, rules)
  if kn == .nil then do
    call lineout summary, 'SKIP' name w~notes[name]
    iterate
  end
  kn['LITERALS'] = w~literalsOf(unit~tokens)
  kn['NUMBERS'] = w~numbersOf(unit~tokens)
  cases = w~cases(name, kn)
  pr = observe(w, file, name, cases, outDir, here)
  n = w~countWritten(cases)
  cls = slamGroupName('SLAM', name)
  grp = w~ooTestGroup(cls, file, rname, cases, 'SLAM-chosen cases for' name, owner)
  if grp == .nil then do
    call lineout summary, 'SKIP' name 'no case gives the same outcome twice'
    iterate
  end
  call writeLines outDir || '/' || cls, grp
  rnd = w~randomCases(kn, n, 20261029)
  prr = observe(w, file, name, rnd, outDir, here)
  cls = slamGroupName('RAND', name)
  grp = w~ooTestGroup(cls, file, rname, rnd, 'Random cases (the comparison) for' name, owner)
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
    do a over c~args
      if a == w~OMITTED then ln = ln '-'
      else ln = ln a~c2x || '.'
    end
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

unitOf: procedure
  use arg file, name, owner, cache
  do u over cache[file]
    if owner == '' then do
      if u~kind == 'ROUTINE' then if u~selector == name~upper then return u
    end
    else if u~kind == 'METHOD' then if u~selector == name~upper then if u~owner~upper == owner~upper then return u
  end
  return .nil

/* The cases as data, for the mutant runner: CASE unit suite kind expected-hex n arg-hex ... */
dumpCases: procedure
  use arg f, name, suite, cases
  do c over cases
    if c~kind == 'OTHER' then iterate
    e = c~expected
    if c~kind == 'ERROR' then e = e || '0a'x || c~message
    ln = 'CASE' name suite c~kind e~c2x || '.' c~args~items
    do a over c~args
      if a == .SlamTestWriter~new~OMITTED then ln = ln '-'
      else ln = ln a~c2x || '.'
    end
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
::requires 'SlamLift.cls'
