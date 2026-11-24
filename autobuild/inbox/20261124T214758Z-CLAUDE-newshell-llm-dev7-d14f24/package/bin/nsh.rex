/* nsh.rex - NewShell console for LLM proposals (v0.1-dev1)
   Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).

   Verbs (anything else is an ooRexx line, run as typed):
     start llm claude [MODEL]         claude = .Llm~start('claude' [, MODEL])
     proto fs PATH                    build the prototype tree at PATH, then mount it
     mount fs PATH                    fs = .FileSystem~new(PATH)
     create file "PATH"               fsobj = fs~create(PATH)
     policy                           show the policy rules
     decisions                        show the last run's authorisation receipts
     provide llm claude the fs        claude~provide('fs', fs)   (also: provide claude fs)
     mount ws PATH                    ws = .Workspace~new(PATH): where plan steps run programs
     prompt claude "find largest file"   proposal = claude~prompt(...), then shown
     jobs                             the plans and watches submitted
     inbox                            messages from finished plans and fired watches
     wait [SECONDS]                   wait for submitted jobs to settle, showing messages
     autopilot N                      run up to N follow-up proposals as they arrive
     proposal                         show the last proposal: fields, code, sources checked
     ~run                             run the last proposal; the result is kept as LAST
     quit
   Every line runs under the security manager as principal console, so the
   policy (etc/newshell.policy) decides protected calls typed by a person
   too. Only SYNTAX is trapped per line; HALT (Ctrl-C) ends the console. */
signal on halt
echo = value('NSH_ECHO',, 'ENVIRONMENT') == '1'    -- echo input lines, for transcripts
here = filespec('location', .context~package~name)
vars = .Directory~new
consoleManager = .ShellSecurityManager~new('console')
do forever
  if \echo then call charout , 'nsh> '
  line = .stdin~linein
  if line == '', .stdin~state \== 'READY' then leave
  line = line~strip
  if echo then say 'nsh>' line
  if line == '' then iterate
  if line~upper == 'QUIT' | line~upper == 'EXIT' then leave
  code = translateVerb(line, here)
  call runLine code
end
exit 0
halt:
  say
  say 'nsh: halted'
  exit 1

/* Each line runs as its own routine under the security manager, principal
   console; the console's variables are carried from line to line. */
runLine:
  signal on syntax name lineFailed
  src = .Array~of('use arg ns_vars', -
    'do ns_n over ns_vars~allIndexes; call value ns_n, ns_vars[ns_n]; end; drop ns_n', -
    arg(1), -
    'ns_v = .context~variables; ns_v~remove("NS_VARS"); ns_vars~putAll(ns_v)', -
    'return')
  r = .Routine~new('nsh_line', src, .context~package)
  r~setSecurityManager(consoleManager)
  r~call(vars)
  signal off syntax
  return
lineFailed:
  signal off syntax
  c = condition('O')
  say 'nsh: error' c~code':' c~message
  return

translateVerb: procedure
  use strict arg line, here
  w = line~space~makeArray(' ')
  verb = w[1]~upper
  select
    when verb == 'START', w~items >= 3, w[2]~upper == 'LLM' then do
      model = ''
      if w~items >= 4 then model = ", '"w[4]"'"
      -- the LLM's own job board comes with it, already provided as jobs
      return w[3] "= .Llm~start('"w[3]"'"model"); jobs = .JobBoard~new("w[3]"); "w[3]"~provide('jobs', jobs)"
    end
    when verb == 'MOUNT', w~items >= 3, w[2]~upper == 'WS' then
      return "ws = .Workspace~new('"line~subword(3)~strip"'); ws~~table"
    when verb == 'JOBS' then return 'jobs~jobs~~table'
    when verb == 'INBOX' then return 'ns_f = nshInbox(); if ns_f \== .nil then proposal = ns_f'
    when verb == 'AUTOPILOT' then do
      n = 0; if w~items >= 2 then n = w[2]
      return 'autopilot =' n"; say 'autopilot: up to' autopilot 'follow-up proposal(s) will be run without asking (the policy still decides every call)'"
    end
    when verb == 'WAIT' then do
      secs = 120; if w~items >= 2 then secs = w[2]
      return "if symbol('autopilot') \== 'VAR' then autopilot = 0; ns_r = nshWait(jobs," secs", autopilot); if ns_r[1] \== .nil then proposal = ns_r[1]; autopilot = ns_r[2]"
    end
    when (verb == 'MOUNT' | verb == 'PROTO'), w~items >= 3, w[2]~upper == 'FS' then do
      path = line~subword(3)~strip
      build = ''
      if verb == 'PROTO' then build = "'rexx' '"here"../tests/make_proto_fs.rex' '"path"'; "
      return build"fs = .FileSystem~new('"path"'); fs~~table"
    end
    when verb == 'PROVIDE' then do
      -- provide llm claude the fs  |  provide claude fs
      rest = .Array~new
      do i = 2 to w~items
        if wordpos(w[i]~upper, 'LLM THE') = 0 then rest~append(w[i])
      end
      if rest~items < 2 then return "say 'usage: provide llm NAME the OBJECT'"
      return rest[1]"~provide('"rest[2]"', "rest[2]"); "rest[1]"~~table"
    end
    when verb == 'PROMPT', w~items >= 3 then do
      text = line~subword(3)~strip
      if pos(text~left(1), '"''') > 0 then text = text~substr(2, text~length - 2)
      return 'proposal =' w[2]"~prompt("quoteRexx(text)"); proposal~~table~~show"
    end
    when verb == 'CREATE', w~items >= 3, w[2]~upper == 'FILE' then do
      path = line~subword(3)~strip
      if pos(path~left(1), '"''') > 0 then path = path~substr(2, path~length - 2)
      return 'fsobj = fs~create('quoteRexx(path)'); fsobj~~table'
    end
    when line~upper == 'POLICY' then return '.ShellPolicy~current~~table'
    when line~upper == 'DECISIONS' then return 'proposal~decisions~~table'
    when line~upper == 'PROPOSAL' then return 'proposal~~table~~show~~sources'
    when line == '~run' | line~upper == 'PROPOSAL~RUN' then return 'last = proposal~run; if last \== .nil then last~~table'
    otherwise return line
  end

quoteRexx: procedure
  use strict arg text
  return "'"text~changeStr("'", "''")"'"

/* Show unread inbox messages, with the LLM's diagnosis and its follow-up
   proposal when it wrote one. Returns the newest follow-up, or .nil. */
::routine nshInbox public
  list = .ShellInbox~current~take
  newest = .nil
  if list~items~items = 0 then do; say 'inbox: nothing new'; return newest; end
  do m over list~items
    say 'inbox:' m~at m~kind '"'m~name'"' m~text
    d = m~diagnosis
    if d \== '' then do l over d~makeArray('0a'x); say '   llm:' l; end
    f = m~followUp
    if f \== .nil then do
      say '   follow-up proposal:' f~state', ' || f~lines 'lines (it is now PROPOSAL; ~run runs it)'
      f~show
      newest = f
    end
  end
  return newest

/* Wait until every submitted job has settled (or seconds pass), showing
   messages as they land. The console waits; the LLM does not. With
   autopilot n > 0, up to n checked follow-up proposals are run as they
   arrive (the security manager still decides every protected call).
   Returns .Array~of(newest follow-up or .nil, autopilot left). */
::routine nshWait public
  use strict arg jobs, seconds = 120, autopilot = 0
  t0 = time('E')
  newest = .nil
  do forever
    if .ShellInbox~current~unread > 0 then do
      f = nshInbox()
      if f \== .nil then do
        newest = f
        if autopilot > 0 & f~state == 'CHECKED' then do
          autopilot -= 1
          say 'autopilot: running the follow-up (' || autopilot 'left)'
          signal on syntax name runFailed
          r = f~run
          signal off syntax
          if r \== .nil then r~~table
          newest = .nil
        end
        else if f~state \== 'CHECKED' then say 'autopilot: not running a' f~state 'proposal'
      end
    end
    if jobs~running = 0 & .ShellInbox~current~unread = 0 then leave
    if time('E') - t0 >= seconds then do; say 'wait: still running after' seconds's'; leave; end
    call SysSleep 0.5
  end
  return .Array~of(newest, autopilot)
runFailed:
  say 'autopilot: the follow-up failed:' condition('O')~message
  return .Array~of(.nil, autopilot)

::requires 'FileSystem.cls'
::requires 'ShellJobs.cls'
::requires 'ShellLlm.cls'
::requires 'Computer.cls'
::requires 'ShellSecurity.cls'
