/* ShellJobs.cls - plans and watches the LLM registers, then is told about
   Architecture: Tom Dyer (24 November 2026): the LLM registers a multi-step
   plan object; each step carries its checks and its pass/fail criteria; the
   plan runs without the LLM watching it, and when it stops the LLM gets a
   message with the job, the stage reached and that stage's result: the
   error point and a trace excerpt, not the whole build output. Trigger
   events (disk space below n, a log file appearing) work the same way.
   Coding: Claude (Opus 5.5).

   plan = jobs~plan('build hello')
   s = plan~step('unzip');   s~does(ws, 'run', .Array~of('unzip', '-o', 'hello.zip')); s~passIf('exitIs', 0)
   s = plan~step('compile'); s~does(ws, 'run', .Array~of('make', '-C', 'hello'));     s~passIf('exitIs', 0)
   s = plan~step('check');   s~passIf('fileExists', 'hello/hello')
   jobs~submit(plan)        -- protected: the policy decides; the plan runs on its own thread

   Every step's action runs under the security manager as principal llm,
   so ws~run is authorised per program and path (policy method run:make).
   Programs run through oorexx_process (argv, no shell, with a timeout). */
::requires 'ShellNative.cls'
::requires 'ShellObject.cls'
::requires 'ShellLog.cls'
::requires 'ShellSecurity.cls'
::requires 'Process.cls'
::requires 'FileSystem.cls'

/* ------------------------------------------------------------ job board -- */
::class JobBoard public inherit ShellObject
::constant SHELL_HELP "jobs~find(name) gives the most recent submitted job with that name (to amend an earlier plan). jobs~plan(name) makes a Plan. jobs~watch(kind, ...) makes a Watch: kinds diskFreeBelow(path, bytes) and fileAppears(dir, pattern). jobs~submit(planOrWatch) starts it on its own thread and returns at once; you are sent a message when it stops or fires, with the stage reached and the error point. Do not wait for it."

::method init
  expose owner list inbox
  use strict arg owner
  list = .Array~new
  inbox = .ShellInbox~current

::method owner
  expose owner
  return owner~kind
::method plan
  expose owner
  use strict arg name
  return .Plan~new(name, owner)
::method watch
  expose owner
  use strict arg kind, a1 = '', a2 = ''
  return .Watch~new(kind, a1, a2, owner)

::method submit protected
  expose list
  use strict arg job
  if \(job~isA(.Plan) | job~isA(.Watch)) then raise syntax 93.900 array ('submit takes a Plan or a Watch')
  list~append(job)
  -- a job submitted by a follow-up proposal remembers the job it follows
  if .local~hasIndex('NEWSHELL.ORIGIN') then job~setOrigin(.local['NEWSHELL.ORIGIN'])
  .NewshellLog~event('JOB SUBMITTED' job~class~id job~name)
  job~launch
  return job

::method jobs unguarded
  expose list
  return .ShellCollection~new(list~copy)
/* A job restored from a job store: listed and findable, never launched. */
::method adopt protected
  expose list
  use strict arg job
  list~append(job)
  return job

/* The most recent submitted job with this name, or .nil. */
::method find unguarded
  expose list
  use strict arg jobName
  do i = list~items to 1 by -1
    if list[i]~name~caselessEquals(jobName) then return list[i]
  end
  return .nil
::method running unguarded
  expose list
  n = 0
  do j over list; if \j~settled then n += 1; end
  return n
::method fields
  return .Array~of('owner', 'running')
::method relatedSamples
  expose owner
  p = .Plan~new('sample', owner)
  return .Array~of(.Array~of('jobs~plan(name) returns a Plan', p), -
                   .Array~of('plan~step(name) returns a PlanStep', p~step('sample')), -
                   .Array~of('jobs~watch(kind, ...) returns a Watch', .Watch~new('fileAppears', '/tmp', '*.log', owner)))

/* ----------------------------------------------------------------- plan -- */
::class Plan public inherit ShellObject
::constant SHELL_HELP "plan~step(name) adds a step and returns it. Steps run in order. A step passes when all its checks pass; a step with no checks passes when its action returns. A step whose program is killed DIED, and the plan stops. plan~atError is the StepOutcome where it stopped. plan~notify('always') also reports a passed plan, with what each step found (for a review plan). plan~amend(newName) gives a new plan with copies of the steps; then insertStep(position, name) adds a step before position and returns it (later steps move down one), removeStep(position) drops one, stepNamed(name) or stepAt(position) gives one; prefer stepNamed after an insert."

::method init
  expose name owner steps outcomes state stage startedAt seconds atError diagnosis decisions settled
  use strict arg name, owner
  steps = .Array~new; outcomes = .Array~new
  state = 'REGISTERED'; stage = ''; startedAt = ''; seconds = 0
  atError = .nil; diagnosis = ''; decisions = .nil; settled = .false

::method name unguarded
  expose name
  return name
::method state unguarded
  expose state
  return state
::method stage unguarded
  expose stage
  return stage
::method seconds unguarded
  expose seconds
  return seconds~format(, 2)
::method stepCount unguarded
  expose steps
  return steps~items
::method atError unguarded
  expose atError
  return atError
::method outcomes unguarded
  expose outcomes
  return .ShellCollection~new(outcomes~copy)
::method diagnosis unguarded
  expose diagnosis
  return diagnosis
/* Settled: the state is final, the owner has been told, the inbox posted. */
::method settled unguarded
  expose settled
  return settled
::method setDiagnosis unguarded
  expose diagnosis
  use strict arg diagnosis
::method decisions unguarded
  expose decisions
  if decisions == .nil then return .ShellCollection~new
  return decisions~decisions
::method identity
  expose name
  return 'plan:'name':'self~identityHash
::method fields
  return .Array~of('name', 'state', 'stage', 'stepCount', 'seconds')

/* notify: 'fail' (default) tells the LLM only when the plan does not pass;
   'always' also tells it when it passes, with what each step found (use it
   for a review plan). */
::method notify unguarded
  expose notifyMode
  use strict arg mode = .nil
  if mode == .nil then do; if var('notifyMode') = 0 then return 'fail'; return notifyMode; end
  if wordpos(mode~lower, 'fail always') = 0 then raise syntax 93.900 array ('notify is fail or always, not' mode)
  notifyMode = mode~lower
  return self

/* A new REGISTERED plan with copies of this plan's steps, to change and submit. */
::method amend unguarded
  expose steps owner
  use strict arg newName
  p = .Plan~new(newName, owner)
  do s over steps; p~adoptStep(s~copyStep); end
  return p

::method adoptStep
  expose steps state
  use strict arg s
  if state \== 'REGISTERED' then raise syntax 93.900 array ('Plan' state'; steps can only be changed before submit')
  steps~append(s)
  self~renumber
  return s

/* Insert a new step before position at (1 = first) and return it. */
::method insertStep
  expose steps state
  use strict arg at, stepName
  if state \== 'REGISTERED' then raise syntax 93.900 array ('Plan' state'; steps can only be changed before submit')
  if \at~datatype('W') | at < 1 | at > steps~items + 1 then raise syntax 93.900 array ('insertStep position must be 1 to' steps~items + 1)
  s = .PlanStep~new(at, stepName)
  if at = 1 then steps~insert(s, .nil)          -- Array~insert puts it after the index; .nil = first
  else steps~insert(s, at - 1)
  self~renumber
  return s

::method removeStep
  expose steps state
  use strict arg at
  if state \== 'REGISTERED' then raise syntax 93.900 array ('Plan' state'; steps can only be changed before submit')
  if \at~datatype('W') | at < 1 | at > steps~items then raise syntax 93.900 array ('removeStep position must be 1 to' steps~items)
  steps~delete(at)
  self~renumber
  return self

::method stepAt
  expose steps
  use strict arg at
  return steps[at]

/* The step with this name, or .nil: positions shift after insertStep. */
::method stepNamed
  expose steps
  use strict arg stepName
  do s over steps; if s~name~caselessEquals(stepName) then return s; end
  return .nil

::method steps unguarded
  expose steps
  return .ShellCollection~new(steps~copy)

::method renumber private
  expose steps
  do i = 1 to steps~items; steps[i]~setIndex(i); end

::method followUp unguarded
  expose followUp
  if var('followUp') = 0 then return .nil
  return followUp
::method setFollowUp unguarded
  expose followUp
  use strict arg followUp
::method origin unguarded
  expose origin
  if var('origin') = 0 then return .nil
  return origin
::method setOrigin unguarded
  expose origin
  use strict arg origin

::method step
  expose steps state
  use strict arg stepName
  if state \== 'REGISTERED' then raise syntax 93.900 array ('Plan' state'; steps can only be added before submit')
  s = .PlanStep~new(steps~items + 1, stepName)
  steps~append(s)
  return s

::method launch protected
  expose state steps
  if state \== 'REGISTERED' then raise syntax 93.900 array ('Plan already' state)
  if steps~items = 0 then raise syntax 93.900 array ('Plan has no steps')
  state = 'RUNNING'
  .Message~new(self, 'EXECUTE')~start

::method execute protected unguarded     -- runs for the whole plan: must not hold the object's lock
  expose name owner steps outcomes state stage startedAt seconds atError decisions settled
  startedAt = .DateTime~new~isoDate
  t0 = time('E')
  -- the steps run as whoever owns the plan: llm for an Llm, codex for the agent
  principal = 'llm'
  if owner \== .nil, owner~hasMethod('PRINCIPAL') then principal = owner~principal
  decisions = .ShellSecurityManager~new(principal)
  runner = .Routine~new('planStep', .Array~of('use arg target, msg, args', 'return target~sendWith(msg, args)'), .context~package)
  runner~setSecurityManager(decisions)
  .NewshellLog~event('PLAN' name 'start,' steps~items 'step(s)')
  final = 'PASSED'
  do s over steps
    stage = s~index'/'steps~items s~name
    .NewshellLog~event('PLAN' name 'step' stage)
    out = s~perform(runner)
    outcomes~append(out)
    .NewshellLog~event('PLAN' name 'step' stage out~state out~reason)
    if out~state == 'DIED' then do; atError = out; final = 'DIED'; leave; end
    if out~state == 'FAIL' then do
      -- continue only means the later steps still run: the plan has still failed
      if atError == .nil then atError = out
      final = 'FAILED'
      if s~onFail == 'continue' then iterate
      leave
    end
  end
  seconds = time('E') - t0
  state = final
  .NewshellLog~event('PLAN' name state 'at' stage 'in' seconds~format(, 2)'s')
  call tellOwner owner, self
  .ShellInbox~current~post('plan', name, state 'at step' stage, self)
  settled = .true

/* A plan read back from a job store: final state, stage and report as
   recorded, steps rebuilt so it can be amended. Never launched again. */
::method restoreState protected
  expose state stage seconds storedReport settled
  use strict arg state, stage, seconds, storedReport
  settled = .true
  return self

/* The message the LLM is sent: job, stage reached, result, error point. */
::method report unguarded
  expose name steps outcomes state stage atError storedReport
  if var('storedReport') then return storedReport
  out = .MutableBuffer~new
  out~append(jobHistory(self))
  out~append('Job: plan "'name'" (' || steps~items 'steps)', .endOfLine)
  out~append('State:' state, .endOfLine)
  out~append('Stage reached: step' stage, .endOfLine)
  do o over outcomes; out~append('  step' o~index o~name':' o~state '('o~seconds's)' o~reason, .endOfLine); end
  do i = outcomes~items + 1 to steps~items; out~append('  step' i steps[i]~name': NOT RUN', .endOfLine); end
  if atError \== .nil then out~append(atError~errorReport)
  -- what each look-only step found (ws~list, ws~tail ...), for review plans
  do o over outcomes
    f = o~findings
    if f \== '' then out~append('Step' o~index o~name 'found:', .endOfLine, f)
  end
  return out~string

/* ------------------------------------------------------------- the step -- */
::class PlanStep public inherit ShellObject
::constant SHELL_HELP "s~does(target, methodName, argsArray) sets the action: the message sent to target when the step runs (for example s~does(ws, 'run', .Array~of('make', '-C', 'hello'))). A step with no action only runs its checks. s~passIf(kind, value) adds a check: exitIs N (for an action that is not a program, exitIs 0 means it completed), fileExists path (a file or directory is there), fileAbsent path (it is not there), outputHas text, outputLacks text (these read the text of whatever the action returned: a program's output, a ws~list table, ws~tail lines). s~onFail('stop' or 'continue'); default stop; with continue the later steps still run but the plan still ends FAILED. s~timeout(seconds); default 600. Each returns the step."

::method init
  expose index name target msg args checks onFail timeoutSeconds
  use strict arg index, name
  target = .nil; msg = ''; args = .Array~new; checks = .Array~new
  onFail = 'stop'; timeoutSeconds = 600

::method index
  expose index
  return index
::method setIndex
  expose index
  use strict arg index
::method name
  expose name
  return name
::method target
  expose target
  return target
::method message
  expose msg
  return msg
::method arguments
  expose args
  return args~copy
::method checks
  expose checks
  return checks~copy
::method copyStep
  expose index name target msg args checks onFail timeoutSeconds
  s = .PlanStep~new(index, name)
  if target \== .nil then s~does(target, msg, args)
  do c over checks; s~passIf(c~kind, c~value); end
  s~onFail(onFail); s~timeout(timeoutSeconds)
  return s
::method onFail
  expose onFail
  use strict arg value = .nil
  if value == .nil then return onFail
  if wordpos(value~lower, 'stop continue') = 0 then raise syntax 93.900 array ('onFail is stop or continue, not' value)
  onFail = value~lower
  return self
::method timeout
  expose timeoutSeconds
  use strict arg value = .nil
  if value == .nil then return timeoutSeconds
  if \value~datatype('W') | value < 1 then raise syntax 93.900 array ('timeout needs whole seconds, not' value)
  timeoutSeconds = value
  return self

::method does
  expose target msg args
  use strict arg t, m, a = (.Array~new)
  if \t~isA(.ShellObject) then raise syntax 93.900 array ('does: the target must be a shell object')
  if \m~datatype('V') then raise syntax 93.900 array ('does: not a method name:' m)
  banned = 'CLASS SEND SENDWITH START STARTWITH SETMETHOD UNSETMETHOD UNKNOWN INIT INSTANCEMETHOD INSTANCEMETHODS COPY LAUNCH EXECUTE POLL'
  if wordpos(m~upper, banned) > 0 then raise syntax 93.900 array ('does: ~'m~lower 'is not allowed')
  known = shellPublicMethods(t~class)
  do p over shellProtectedMethods(t~class); known~append(p); end
  if known~index(m~lower) == .nil then raise syntax 93.900 array ('does:' t~class~id 'has no method' m)
  if \a~isA(.Array) then raise syntax 93.900 array ('does: arguments must be an Array')
  target = t; msg = m~lower; args = a~copy
  return self

::method passIf
  expose checks
  use strict arg kind, value
  checks~append(.StepCheck~new(kind, value))
  return self

::method action
  expose target msg args
  if target == .nil then return '(checks only)'
  text = target~class~id'~'msg'('
  sep = ''
  do a over args; text = text || sep || a~string; sep = ', '; end
  return text')'
::method checkText
  expose checks
  text = ''
  do c over checks; text = text';' c~text; end
  return text~substr(3)
::method fields
  return .Array~of('index', 'name', 'action', 'checkText', 'onFail')

/* Run the action through the secured runner, then the checks. */
::method perform
  expose index name target msg args checks timeoutSeconds
  use strict arg runner
  t0 = time('E')
  outcomeValue = .nil
  if target \== .nil then do
    if target~hasMethod('SETTIMEOUT') then target~setTimeout(timeoutSeconds)
    signal on syntax name actionFailed
    outcomeValue = runner~call(target, msg, args)
    signal off syntax
  end
  -- a program killed by a signal did not fail a check: it died, and the plan stops
  if outcomeValue \== .nil, outcomeValue~hasMethod('DIED'), outcomeValue~died then
    return .StepOutcome~new(index, name, 'DIED', time('E') - t0, 'none: the program died', -
      outcomeValue~program 'was killed by signal' outcomeValue~killedBy signalName(outcomeValue~killedBy) 'after' outcomeValue~seconds's', outcomeValue)
  base = ''
  if target \== .nil, target~hasMethod('PATH') then base = target~path
  else if checks~items > 0 then base = .ShellWorkspaceRegistry~lastPath
  do c over checks
    verdict = c~evaluate(outcomeValue, base)
    if \verdict[1] then return .StepOutcome~new(index, name, 'FAIL', time('E') - t0, c~text, verdict[2], outcomeValue)
  end
  return .StepOutcome~new(index, name, 'PASS', time('E') - t0, '', 'all' checks~items 'check(s) passed', outcomeValue)
actionFailed:
  c = condition('O')
  return .StepOutcome~new(index, name, 'FAIL', time('E') - t0, 'action', 'the action raised' c~code':' c~message, .nil)
::class StepCheck public
::method init
  expose kind value
  use strict arg kindArg, value
  kind = kindArg~lower
  if wordpos(kind, 'exitis fileexists fileabsent outputhas outputlacks') = 0 then
    raise syntax 93.900 array ('passIf kinds are exitIs fileExists fileAbsent outputHas outputLacks, not' kindArg)
::method text
  expose kind value
  return kind value
::method kind
  expose kind
  return kind
::method value
  expose value
  return value
::method evaluate
  expose kind value
  use strict arg outcomeValue, base
  select
    when kind == 'exitis' then do
      if outcomeValue == .nil | \outcomeValue~hasMethod('EXITCODE') then do
        -- not a program (ws~remove, ws~list ...): it completed, which is exit 0
        if value = 0 then return .Array~of(.true, '')
        return .Array~of(.false, 'the action was not a program; it completed (exit 0), wanted' value)
      end
      if outcomeValue~exitCode = value then return .Array~of(.true, '')
      return .Array~of(.false, 'exit' outcomeValue~exitCode', wanted' value)
    end
    when kind == 'fileexists' | kind == 'fileabsent' then do
      path = value
      if path~left(1) \== '/' then path = base'/'path
      there = .File~new(path)~exists                    -- a file or a directory
      if kind == 'fileexists' then do
        if there then return .Array~of(.true, '')
        return .Array~of(.false, value 'does not exist')
      end
      if \there then return .Array~of(.true, '')
      return .Array~of(.false, value 'still exists')
    end
    when kind == 'outputhas' | kind == 'outputlacks' then do
      -- the text of any result: a program's output, a listed table, a tail's lines
      lines = resultLines(outcomeValue)
      at = 0
      do i = 1 to lines~items
        if lines[i]~caselessPos(value) > 0 then do; at = i; leave; end
      end
      if kind == 'outputhas' then do
        if at > 0 then return .Array~of(.true, '')
        return .Array~of(.false, 'output does not contain "'value'"')
      end
      if at = 0 then return .Array~of(.true, '')
      return .Array~of(.false, 'output line' at 'contains "'value'"')
    end
  end

/* --------------------------------------------------------- step outcome -- */
::class StepOutcome public inherit ShellObject
::method init
  expose index name state seconds failedCheck reason outcomeValue
  use strict arg index, name, state, seconds, failedCheck, reason, outcomeValue
::method index
  expose index
  return index
::method name
  expose name
  return name
::method state
  expose state
  return state
::method seconds
  expose seconds
  return seconds~format(, 2)
::method failedCheck
  expose failedCheck
  return failedCheck
::method reason
  expose reason
  return reason
::method result
  expose outcomeValue
  return outcomeValue
::method exitCode
  expose outcomeValue
  if outcomeValue == .nil | \outcomeValue~hasMethod('EXITCODE') then return ''
  return outcomeValue~exitCode
/* For a step whose result is not a program run (a review step), what it
   found, at most 40 lines. */
::method findings
  expose state outcomeValue
  if state \== 'PASS' | outcomeValue == .nil then return ''
  if outcomeValue~hasMethod('ERRORPOINT') then return ''
  if outcomeValue~isA(.ShellObject) then text = outcomeValue~asTable
  else if outcomeValue~isA(.Array) then text = outcomeValue~makeString('LINE', '0a'x)
  else text = outcomeValue~string
  lines = text~makeArray('0a'x)
  out = .MutableBuffer~new
  if text == '' | lines~items = 0 then return '  (empty: nothing to show - the file or list has 0 lines)' || .endOfLine
  do i = 1 to min(40, lines~items); out~append('  ', lines[i], .endOfLine); end
  if lines~items > 40 then out~append('  ... (' || lines~items - 40 'more lines)', .endOfLine)
  return out~string
::method errorLine
  expose outcomeValue
  if outcomeValue == .nil | \outcomeValue~hasMethod('ERRORPOINT') then return ''
  return outcomeValue~errorPoint~text
::method fields
  return .Array~of('index', 'name', 'state', 'failedCheck', 'reason', 'exitCode', 'errorLine')

/* The error point and a trace excerpt; never the whole output. */
::method errorReport
  expose index name failedCheck reason outcomeValue
  out = .MutableBuffer~new
  if self~state == 'DIED' then out~append('Error point: step' index '"'name'" DIED:' reason, .endOfLine)
  else out~append('Error point: step' index '"'name'", check' failedCheck':' reason, .endOfLine)
  if outcomeValue == .nil | \outcomeValue~hasMethod('ERRORPOINT') then return out~string
  out~append('Program:' outcomeValue~commandLine', exit' outcomeValue~exitCode', timed out' outcomeValue~timedOut, .endOfLine)
  ep = outcomeValue~errorPoint
  if ep~line > 0 then out~append('First error line:' ep~stream 'line' ep~line':' ep~text, .endOfLine)
  else out~append('No line matched an error pattern; showing the end of' ep~stream'.', .endOfLine)
  out~append('Trace (' || ep~stream 'lines' ep~firstLine'-'ep~lastLine 'of' ep~total'):', .endOfLine)
  do l over ep~excerpt; out~append('  ', l, .endOfLine); end
  out~append('Full logs (for ws~tail):' outcomeValue~relStdoutFile outcomeValue~relStderrFile, .endOfLine)
  return out~string

/* ------------------------------------------------------------ workspace -- */
/* A directory programs run in. ws~run is protected: the security manager
   judges it as method run:PROGRAM against the workspace path. */
::class ShellWorkspaceRegistry public
::method lastPath class
  if .local~hasIndex('NEWSHELL.WS') then return .local['NEWSHELL.WS']
  return ''
::method remember class
  use strict arg path
  .local['NEWSHELL.WS'] = path

::class Workspace public inherit ShellObject
::constant SHELL_HELP "ws~run(program, arg1, arg2, ...) runs a program in the workspace directory, without a shell, and returns a RunResult (exitCode, killedBy, output, errorPoint). program is a name on PATH (make, unzip) or ./relative/path inside the workspace; path arguments must stay inside the workspace. Look-only: ws~list(dir) gives the files under dir with size and modified time; ws~tail(file, n) gives the last n lines of a file. ws~remove(file) removes one file (protected). Paths are relative to the workspace."

::method init
  expose dir timeoutSeconds counter
  use strict arg dirArg
  f = .File~new(dirArg)
  if \f~isDirectory then raise syntax 93.900 array ('Not a directory:' dirArg)
  if SysIsFileLink(f~absolutePath) then raise syntax 93.900 array ('Workspace is a symbolic link:' dirArg)
  dir = f~absolutePath~strip('T', '/')
  timeoutSeconds = 600; counter = 0
  .ShellWorkspaceRegistry~remember(dir)

::method path
  expose dir
  return dir
::method setTimeout
  expose timeoutSeconds
  use strict arg timeoutSeconds
::method fields
  return .Array~of('path', 'capabilities')
::method capabilities
  return .Array~of('READ', 'RUN(policy)')
::method identity
  expose dir
  return 'ws:'dir
::method exists
  expose dir
  use strict arg rel
  return .File~new(self~inside(rel))~exists

/* An absolute path inside the workspace, or a syntax error; no links. */
::method inside
  expose dir
  use strict arg rel
  if rel~left(1) == '/' then full = qualify(rel)
  else full = qualify(dir'/'rel)
  if full \== dir, full~left(dir~length + 1) \== dir'/' then raise syntax 93.900 array (rel 'is outside the workspace')
  if shellLinkOnPath(full) \== '' then raise syntax 93.900 array (rel 'goes through a symbolic link')
  return full

/* Look-only: files under rel (default the whole workspace), with size and time. */
::method list
  expose dir
  use strict arg rel = '.'
  full = self~inside(rel)
  if \.File~new(full)~isDirectory then return .ShellCollection~new(.Array~of(.FsFile~new(dir, .File~new(full), 'file')))
  rows = .Array~new
  do f over .FileSystem~new(full)~files
    if f~path~pos('/.newshell/') = 0 then rows~append(.FsFile~new(dir, .File~new(f~path), 'file'))
  end
  return .ShellCollection~new(rows)

/* Look-only: the last n lines of a file. */
::method tail
  use strict arg rel, n = 20
  full = self~inside(rel)
  lines = .Array~new
  s = .Stream~new(full)
  if s~open('READ') \= 'READY:' then return .Array~of('(cannot read' rel')')
  do forever
    l = s~lineIn
    if l == '', s~state \== 'READY' then leave
    lines~append(l)
  end
  s~close
  if lines~items <= n then return lines
  return lines~section(lines~items - n + 1)

/* Remove one file inside the workspace (protected: the policy decides). */
::method remove protected
  use strict arg rel
  full = self~inside(rel)
  f = .File~new(full)
  if f~isDirectory then raise syntax 93.900 array ('remove takes a file, not a directory:' rel)
  if \f~exists then return 'absent:' rel
  if \f~delete then raise syntax 93.900 array ('Could not remove' rel)
  .NewshellLog~event('REMOVED' full)
  return 'removed:' rel

::method run protected
  expose dir timeoutSeconds counter
  use arg program
  argv = .Array~of(self~resolveProgram(program))
  -- arguments that name paths must stay inside the workspace
  do i = 2 to arg()
    a = arg(i)~string
    if a~left(1) == '/' | a == '..' | a~left(3) == '../' | a~pos('/../') > 0 | a~right(3) == '/..' then ignore = self~inside(a)
    argv~append(a)
  end
  spec = .ProcessSpec~new(argv)
  spec~cwd = dir
  spec~timeoutMs = timeoutSeconds * 1000
  spec~maxOutputBytes = 4194304
  counter += 1
  logBase = dir'/.newshell/runs/'counter~right(3, '0')'-'filespec('name', program)~changeStr('.', '')
  .File~new(dir'/.newshell/runs')~makeDirs
  .NewshellLog~event('RUN' argv~makeString('L', ' ') 'in' dir)
  t0 = time('E')
  x = .ProcessRunner~new~run(spec)
  res = .RunResult~new(program, argv, x, time('E') - t0, logBase)
  .NewshellLog~event('RUN exit' res~exitCode 'in' res~seconds's, stdout' res~stdoutLines 'lines, stderr' res~stderrLines 'lines')
  return res

::method resolveProgram private
  expose dir
  use strict arg program
  if program~left(2) == './' then do
    full = qualify(dir'/'program~substr(3))
    if full~left(dir~length + 1) \== dir'/' then raise syntax 93.900 array (program 'is outside the workspace')
    if shellLinkOnPath(full) \== '' then raise syntax 93.900 array (program 'goes through a symbolic link')
    if \.File~new(full)~isFile then raise syntax 93.900 array ('No such program:' program)
    return full
  end
  if program~pos('/') > 0 then raise syntax 93.900 array ('Give a program name on PATH or ./path in the workspace, not' program)
  do d over value('PATH',, 'ENVIRONMENT')~makeArray(':')
    if d == '' then iterate
    if .File~new(d'/'program)~isFile then return d'/'program
  end
  raise syntax 93.900 array ('Program not found on PATH:' program)

/* The security manager judges ws~run as run:PROGRAM at the workspace path. */
::method authorityAction
  use strict arg name, args
  if name~upper == 'RUN', args~items >= 1 then return 'run:'args[1]
  return name
::method authorityPath
  expose dir
  use strict arg name, args
  if name~upper == 'REMOVE', args~items >= 1 then return self~inside(args[1])
  return dir
::method relatedSamples
  return .Array~of(.Array~of('ws~run(...) returns a RunResult', .RunResult~sample))

::class RunResult public inherit ShellObject
::constant SHELL_HELP "exitCode is the program's exit status. output is stdout and stderr lines as an Array. errorPoint is the first line that looks like an error, with lines around it."
::method sample class
  return self~new('true', .Array~of('/bin/true'), .nil, 0, '')
::method init
  expose program argv exitCode timedOut seconds outLines errLines stdoutFile stderrFile killedBy
  use strict arg program, argv, x, seconds, logBase
  outLines = .Array~new; errLines = .Array~new; exitCode = ''; timedOut = .false; killedBy = 0
  stdoutFile = ''; stderrFile = ''
  if x == .nil then return
  if x~failedToStart then do
    exitCode = 127
    errLines~append('could not start:' x~errorMessage)
  end
  else do
    exitCode = x~exitCode
    timedOut = x~timedOut
    if x~termination == 'SIGNAL' then do      -- killed: the shell's convention, 128 + signal
      killedBy = x~termSignal
      exitCode = 128 + killedBy
    end
    outLines = splitLines(x~stdout)
    errLines = splitLines(x~stderr)
    if timedOut then errLines~append('newshell: timed out')
  end
  stdoutFile = logBase'.out'; stderrFile = logBase'.err'
  call writeLines stdoutFile, outLines
  call writeLines stderrFile, errLines

::method program
  expose program
  return program
::method commandLine
  expose argv
  return argv~makeString('L', ' ')
::method exitCode
  expose exitCode
  return exitCode
::method timedOut
  expose timedOut
  return timedOut
::method seconds
  expose seconds
  return seconds~format(, 2)
/* 0, or the signal that killed the program (9 for kill -9). */
::method killedBy
  expose killedBy
  return killedBy
::method died
  expose killedBy timedOut
  return killedBy > 0 & \timedOut
::method stdoutLines
  expose outLines
  return outLines~items
::method stderrLines
  expose errLines
  return errLines~items
::method stdoutFile
  expose stdoutFile
  return stdoutFile
::method stderrFile
  expose stderrFile
  return stderrFile
::method relStdoutFile
  expose stdoutFile
  return relToWorkspace(stdoutFile)
::method relStderrFile
  expose stderrFile
  return relToWorkspace(stderrFile)
::method output
  expose outLines errLines
  all = outLines~copy
  do l over errLines; all~append(l); end
  return all
::method findLine
  use strict arg text
  n = 0
  do l over self~output
    n += 1
    if l~caselessPos(text) > 0 then return n
  end
  return 0
::method fields
  return .Array~of('program', 'exitCode', 'killedBy', 'seconds', 'stdoutLines', 'stderrLines')

/* First error-looking line in stderr (then stdout), with 3 lines before and
   6 after; with no match, the last 10 lines of stderr. */
::method errorPoint
  expose outLines errLines
  patterns = .Array~of('error', 'fatal', 'undefined reference', 'no such file', 'cannot', 'failed')
  do pair over .Array~of(.Array~of('stderr', errLines), .Array~of('stdout', outLines))
    lines = pair[2]
    do i = 1 to lines~items
      do p over patterns
        if lines[i]~caselessPos(p) > 0 then return .ErrorPoint~new(pair[1], lines, i)
      end
    end
  end
  if errLines~items = 0 then return .ErrorPoint~new('stdout', outLines, 0)   -- e.g. killed: what it was doing last
  return .ErrorPoint~new('stderr', errLines, 0)

::class ErrorPoint public
::method init
  expose stream lines line firstLine lastLine
  use strict arg stream, lines, line
  if line > 0 then do
    firstLine = max(1, line - 3); lastLine = min(lines~items, line + 6)
  end
  else do
    firstLine = max(1, lines~items - 9); lastLine = lines~items
  end
::method stream
  expose stream
  return stream
::method line
  expose line
  return line
::method text
  expose lines line
  if line = 0 then return ''
  return lines[line]
::method firstLine
  expose firstLine
  return firstLine
::method lastLine
  expose lastLine
  return lastLine
::method total
  expose lines
  return lines~items
::method excerpt
  expose lines firstLine lastLine line
  list = .Array~new
  do i = firstLine to lastLine
    mark = '  '; if i = line then mark = '> '
    list~append(mark || i~right(4)':' lines[i])
  end
  return list

/* ---------------------------------------------------------------- watch -- */
::class Watch public inherit ShellObject
::constant SHELL_HELP "A Watch checks every few seconds and fires once: diskFreeBelow(path, bytes) when free space under path falls below bytes; fileAppears(dir, pattern) when a new file matching pattern (* and ? wildcards) appears in dir. w~every(seconds), default 2. w~lasting(seconds), default 3600. Submit it with jobs~submit(w)."

::method init
  expose kind a1 a2 owner state every lasting event known name settled
  use strict arg kindArg, a1, a2, owner
  kind = kindArg~lower
  select
    when kind == 'diskfreebelow' then do
      if \a2~datatype('N') then raise syntax 93.900 array ('diskFreeBelow(path, bytes): bytes must be a number')
      name = 'disk free under' a1 '<' a2
    end
    when kind == 'fileappears' then name = 'file' a2 'appears in' a1
    otherwise raise syntax 93.900 array ('watch kinds are diskFreeBelow and fileAppears, not' kindArg)
  end
  if \.File~new(a1)~isDirectory then raise syntax 93.900 array ('Not a directory:' a1)
  state = 'REGISTERED'; every = 2; lasting = 3600; event = ''; known = .Set~new; settled = .false

::method name unguarded
  expose name
  return name
::method watchKind unguarded
  expose kind
  return kind
::method watchArgs unguarded
  expose a1 a2
  return .Array~of(a1, a2)
::method state unguarded
  expose state
  return state
::method event unguarded
  expose event
  return event
::method stage unguarded
  expose state
  return state
::method every
  expose every
  use strict arg s
  every = s
  return self
::method lasting
  expose lasting
  use strict arg s
  lasting = s
  return self
::method stop unguarded
  expose state
  if state == 'ARMED' then state = 'STOPPED'
  return self
::method fields
  return .Array~of('name', 'state', 'event')
::method setDiagnosis unguarded
  expose diagnosis
  use strict arg diagnosis
::method diagnosis unguarded
  expose diagnosis
  if var('diagnosis') = 0 then return ''
  return diagnosis
::method followUp unguarded
  expose followUp
  if var('followUp') = 0 then return .nil
  return followUp
::method setFollowUp unguarded
  expose followUp
  use strict arg followUp
::method origin unguarded
  expose origin
  if var('origin') = 0 then return .nil
  return origin
::method setOrigin unguarded
  expose origin
  use strict arg origin

::method launch protected
  expose kind a1 a2 state known
  if state \== 'REGISTERED' then raise syntax 93.900 array ('Watch already' state)
  if kind == 'fileappears' then do n over self~matching; known~put(n); end
  state = 'ARMED'
  .Message~new(self, 'POLL')~start

::method settled unguarded
  expose settled
  return settled

::method poll protected unguarded        -- loops until fired: must not hold the object's lock
  expose kind a1 a2 owner state every lasting event settled
  t0 = time('E')
  .NewshellLog~event('WATCH armed:' self~name', every' every's')
  do while state == 'ARMED'
    hit = self~probe
    if hit \== '' then do
      event = hit; state = 'FIRED'
      .NewshellLog~event('WATCH fired:' self~name '-' hit)
      call tellOwner owner, self
      .ShellInbox~current~post('watch', self~name, hit, self)
      settled = .true
      return
    end
    if time('E') - t0 > lasting then do; state = 'EXPIRED'; leave; end
    call SysSleep every
  end
  .NewshellLog~event('WATCH' state':' self~name)
  settled = .true

::method probe private
  expose kind a1 a2 known
  if kind == 'diskfreebelow' then do
    free = diskFree(a1)
    if free \== '', free < a2 then return 'free space under' a1 'is' free 'bytes, below' a2
    return ''
  end
  do n over self~matching
    if \known~hasIndex(n) then return 'new file' a1'/'n
  end
  return ''

::method matching private
  expose a1 a2
  names = .Array~new
  list = .File~new(a1)~listFiles
  if list == .nil then return names
  do f over list
    if f~isFile, globMatch(a2, f~name) then names~append(f~name)
  end
  return names

::method report unguarded
  expose kind event
  return jobHistory(self) || 'Job: watch "'self~name'"' || .endOfLine || 'State:' self~state || .endOfLine || 'Event:' event || .endOfLine

/* ---------------------------------------------------------------- inbox -- */
/* Where finished jobs and fired watches land, for the person at the console. */
::class ShellInbox public inherit ShellObject
::method current class
  if \.local~hasIndex('NEWSHELL.INBOX') then .local['NEWSHELL.INBOX'] = self~new
  return .local['NEWSHELL.INBOX']
::method init
  expose items
  items = .Array~new
::method post unguarded
  expose items
  use strict arg kind, name, text, job
  guard on
  items~append(.InboxMessage~new(kind, name, text, job))
  guard off
::method unread unguarded
  expose items
  n = 0
  do m over items; if \m~seen then n += 1; end
  return n
::method take unguarded
  expose items
  guard on
  list = .Array~new
  do m over items; if \m~seen then do; m~markSeen; list~append(m); end; end
  guard off
  return .ShellCollection~new(list)
::method all unguarded
  expose items
  return .ShellCollection~new(items~copy)
::method fields
  return .Array~of('unread')

::class InboxMessage public inherit ShellObject
::method init
  expose kind name text job seen at
  use strict arg kind, name, text, job
  seen = .false; at = time('L')
::method kind
  expose kind
  return kind
::method name
  expose name
  return name
::method text
  expose text
  return text
::method job
  expose job
  return job
::method at
  expose at
  return at
::method seen
  expose seen
  return seen
::method markSeen
  expose seen
  seen = .true
::method diagnosis
  expose job
  return job~diagnosis
::method followUp
  expose job
  if \job~hasMethod('FOLLOWUP') then return .nil
  return job~followUp
::method fields
  return .Array~of('at', 'kind', 'name', 'text')

/* -------------------------------------------------------------- helpers -- */
/* The owner (an Llm) is told; a failure to tell is logged, never fatal. */
::routine tellOwner
  use strict arg owner, job
  if owner == .nil then return
  signal on syntax name tellFailed
  owner~jobFinished(job)
  return
tellFailed:
  .NewshellLog~event('NOTIFY failed for' job~name':' condition('O')~message)
  return

::routine splitLines
  use strict arg text
  if text == .nil then return .Array~new
  text = text~string
  if text == '' then return .Array~new
  lines = text~makeArray('0a'x)
  return lines

::routine writeLines
  use strict arg path, lines
  s = .Stream~new(path)
  if s~open('WRITE REPLACE') \= 'READY:' then return
  do l over lines; s~lineOut(l); end
  s~close

/* Free bytes under path, from df -P -B1 (ooRexx has no statvfs on Linux). */
::routine diskFree
  use strict arg path
  -- dev7: statvfs through the native provider (ChatGPT, providers dev10); df only without it
  c = .ShellNative~capacity(path)
  if c \== .nil then return c['free']
  df = '/usr/bin/df'
  if .File~new('/bin/df')~isFile then df = '/bin/df'
  spec = .ProcessSpec~new(.Array~of(df, '-P', '-B1', path))
  spec~timeoutMs = 10000
  x = .ProcessRunner~new~run(spec)
  if x~failedToStart then return ''
  lines = splitLines(x~stdout)
  if lines~items < 2 then return ''
  return lines[2]~word(4)

::routine globMatch public
  use strict arg pattern, name
  if pattern == '' then return name == ''
  c = pattern~left(1)
  if c == '*' then do
    do i = 0 to name~length
      if globMatch(pattern~substr(2), name~substr(i + 1)) then return .true
    end
    return .false
  end
  if name == '' then return .false
  if c == '?' | c == name~left(1) then return globMatch(pattern~substr(2), name~substr(2))
  return .false

/* The chain this job ends: each job a follow-up came from, oldest first. */
::routine jobHistory
  use strict arg job
  chain = .Array~new
  j = job~origin
  do while j \== .nil & chain~items < 20
    chain~insert(j, .nil)
    j = j~origin
  end
  if chain~items = 0 then return ''
  out = .MutableBuffer~new('History (oldest first; jobs~find(name) gives any of them):' || .endOfLine)
  n = 0
  do j over chain
    n += 1
    out~append('  ' n '"'j~name'"' j~state 'at' j~stage, .endOfLine)
  end
  return out~string

/* The lines of text a step's result shows. */
::routine resultLines
  use strict arg v
  if v == .nil then return .Array~new
  if v~hasMethod('OUTPUT') then return v~output
  if v~isA(.ShellObject) then return v~asTable~makeArray('0a'x)
  if v~isA(.Array) then return v
  return v~string~makeArray('0a'x)

::routine relToWorkspace
  use strict arg path
  at = path~pos('/.newshell/')
  if at = 0 then return path
  return path~substr(at + 1)

::routine signalName
  use strict arg n
  names = .Array~of('SIGHUP', 'SIGINT', 'SIGQUIT', 'SIGILL', 'SIGTRAP', 'SIGABRT', 'SIGBUS', 'SIGFPE', 'SIGKILL', 'SIGUSR1', 'SIGSEGV', 'SIGUSR2', 'SIGPIPE', 'SIGALRM', 'SIGTERM')
  if n >= 1, n <= names~items then return '('names[n]')'
  return ''
