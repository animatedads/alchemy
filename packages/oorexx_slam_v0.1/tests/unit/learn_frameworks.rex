/* What SLAM learns about the two test frameworks before it writes a test for either.
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 *
 * 1. From ooTest's own 314 test groups, read into a SLAM store: which assertions they use, and where the
 *    literal goes. In a shape a literal is N or S; when the first argument of assertEquals / assertSame
 *    is a literal and the second is not, the expected value comes first.
 * 2. From each framework itself: SLAM writes one assertion that must fail, with FIRST in the first value
 *    and SECOND in the second, runs it, and reads which one the framework calls expected.
 *
 * Args: store of ooTest's groups | ooTest root | JUnit classpath | work directory | summary file
 * Summary lines: ASSERT name count | LITERAL_FIRST n | LITERAL_SECOND n | OOTEST_EXPECTED arg | JUNIT_EXPECTED arg
 */
signal on syntax name onSyntax
parse arg db '|' ootest '|' junitCp '|' work '|' summary
call SysFileDelete summary
call SysMkDir work
st = .SlamStore~new(db)
counts = .directory~new
first = 0; second = 0
rows = st~q("SELECT s.canon AS c, count(*) AS n FROM instance i JOIN shape s ON s.id = i.shape_id WHERE s.canon LIKE '%~ assert%' OR s.canon LIKE '%~ expect%' GROUP BY s.canon")~rows
do r over rows
  c = r['C']
  n = r['N']
  do forever
    at = c~caselessPos('~ assert')
    at2 = c~caselessPos('~ expect')
    if at == 0 | (at2 > 0 & at2 < at) then at = at2
    if at == 0 then leave
    c = c~substr(at + 2)
    parse var c nm ' ' c
    nm = nm~lower
    if counts~hasIndex(nm) then counts[nm] = counts[nm] + n
    else counts[nm] = n
    if wordpos(nm, 'assertequals assertsame') > 0 then do
      args = argsOf(c)
      if args~items >= 2 then do
        l1 = literal(args[1])
        l2 = literal(args[2])
        if l1 then if \l2 then first += n
        if l2 then if \l1 then second += n
      end
    end
  end
end
st~close
do nm over counts~allIndexes~sort
  call lineout summary, 'ASSERT' nm counts[nm]
end
call lineout summary, 'LITERAL_FIRST' first
call lineout summary, 'LITERAL_SECOND' second

/* 2. ask each framework */
g = work || '/PROBE.testGroup'
call SysFileDelete g
do l over .array~of('#!/usr/bin/env rexx', '/* SLAM asks ooTest which value it calls expected */', -
    'parse source . . sourceFile', 'group = .TestGroup~new(sourceFile)', 'group~add(.PROBE.testGroup)', -
    'if group~isAutomatedTest then return group', 'testRun = group~suite~execute', 'testRun~print', 'return testRun', -
    "::requires 'ooTest.frm'", "::class 'PROBE.testGroup' public subclass ooTestCase", '::method test_order', -
    "  self~assertSame('FIRST', 'SECOND', 'probe')")
  call lineout g, l
end
call stream g, 'C', 'CLOSE'
out = work || '/probe_ootest.txt'
address system 'cd "' || work || '" && REXX_PATH="' || ootest || ':' || ootest || '/framework:$REXX_PATH" rexx PROBE.testGroup >' out '2>&1'
call lineout summary, 'OOTEST_EXPECTED' whichExpected(out, 'Expected:')
j = work || '/ProbeTest.java'
call SysFileDelete j
do l over .array~of('import org.junit.Test;', 'import static org.junit.Assert.*;', 'public class ProbeTest {', -
    '  @Test public void order() { assertEquals("probe", "FIRST", "SECOND"); }', '}')
  call lineout j, l
end
call stream j, 'C', 'CLOSE'
out = work || '/probe_junit.txt'
address system 'cd "' || work || '" && javac -nowarn -cp "' || junitCp || '" ProbeTest.java 2>/dev/null && java -cp ".:' || junitCp || '" org.junit.runner.JUnitCore ProbeTest >' out '2>/dev/null'
call lineout summary, 'JUNIT_EXPECTED' whichExpected(out, 'expected:')
call stream summary, 'C', 'CLOSE'
exit 0

/* Which argument the framework printed as expected: FIRST or SECOND, or ? */
whichExpected: procedure
  use arg f, label
  do while lines(f) > 0
    ln = linein(f)
    at = ln~pos(label)
    if at == 0 then iterate
    rest = ln~substr(at + label~length, 12)
    call stream f, 'C', 'CLOSE'
    if rest~pos('FIRST') > 0 then return 'FIRST'
    if rest~pos('SECOND') > 0 then return 'SECOND'
    return '?'
  end
  call stream f, 'C', 'CLOSE'
  return '?'

/* The top-level arguments of a call written as a shape: "( a , b ) ..." */
argsOf: procedure
  use arg c
  out = .array~new
  if c~word(1) \== '(' then return out
  depth = 0
  cur = ''
  do w over c~makeArray(' ')
    if w == '(' then do
      depth += 1
      if depth == 1 then iterate
    end
    if w == ')' then do
      depth -= 1
      if depth == 0 then do
        out~append(cur~strip)
        return out
      end
    end
    if depth == 1 then if w == ',' then do
      out~append(cur~strip)
      cur = ''
      iterate
    end
    cur = cur w
  end
  return out

literal: procedure
  use arg a
  return a == 'N' | a == 'S' | a == '- N'

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D') condition('O')~traceback~makeArray~makeString('L', ' | ')
  exit 1

::requires 'SlamStore.cls'
