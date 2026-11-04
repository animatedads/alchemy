/* SLAM writes unit tests: ooRexxUnit (ooTest) groups for ooRexx, JUnit 4 classes for NetRexx on the JVM.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 * Args: work directory (as tests/unit/qualify.sh left it)
 */
signal on syntax name onSyntax
parse arg work
checks = 0
call check work \= '', 'arguments'
u = work || '/unit'

say '== 1. what SLAM learns before writing a test'
l = kv(u || '/learn.txt')
say '      assertSame' l['ASSERT assertsame'] ' assertEquals' l['ASSERT assertequals'] ' expectSyntax' l['ASSERT expectsyntax'] ' assertTrue' l['ASSERT asserttrue']
call check l['ASSERT assertsame'] > l['ASSERT assertequals'] & l['ASSERT assertsame'] > l['ASSERT asserttrue'], 'ooTest''s own 314 groups compare with assertSame (==) most: SLAM writes assertSame'
call check l['ASSERT expectsyntax'] > 1000, 'expectSyntax is how they expect an error (' || l['ASSERT expectsyntax'] 'times): SLAM writes it for a raise syntax'
call check l['OOTEST_EXPECTED'] == 'FIRST', 'asked with a failing assertSame(''FIRST'', ''SECOND''), ooTest calls the first value expected'
if l['JUNIT_EXPECTED'] \== '?' then call check l['JUNIT_EXPECTED'] == 'FIRST', 'asked with a failing assertEquals("probe", "FIRST", "SECOND"), JUnit calls the value after the message expected'
say '      a literal first' l['LITERAL_FIRST'] ', a literal second' l['LITERAL_SECOND']
call check l['LITERAL_SECOND'] > 1000, 'ooTest''s own groups put the literal second' l['LITERAL_SECOND'] 'times (first' l['LITERAL_FIRST'] || '): there, expected and actual are reported the wrong way round'

say '== 2. ooTest groups SLAM wrote for standalone ooRexx routines'
units = 0; cases = 0; written = 0; rnd = 0; right = 0; wrong = 0
do while lines(u || '/summary.txt') > 0
  parse value linein(u || '/summary.txt') with tag name path c w r pr pw .
  if tag \== 'UNIT' then iterate
  units += 1; cases += c; written += w; rnd += r; right += pr; wrong += pw
end
say '      units' units ' cases' cases ' written' written ' random' rnd ' predicted right' right ' wrong' wrong
call check units = 56, '56 of the 71 standalone routines get a group (the other 15 take a collection or an object SLAM cannot make)'
call check written > 600 & rnd = written, written 'cases written; each routine also gets a random group of the same size'
call check right > 20 & wrong = 0, 'SLAM predicted' right 'outcomes before running (a guard''s constant return or raise syntax), and none was wrong'
kinds = .directory~new
call SysFileTree u || '/groups/SLAM_*.testGroup', 'g.', 'FO'
do i = 1 to g.0
  t = charin(g.i, 1, chars(g.i)); call stream g.i, 'C', 'CLOSE'
  do w over .array~of('_omit', '_fraction', 'self~errorOf(')
    if t~pos(w) > 0 then kinds[w] = .true
  end
end
call check kinds~hasIndex('_omit') & kinds~hasIndex('_fraction') & kinds~hasIndex('self~errorOf('), 'the cases the rx2cpp lane asked for are written: an argument left out, a number that is not whole, and an error read from its condition (code and message)'
parse value linein(u || '/originals.txt') with . ok bad .
call check ok = 2 * units & bad = 0, 'every group, SLAM''s and random, passes under the real ooTest framework on the code as it is (' || ok || ')'

say '== 3. how good: mutants (one operator or number changed) against both suites'
s = kv(u || '/score.txt')
n = s['MUTANTS']
say '      mutants' n ' SLAM catches' s['KILLED SLAM'] '(' || pct(s['KILLED SLAM'], n) || ')  random catches' s['KILLED RAND'] '(' || pct(s['KILLED RAND'], n) || ')  only SLAM' s['ONLY SLAM'] ' only random' s['ONLY RAND']
call check n > 700, n 'mutants of the 56 routines'
call check s['KILLED SLAM'] > s['KILLED RAND'], 'SLAM''s cases catch more mutants than random cases of the same number'
call check s['ONLY SLAM'] > 2 * s['ONLY RAND'], 'mutants only SLAM catches (' || s['ONLY SLAM'] || ') outnumber those only random catches (' || s['ONLY RAND'] || ') more than two to one'
call check s['UNIT_BETTER SLAM'] > s['UNIT_BETTER RAND'], 'SLAM catches more in' s['UNIT_BETTER SLAM'] 'routines, random in' s['UNIT_BETTER RAND']
parse value linein(u || '/agree.txt') with . agree . differ .
call check agree >= 150 & differ = 0, 'the fast runner (all cases in one process) and the real ooTest framework agree on every sampled mutant (' || agree || ')'

say '== 4. what no test reaches (the rx2cpp lane''s ask), on a fixture'
r = .array~new
do while lines(u || '/untested.txt') > 0; r~append(linein(u || '/untested.txt')); end
txt = r~makeString('L', '0a'x)
call check txt~pos('FILE native/dropped.cpp') > 0 & txt~pos('FILE src/Orphan.cls') > 0, 'files no test names, directly or through what it names: dropped.cpp (no script builds it), Orphan.cls'
call check txt~pos('UNIT src/Shapes.cls UNUSED') > 0 & txt~pos('UNIT native/helper.cpp helperNever') > 0, 'units no reached code calls: unused, helperNever (named only in a comment, which does not count)'
call check txt~pos('PERIMETER') == 0 & txt~pos('helperTwice') == 0, 'perimeter (called by area, which the test calls) and helperTwice (called by helperUser) are reached'
call check txt~pos('helperByPointer') == 0, 'helperByPointer is reached: installed by its address (hook() = &helperByPointer), as rx2cpp installs its hooks (the rx2cpp lane''s report)'

j = work || '/junit'
if stream(j || '/summary.txt', 'C', 'QUERY EXISTS') \== '' then do
  say '== 5. JUnit 4 classes SLAM wrote for NetRexx methods (compiled by NetRexxC)'
  units = 0; written = 0
  do while lines(j || '/summary.txt') > 0
    parse value linein(j || '/summary.txt') with tag . . . . . . c w .
    if tag \== 'UNIT' then iterate
    units += 1; written += w
  end
  o = .array~new
  do while lines(j || '/originals.txt') > 0; o~append(linein(j || '/originals.txt')); end
  say '      methods' units ' cases written' written '  ' o~makeString('L', ' | ')
  call check units >= 15, units 'NetRexx methods get a JUnit class (signatures read from the compiled classes with javap)'
  call check o[1]~word(2) == 'OK' & o[2]~word(2) == 'OK', 'SLAM''s classes and the random ones pass under JUnit on the code as it is'
  s = kv(j || '/score.txt')
  n = s['MUTANTS']
  say '      mutants' n ' SLAM catches' s['KILLED SLAM'] '(' || pct(s['KILLED SLAM'], n) || ')  random catches' s['KILLED RAND'] '(' || pct(s['KILLED RAND'], n) || ')  only SLAM' s['ONLY SLAM'] ' only random' s['ONLY RAND']
  call check n > 50, n 'mutants of the NetRexx methods, each compiled by NetRexxC'
  call check s['KILLED SLAM'] >= s['KILLED RAND'], 'SLAM''s JUnit cases catch at least as many as random ones'
end
else say 'SKIP JUnit: set JUNIT_CP and NETREXX_HOME'

say 'UNIT TEST: PASS (' || checks || ' checks)'
exit 0

kv: procedure
  use arg f
  d = .directory~new
  do while lines(f) > 0
    ln = linein(f)
    v = ln~word(ln~words)
    k = ln~subWord(1, ln~words - 1)
    d[k] = v
  end
  call stream f, 'C', 'CLOSE'
  return d

pct: procedure
  use arg a, b
  if b = 0 then return '0%'
  return format(100 * a / b, , 1) || '%'

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
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~traceback~makeArray~makeString('L', ' | ')
  exit 1
