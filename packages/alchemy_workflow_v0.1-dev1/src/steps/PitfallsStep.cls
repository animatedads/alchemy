/* PitfallsStep.cls - Alchemy Workflow v0.1-dev1 step "Pitfalls" (stage inspect): the ooRexx traps that have
 * already cost runs, asked of Boston Crab's RexxPitfallChecker (oorexx_slam_bostoncrab_v0.24,
 * tests/PitfallChecker.cls; Claude (Opus 5.5)), so the estate has one checker for them, not two.
 *
 * Architecture: Tom Dyer (the rules; "run the pitfall lint on changed ooRexx before any test run or
 * submission"). Code: Claude (Opus 5.5), 2026-11-19.
 *
 * Rules (the checker's own, with its wording; FAIL, because each one is code that does not do what it says):
 *   PF-P1  a string followed at once by "(": a call of the routine named by the string ('"'(x))
 *   PF-P2  a string followed at once by x or b that is not a real hex or binary string ('|'b)
 *   PF-P3  two names in one file that differ only in case: to ooRexx they are one name
 *   PF-P4  a "use arg" name that is also a loop control variable in the same routine: the loop overwrites it
 * The checker leaves comments, the inside of strings and ::resource text alone. Where it knows the fix
 * (P1, P2: put || in at a column), the finding says where.
 *
 * Needs oorexx_slam_bostoncrab_v0.24/tests on REXX_PATH (bin/workflow_env.sh); without it the step is
 * listed as unavailable and the others run.
 */
::requires 'AlchemyWorkflow.cls'
::requires 'PitfallChecker.cls'

::class PitfallsStep public subclass WorkflowStep
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-19'

::method id
  return 'Pitfalls'

::method stage
  return 'inspect'

::method describe
  return 'ask Boston Crab''s RexxPitfallChecker ' || .RexxPitfallChecker~module_version || ' for P1 to P4 in every ooRexx file'

::method skipReason
  use strict arg ctx
  if ctx~sourceFiles~items = 0 then return 'no ooRexx files'
  return ''

::method intends
  use strict arg ctx
  return 'read' ctx~sourceFiles~items 'ooRexx file(s) with RexxPitfallChecker' .RexxPitfallChecker~module_version

::method run
  use strict arg ctx, res
  checker = .RexxPitfallChecker~new
  do rel over ctx~sourceFiles
    src = ctx~source(rel)
    do p over checker~check(src~raw)
      res~add(self~finding('PF-' || p~rule, 'FAIL', rel, p~line, self~evidence(p), self~fixFor(p)))
    end
  end
  res~note('RexxPitfallChecker' .RexxPitfallChecker~module_version '(' || .RexxPitfallChecker~module_lastChanged || ')')

::method evidence
  use strict arg p
  select
    when p~rule == 'P1' then return 'a string followed by "(" is a routine call, column' p~column || ':' p~text~strip
    when p~rule == 'P2' then return 'a string followed by' p~after 'is a hex or binary literal, column' p~column || ':' p~text~strip
    when p~rule == 'P3' then return '"' || p~names[1] || '" and "' || p~names[2] || '" differ only in case, and are one name to ooRexx'
    otherwise return 'the loop variable "' || p~names[1] || '" overwrites a use arg name of this routine:' p~text~strip
  end

::method fixFor
  use strict arg p
  select
    when p~fixAt > 0 then return 'put || in at column' p~fixAt '(the string and what follows it are two things)'
    when p~rule == 'P3' then return 'spell the name one way throughout the file'
    when p~rule == 'P4' then return 'give the loop variable a name of its own'
    otherwise return 'join the string and what follows it with ||'
  end
