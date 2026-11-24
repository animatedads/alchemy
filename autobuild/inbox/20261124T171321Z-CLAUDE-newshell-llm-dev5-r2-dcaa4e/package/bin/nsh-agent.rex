/* nsh-agent.rex - newshell for an agent (Codex): one command per invocation
   Architecture: Tom Dyer. Coding: Claude (Opus 5.5).

   rexx nsh-agent.rex [--config FILE] describe
   rexx nsh-agent.rex [--config FILE] check FILE
   rexx nsh-agent.rex [--config FILE] run FILE [--follows JOB] [--wait SECONDS]
   rexx nsh-agent.rex [--config FILE] jobs
   rexx nsh-agent.rex [--config FILE] report JOB

   describe  the objects the agent may use: the same brief an LLM is given
   check     check a proposal file; print the source of every method it calls
   run       check and run it under the security manager as the agent's
             principal; wait for the jobs it submits to settle; print each
             one's report (job, stage reached, result, error point)
   jobs      the jobs kept in the state directory
   report    one kept job's report

   stdout carries what the agent reads (briefs, sources, reports); progress
   goes to stderr through oorexx_logging. Exit: 0 ok (every job passed),
   1 a job FAILED or DIED, 2 rejected, refused or a usage error. */
parse arg argline
args = argline~space~makeArray(' ')
config = value('NEWSHELL_AGENT_CONFIG',, 'ENVIRONMENT')
if config == '' then config = filespec('location', .context~package~name)'../etc/agent.conf'
follows = ''; waitSeconds = 600
rest = .Array~new
i = 1
do while i <= args~items
  a = args[i]
  select
    when a == '--config' then do; i += 1; config = args[i]; end
    when a == '--follows' then do         -- a job name may have spaces: every word up to the next option
      do while i < args~items
        if args[i + 1]~left(2) == '--' then leave
        i += 1; follows = (follows args[i])~strip
      end
    end
    when a == '--wait' then do; i += 1; waitSeconds = args[i]; end
    otherwise rest~append(a)
  end
  i += 1
end
if rest~items = 0 then call usage
verb = rest[1]~lower
signal on syntax name failed
agent = .Agent~fromConfig(config)
select
  when verb == 'describe' then do
    say agent~brief
    exit 0
  end
  when verb == 'jobs' then do
    agent~board~jobs~~table
    exit 0
  end
  when verb == 'report' then do
    if rest~items < 2 then call usage
    job = agent~board~find(rest~section(2)~makeString('L', ' '))
    if job == .nil then do; say 'no job named' rest~section(2)~makeString('L', ' '); exit 2; end
    say job~report
    exit 0
  end
  when verb == 'check' | verb == 'run' then do
    if rest~items < 2 then call usage
    file = rest[2]
    code = readAll(file)
    p = .Proposal~new(agent, 'file' file, code)
    p~setFinal(code)
    say 'Proposal' file':' p~state', ' || p~lines 'lines,' p~methodsChecked 'method source(s) checked'
    if p~problems > 0 then do
      do x over p~problemList; say 'PROBLEM:' x; end
      exit 2
    end
    if verb == 'check' then do
      say 'The source of every method this proposal calls, read from the live objects:'
      do s over p~sourceList
        say s~listing
      end
      exit 0
    end
    if follows \== '' then do
      origin = agent~board~find(follows)
      if origin == .nil then do; say 'PROBLEM: --follows names no kept job:' follows; exit 2; end
      p~setOrigin(origin)
    end
    before = agent~board~jobs~items~items
    signal on syntax name refused
    value = p~run
    signal off syntax
    -- the jobs this run submitted: wait for each to settle, then report it
    submitted = agent~board~jobs~items~section(before + 1)
    t0 = time('E')
    do j over submitted
      do while \j~settled & time('E') - t0 < waitSeconds
        call SysSleep 0.5
      end
    end
    worst = 0
    do j over submitted
      say '=====' j~name':' j~state
      say j~report
      if wordpos(j~state, 'FAILED DIED EXPIRED') > 0 then worst = 1
      if \j~settled then do; say 'still running after' waitSeconds's'; worst = 1; end
    end
    if submitted~items = 0, value \== .nil then do
      if value~isA(.ShellObject) then value~~table
      else say value
    end
    exit worst
  end
  otherwise call usage
end
exit 0

refused:
  c = condition('O')
  if c~code == '98.948' then say 'REFUSED:' c~message        -- the security manager said no
  else say 'ERROR' c~code':' c~message
  exit 2
failed:
  c = condition('O')
  say 'ERROR' c~code':' c~message
  exit 2
usage:
  say 'usage: nsh-agent [--config FILE] describe | check FILE | run FILE [--follows JOB] [--wait SECONDS] | jobs | report JOB'
  exit 2

::routine readAll
  use strict arg path
  s = .Stream~new(path)
  if s~open('READ') \= 'READY:' then raise syntax 93.900 array ('Cannot read' path)
  text = s~charIn(1, s~chars)
  s~close
  return text~strip('T', '0a'x)

::requires 'ShellAgent.cls'
