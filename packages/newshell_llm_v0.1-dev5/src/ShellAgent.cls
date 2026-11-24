/* ShellAgent.cls - an agent (Codex) as the principal of its own proposals
   Architecture: Tom Dyer (24 November 2026): put newshell on ed209g and hand
   Codex the keys; it works through shell objects, its plans report back to
   it, and the policy decides every protected call.
   Coding: Claude (Opus 5.5).

   An Agent is a ShellContext with no LLM client: the agent writes the code
   itself and gives it to bin/nsh-agent.rex. Each invocation is a separate
   process (Codex works one sshnode command at a time), so jobs are kept in
   a JobStore when they settle and read back at the start of the next
   invocation: jobs~find(name) and amend work across commands, and a report
   is never lost with the process that produced it.

   Config (etc/agent.conf): one directive per line, '#' comments
     principal NAME                 who the code runs as (default codex)
     state DIR                      where jobs are kept
     policy FILE                    the policy file (else NEWSHELL_POLICY)
     provide VAR CLASS [ARG ...]    an object the agent's code may use;
                                    CLASS is one of Mu Network Services Xtpd
                                    Workspace FileSystem Computer */
::requires 'ShellProposal.cls'
::requires 'ShellJobs.cls'
::requires 'ShellHost.cls'
::requires 'ShellNet.cls'
::requires 'FileSystem.cls'
::requires 'Computer.cls'
::requires 'json.cls'

::class Agent public subclass ShellContext
::method init
  expose store board configPath
  use strict arg principal, stateDir
  self~init:super(principal)
  store = .JobStore~new(stateDir)
  board = .JobBoard~new(self)
  self~provide('jobs', board)

::method board
  expose board
  return board
::method store
  expose store
  return store

/* Build an agent from a config file. */
::method fromConfig class
  use strict arg path
  principal = 'codex'; stateDir = ''; provides = .Array~new
  do l over readLines(path)
    l = l~changeStr('09'x, ' ')
    if l~pos('#') > 0 then l = l~left(l~pos('#') - 1)
    if l~strip == '' then iterate
    select
      when l~word(1) == 'principal' then principal = l~word(2)
      when l~word(1) == 'state' then stateDir = l~word(2)
      when l~word(1) == 'policy' then call value 'NEWSHELL_POLICY', l~word(2), 'ENVIRONMENT'
      when l~word(1) == 'provide' then provides~append(l~subword(2))
      otherwise raise syntax 93.900 array (path': unknown directive' l~word(1))
    end
  end
  if stateDir == '' then raise syntax 93.900 array (path': no state directory')
  a = self~new(principal, stateDir)
  do p over provides
    a~provide(p~word(1), makeObject(p~word(2), p~subword(3)))
  end
  a~restoreJobs
  return a

/* The brief an agent is given: the same object description an LLM gets. */
::method brief
  text = self~systemPrompt
  text = text~changeStr('6. Reply with the code only: no explanation, no markdown fences, no USE ARG line.', -
    '6. Write the code to a file, give it to "nsh-agent check FILE", then "nsh-agent run FILE". When a job you submit stops, run prints its report; answer it with the next file (review, cleanup, or the amended plan), run with --follows JOBNAME.')
  return text

/* A job settled: keep it, so the next invocation can find and amend it. */
::method jobFinished
  expose store
  use strict arg job
  store~save(job, self)
  return

/* Objects the agent provided, by the name its code uses. */
::method nameOf
  use strict arg obj
  do n over self~names
    if self~objectNamed(n) == obj then return n
  end
  return ''
::method objectNamed
  use strict arg n
  names = self~names; objs = self~objects
  do i = 1 to names~items
    if names[i] == n~lower then return objs[i]
  end
  return .nil

::method restoreJobs
  expose store board
  byName = .Directory~new
  do rec over store~records
    job = rebuild(rec, self)
    if job == .nil then iterate
    o = rec['origin']
    if o \== .nil, o \== '', byName~hasIndex(o~lower) then job~setOrigin(byName[o~lower])
    board~adopt(job)
    byName[job~name~lower] = job
  end
  if store~records~items > 0 then .NewshellLog~event('RESTORED' store~records~items 'job(s) from' store~dir)

::method fields
  return .Array~of('principal', 'provided')

/* -------------------------------------------------------------- job store -- */
::class JobStore public
::method init
  expose dir
  use strict arg dir
  .File~new(dir'/jobs')~makeDirs
  if \.File~new(dir'/jobs')~isDirectory then raise syntax 93.900 array ('Cannot use state directory' dir)
::method dir
  expose dir
  return dir

::method save
  expose dir
  use strict arg job, agent
  rec = .Directory~new
  rec['name'] = job~name; rec['state'] = job~state; rec['stage'] = job~stage
  rec['report'] = job~report; rec['saved'] = .DateTime~new~isoDate
  rec['origin'] = ''
  if job~origin \== .nil then rec['origin'] = job~origin~name
  if job~isA(.Plan) then do
    rec['kind'] = 'plan'
    rec['seconds'] = job~seconds
    steps = .Array~new
    do s over job~steps~items
      st = .Directory~new
      st['name'] = s~name; st['message'] = s~message; st['onFail'] = s~onFail; st['timeout'] = s~timeout
      st['target'] = ''
      if s~target \== .nil then st['target'] = agent~nameOf(s~target)
      args = .Array~new; do a over s~arguments; args~append(a~string); end
      st['args'] = args
      cs = .Array~new
      do c over s~checks; cs~append(.Array~of(c~kind, c~value~string)); end
      st['checks'] = cs
      steps~append(st)
    end
    rec['steps'] = steps
  end
  else do
    rec['kind'] = 'watch'
    rec['watchKind'] = job~watchKind
    rec['watchArgs'] = job~watchArgs
    rec['event'] = job~event
  end
  n = .File~new(dir'/jobs')~list~items + 1
  path = dir'/jobs/'n~right(4, '0')'-'slug(job~name)'.json'
  s = .Stream~new(path)
  if s~open('WRITE REPLACE') \= 'READY:' then raise syntax 93.900 array ('Cannot write' path)
  s~charOut(.JSON~toJSON(rec))
  s~close
  .NewshellLog~event('KEPT' job~name job~state 'in' path)
  return path

/* Every kept record, oldest first. */
::method records
  expose dir
  list = .Array~new
  names = .File~new(dir'/jobs')~list
  if names == .nil then return list
  do n over names~sortWith(.CaselessComparator~new)
    if n~right(5) \== '.json' then iterate
    s = .Stream~new(dir'/jobs/'n)
    if s~open('READ') \= 'READY:' then iterate
    text = s~charIn(1, s~chars); s~close
    rec = parseRecord(text)
    if rec == .nil then do; .NewshellLog~event('SKIPPED unreadable job record' n); iterate; end
    rec['file'] = n
    list~append(rec)
  end
  return list

/* -------------------------------------------------------------- helpers -- */
::routine parseRecord
  use strict arg text
  signal on syntax name bad
  rec = .JSON~fromJSON(text)
  if \rec~isA(.Directory) then return .nil
  return rec
bad:
  return .nil

::routine rebuild
  use strict arg rec, agent
  if rec['kind'] == 'plan' then do
    p = .Plan~new(rec['name'], agent)
    do st over rec['steps']
      s = p~step(st['name'])
      if st['target'] \== '' then do
        t = agent~objectNamed(st['target'])
        if t \== .nil then s~does(t, st['message'], st['args'])
      end
      do c over st['checks']; s~passIf(c[1], c[2]); end
      s~onFail(st['onFail']); s~timeout(st['timeout'])
    end
    p~restoreState(rec['state'], rec['stage'], rec['seconds'], rec['report'])
    return p
  end
  return .StoredWatch~new(rec)

/* A watch read back from the store: its history, nothing to amend. */
::class StoredWatch public inherit ShellObject
::method init
  expose rec origin
  use strict arg rec
  origin = .nil
::method name
  expose rec
  return rec['name']
::method state
  expose rec
  return rec['state']
::method stage
  expose rec
  return rec['stage']
::method report
  expose rec
  return rec['report']
::method event
  expose rec
  return rec['event']
::method settled
  return .true
::method origin
  expose origin
  return origin
::method setOrigin
  expose origin
  use strict arg origin
::method fields
  return .Array~of('name', 'state', 'event')

::routine makeObject
  use strict arg cls, args
  a = args~makeArray(' ')
  select
    when cls~caselessEquals('Mu') then do
      if a~items >= 1 then return .Mu~new(a[1])
      return .Mu~new
    end
    when cls~caselessEquals('Network') then return .Network~new
    when cls~caselessEquals('Services') then return .Services~new
    when cls~caselessEquals('Xtpd') then return .Xtpd~new
    when cls~caselessEquals('Computer') then return .Computer~new
    when cls~caselessEquals('Workspace') then do
      .File~new(a[1])~makeDirs
      return .Workspace~new(a[1])
    end
    when cls~caselessEquals('FileSystem') then return .FileSystem~new(a[1])
    otherwise raise syntax 93.900 array ('provide: class' cls 'is not one an agent may be given')
  end

::routine slug
  use strict arg text
  out = ''
  do i = 1 to min(text~length, 40)
    c = text~subchar(i)
    if c~datatype('A') | c == '.' | c == '_' then out = out || c
    else out = out'-'
  end
  return out
