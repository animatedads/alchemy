/* ShellSecurity.cls - the security manager that authorises shell code
   Architecture: Tom Dyer (24 November 2026): proposals run under the
   security manager, and the security manager performs the authorisation:
   whether ~edit is permitted is decided from the object's path.
   Coding: Claude (Opus 5.5).

   Built on ooRexx's own security manager (Routine~setSecurityManager):
     METHOD       a protected method was called: the policy decides, from
                  principal, class, method and the object's authorityPath.
     COMMAND      a host command      - llm: denied;  console: allowed, logged
     CALL         an external routine - llm: denied;  console: allowed, logged
     STREAM       a stream by name    - llm: denied;  console: allowed, logged
     REQUIRES     ::requires          - llm: denied;  console: allowed, logged
     LOCAL/ENVIRONMENT  a dot name not in the package
                  llm: only ARRAY SHELLCOLLECTION TRUE FALSE NIL ENDOFLINE
                  console: allowed
   What it does not see (found 24 Nov 2026): built-in classes such as .File
   and .Stream, and value(name,, 'ENVIRONMENT'). ProposalCheck still rejects
   those in proposals.
   Trusted code (the shell's own classes) runs unchecked: only the code the
   manager is attached to is checked. That is the point: the objects do the
   I/O, the proposal only asks.

   Policy file (text, one rule per line, '#' comments, first match wins,
   no match = deny):
     verdict principal class method path
     allow   llm       FsFile edit   /tmp
   '*' matches anything. A path matches itself and everything below it
   (/tmp matches /tmp/x, not /tmpx). A path that passes through a symbolic
   link is denied before any rule is read. */
::requires 'ShellObject.cls'
::requires 'ShellLog.cls'

/* --------------------------------------------------------------- policy -- */
::class ShellPolicy public inherit ShellObject
::method current class
  if \.local~hasIndex('NEWSHELL.POLICY') then do
    path = value('NEWSHELL_POLICY',, 'ENVIRONMENT')
    if path == '' then path = filespec('location', .context~package~name)'../etc/newshell.policy'
    .local['NEWSHELL.POLICY'] = self~load(path)
  end
  return .local['NEWSHELL.POLICY']
::method reload class
  .local~remove('NEWSHELL.POLICY')
  return self~current

::method load class
  use strict arg path
  f = .File~new(path)
  if \f~isFile then raise syntax 93.900 array ('No policy file:' path)
  if SysIsFileLink(f~absolutePath) then raise syntax 93.900 array ('Policy file is a symbolic link:' path)
  rules = .Array~new
  s = .Stream~new(f~absolutePath)
  if s~open('READ') \= 'READY:' then raise syntax 93.900 array ('Cannot read policy' path)
  n = 0
  do forever
    line = s~lineIn
    if line == '', s~state \== 'READY' then leave
    n += 1
    line = line~changeStr('09'x, ' ')
    if line~pos('#') > 0 then line = line~left(line~pos('#') - 1)
    if line~strip == '' then iterate
    if line~words \= 5 then do; s~close; raise syntax 93.900 array (path 'line' n': need verdict principal class method path'); end
    parse var line verdict principal cls method rulePath .
    if wordpos(verdict~lower, 'allow deny') = 0 then do; s~close; raise syntax 93.900 array (path 'line' n': verdict is allow or deny'); end
    rules~append(.ShellPolicyRule~new(n, verdict~lower, principal, cls, method, rulePath))
  end
  s~close
  .NewshellLog~event('POLICY loaded' rules~items 'rule(s) from' f~absolutePath)
  return self~new(f~absolutePath, rules)

::method init
  expose path rules
  use strict arg path, rules
::method path
  expose path
  return path
::method rules
  expose rules
  return .ShellCollection~new(rules)
::method fields
  return .Array~of('path', 'ruleCount')
::method ruleCount
  expose rules
  return rules~items

/* Returns the first matching rule, or .nil (deny). */
::method match
  expose rules
  use strict arg principal, cls, method, objPath
  do r over rules
    if r~matches(principal, cls, method, objPath) then return r
  end
  return .nil

::method asTable
  return self~rules~asTable

::class ShellPolicyRule public inherit ShellObject
::method init
  expose line verdict principal cls method path
  use strict arg line, verdict, principal, cls, method, path
  if path \== '*' then path = path~strip('T', '/')
  if path == '' then path = '/'
::method line
  expose line
  return line
::method verdict
  expose verdict
  return verdict
::method principal
  expose principal
  return principal
::method cls
  expose cls
  return cls
::method method
  expose method
  return method
::method path
  expose path
  return path
::method fields
  return .Array~of('line', 'verdict', 'principal', 'cls', 'method', 'path')
::method matches
  expose principal cls method path
  use strict arg p, c, m, objPath
  if principal \== '*', \principal~caselessEquals(p) then return .false
  if cls \== '*', \cls~caselessEquals(c) then return .false
  if method \== '*' then do
    if method~right(1) == '*' then do          -- run:* or run:./* : a prefix
      if \m~caselessAbbrev(method~left(method~length - 1)) then return .false
    end
    else if \method~caselessEquals(m) then return .false
  end
  if path == '*' then return .true
  if objPath == '' then return .false
  if path == '/' then return .true
  return objPath == path | objPath~left(path~length + 1) == path'/'

/* ------------------------------------------------------------- decision -- */
::class ShellDecision public inherit ShellObject
::method init
  expose verdict principal kind target cls method path rule
  use strict arg verdict, principal, kind, target, cls = '', method = '', path = '', rule = ''
::method verdict
  expose verdict
  return verdict
::method principal
  expose principal
  return principal
::method kind
  expose kind
  return kind
::method target
  expose target
  return target
::method path
  expose path
  return path
::method rule
  expose rule
  return rule
::method fields
  return .Array~of('verdict', 'principal', 'kind', 'target', 'path', 'rule')
::method text
  expose verdict principal kind target path rule
  return verdict~upper principal kind target path rule

/* -------------------------------------------------------------- manager -- */
::class ShellSecurityManager public
::method init
  expose principal policy decisions
  use strict arg principal, policy = (.ShellPolicy~current)
  decisions = .Array~new
::method principal
  expose principal
  return principal
::method decisions
  expose decisions
  return .ShellCollection~new(decisions)

::method record private
  expose decisions
  use strict arg d
  decisions~append(d)
  .NewshellLog~event('AUTH' d~text)
  return d

::method refuse private
  use strict arg d
  self~record(d)
  raise syntax 98.948 array ('newshell policy:' d~principal 'may not' d~target d~path)

/* A protected method. */
::method method
  expose principal policy
  use arg info
  obj = info~object
  name = info~name~lower
  cls = obj~class~id
  args = info~arguments
  if args == .nil then args = .Array~new
  objPath = ''
  if obj~hasMethod('AUTHORITYPATH') then objPath = obj~authorityPath(name, args)
  -- an object may name the action more finely: Workspace~run is run:PROGRAM
  if obj~hasMethod('AUTHORITYACTION') then name = obj~authorityAction(name, args)
  target = cls'~'name
  if objPath \== '' then do
    objPath = qualify(objPath)
    link = shellLinkOnPath(objPath)
    if link \== '' then self~refuse(.ShellDecision~new('deny', principal, 'METHOD', target, cls, name, objPath, 'path passes through link' link))
  end
  rule = policy~match(principal, cls, name, objPath)
  if rule == .nil then self~refuse(.ShellDecision~new('deny', principal, 'METHOD', target, cls, name, objPath, 'no rule matches'))
  d = .ShellDecision~new(rule~verdict, principal, 'METHOD', target, cls, name, objPath, 'rule' rule~line)
  if rule~verdict == 'deny' then self~refuse(d)
  self~record(d)
  return 0

::method command
  expose principal
  use arg info
  d = .ShellDecision~new('allow', principal, 'COMMAND', info~address':' info~command~left(60))
  if principal \== 'console' then do; d = .ShellDecision~new('deny', principal, 'COMMAND', d~target); self~refuse(d); end
  self~record(d)
  return 0

::method call
  expose principal
  use arg info
  self~consoleOnly('CALL', info~name)
  return 0
::method stream
  expose principal
  use arg info
  self~consoleOnly('STREAM', info~name)
  return 0
::method requires
  expose principal
  use arg info
  self~consoleOnly('REQUIRES', info~name)
  return 0

::method local
  use arg info
  self~dotName('LOCAL', info~name)
  return 0
::method environment
  use arg info
  self~dotName('ENVIRONMENT', info~name)
  return 0

::method consoleOnly private
  expose principal
  use strict arg kind, target
  if principal == 'console' then self~record(.ShellDecision~new('allow', principal, kind, target))
  else self~refuse(.ShellDecision~new('deny', principal, kind, target))

::method dotName private
  expose principal
  use strict arg kind, name
  if principal == 'console' then return
  if wordpos(name~upper, 'ARRAY SHELLCOLLECTION TRUE FALSE NIL ENDOFLINE') > 0 then return
  self~refuse(.ShellDecision~new('deny', principal, kind, '.'name~lower))

/* The first component of path that is a symbolic link, or ''. */
::routine shellLinkOnPath public
  use strict arg path
  sofar = ''
  do part over path~makeArray('/')
    if part == '' then iterate
    sofar = sofar'/'part
    if SysIsFileLink(sofar) then return sofar
  end
  return ''
