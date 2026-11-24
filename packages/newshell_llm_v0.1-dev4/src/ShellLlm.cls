/* ShellLlm.cls - an LLM as a shell object that proposes code; a person runs it.
   Architecture: Tom Dyer (24 November 2026): start an LLM, provide it shell
   objects, prompt it, get back a proposal built from DO OVER on those
   objects, run the proposal, get a list back. The LLM checks the source of
   the methods it proposes to use against the live objects; that source is
   cached.
   Coding: Claude (Opus 5.5).

   claude = .Llm~start('claude')
   claude~provide('fs', .FileSystem~new('/srv/proto'))
   p = claude~prompt('find largest file')     -- proposes; runs nothing
   p~~table~~show~~sources
   list = p~run                                -- only now does code run
   list~~table

   Estate parts: oorexx_ai_provider_anthropic v0.5 (AnthropicMessageClient;
   the key comes from the Secret Broker by reference and reaches curl only
   on stdin), oorexx_secret_broker v0.2, oorexx_crypto v0.1 (SHA-512 of
   method sources), oorexx_logging v0.7 (progress and receipts).

   Where the limits are, in order of strength:
     1. The provided objects are read-only: they have no method that
        changes anything.
     2. A proposal does nothing until a person sends it ~run.
     3. It runs under ADDRESS NEWSHELL_NONE, so a command string is not
        executed (rc 30).
     4. ProposalCheck rejects ADDRESS, CALL, INTERPRET, streams, Sys*
        functions, directives, reflection (~class, ~send, ...), dot names
        other than .Array/.ShellCollection, and calls to methods that no
        provided object or built-in class has.
     5. ~run refuses if any method source it was checked against changed.
   4 is a lint, not a sandbox. Not in dev1: a time limit on ~run. */
::requires 'ShellObject.cls'
::requires 'AnthropicMessages.cls'
::requires 'AnthropicProvider.cls'
::requires 'SecretBroker.cls'
::requires 'crypto.cls'
::requires 'ShellLog.cls'
::requires 'ShellSecurity.cls'

/* --------------------------------------------------------- source cache -- */
/* One entry per (receiver class, method). The source comes from the live
   object (instanceMethod), so it is what will actually run. */
::class MethodSourceCache public inherit ShellObject
::method current class
  if \.local~hasIndex('NEWSHELL.SOURCES') then .local['NEWSHELL.SOURCES'] = self~new
  return .local['NEWSHELL.SOURCES']
::method init
  expose entries hits misses
  entries = .Directory~new; hits = 0; misses = 0
::method lookup
  expose entries hits misses
  use strict arg sample, name
  key = sample~class~id'~'name~upper
  entry = entries[key]
  if entry \== .nil then do
    if entry~matches(sample) then do; hits += 1; return entry; end
    .NewshellLog~event('SOURCE CHANGED' key '- re-reading')
  end
  misses += 1
  entry = .MethodSource~new(sample, name)
  entries[key] = entry
  return entry
::method hits
  expose hits
  return hits
::method misses
  expose misses
  return misses
::method entries
  expose entries
  return entries~items
::method fields
  return .Array~of('entries', 'hits', 'misses')

::class MethodSource public inherit ShellObject
::method init
  expose receiver name definedIn kind lines text digest
  use strict arg sample, nameArg
  name = nameArg~lower
  receiver = sample~class~id
  m = sample~instanceMethod(nameArg)
  definedIn = m~scope~id
  lines = m~source
  select
    when m~isAttribute then kind = 'attribute'
    when m~isConstant then kind = 'constant'
    when lines~items = 0 then kind = 'native'
    otherwise kind = 'method'
  end
  text = lines~makeString('LINE', '0a'x)
  digest = .CryptoHash~hashString(receiver'~'name'0a'x || text)
::method matches
  expose text
  use strict arg sample
  return sample~instanceMethod(self~name)~source~makeString('LINE', '0a'x) == text
::method receiver
  expose receiver
  return receiver
::method name
  expose name
  return name
::method definedIn
  expose definedIn
  return definedIn
::method kind
  expose kind
  return kind
::method lines
  expose lines
  return lines
::method digest
  expose digest
  return digest
::method digest16
  expose digest
  return digest~left(16)
::method listing
  expose receiver name definedIn kind lines
  out = .MutableBuffer~new
  out~append('--', receiver'~'name, '('kind', defined in' definedIn')', .endOfLine)
  if kind == 'attribute' then out~append('   attribute: returns the value it holds', .endOfLine)
  else if kind == 'constant' then out~append('   constant', .endOfLine)
  else if kind == 'native' then out~append('   native method, no Rexx source', .endOfLine)
  else do l over lines; out~append('   ', l, .endOfLine); end
  return out~string
::method fields
  return .Array~of('receiver', 'name', 'definedIn', 'kind', 'digest16')

/* ------------------------------------------------------------------ LLM -- */
::class Llm public inherit ShellObject
::constant SECRET_REFERENCE 'newshell.llm.claude'

::method start class
  use strict arg kind = 'claude', model = 'claude-haiku-5-5', keyEnv = 'ANTHROPIC_API_KEY', curl = 'curl'
  if kind~lower \== 'claude' then raise syntax 93.900 array ('Only claude is wired in dev1, not' kind)
  return self~new(kind~lower, model, keyEnv, curl)

::method init
  expose kind model client names objects prompts costUsd keyEnv
  use strict arg kind, model, keyEnv, curl
  map = .Directory~new; map[self~SECRET_REFERENCE] = keyEnv
  broker = .SecretBroker~new(.MappedEnvironmentSecretProvider~new(map))
  cfg = .AnthropicRuntimeConfig~new(.AnthropicChannel~direct, broker, self~SECRET_REFERENCE, model, 2048, 90, curl)
  client = .AnthropicMessageClient~new(cfg)
  names = .Array~new; objects = .Directory~new
  prompts = 0; costUsd = 0
  .NewshellLog~event('LLM START' kind 'model' model 'key from environment variable' keyEnv)

::method provide
  expose names objects
  use strict arg name, obj
  if \name~datatype('V') then raise syntax 93.900 array ('Not a variable name:' name)
  if \obj~isA(.ShellObject) then raise syntax 93.900 array (name 'is not a shell object')
  if objects~hasIndex(name~lower) then names~delete(names~index(name~lower))
  names~append(name~lower); objects[name~lower] = obj
  .NewshellLog~event('PROVIDE' name~lower 'a' obj~class~id 'identity' obj~identity)
  return self

::method kind
  expose kind
  return kind
::method model
  expose model
  return model
::method provided
  expose names
  return shellJoin(names)
::method prompts
  expose prompts
  return prompts
::method costUsd
  expose costUsd
  return costUsd~format(, 6)
::method fields
  return .Array~of('kind', 'model', 'provided', 'prompts', 'costUsd')
::method names
  expose names
  return names~copy
::method objects
  expose names objects
  list = .Array~new
  do n over names; list~append(objects[n]); end
  return list

/* Objects a proposal might send messages to: each provided object, the
   samples each one names (relatedSamples, two levels), and an empty
   ShellCollection. Each entry is (label, object); one per class. */
::method labelledSamples
  expose names objects
  list = .Array~new; classes = .Set~new
  todo = .Queue~new
  do n over names; todo~queue(.Array~of(n, objects[n], 0)); end
  do while todo~items > 0
    item = todo~pull
    obj = item[2]
    if classes~hasIndex(obj~class~id) then iterate
    classes~put(obj~class~id)
    list~append(item)
    if item[3] < 2, obj~hasMethod('RELATEDSAMPLES') then
      do pair over obj~relatedSamples; todo~queue(.Array~of(pair[1], pair[2], item[3] + 1)); end
  end
  list~append(.Array~of('.ShellCollection~new(anArray)', .ShellCollection~new, 0))
  return list

::method samples
  list = .Array~new
  do item over self~labelledSamples; list~append(item[2]); end
  return list

::method systemPrompt
  expose names objects
  out = .MutableBuffer~new
  out~append('You write ooRexx 5 code for NewShell. Your code is the body of a routine.', .endOfLine)
  out~append('The shell has already set these variables:', .endOfLine, .endOfLine)
  do item over self~labelledSamples
    out~append(item[2]~describe(item[1]), .endOfLine)
  end
  out~append('Rules:', .endOfLine)
  out~append('1. Use only those variables, their methods, ooRexx built-in functions, and String and Array methods.', .endOfLine)
  out~append('2. The only dot names you may use are .Array, .ShellCollection, .true, .false and .nil.', .endOfLine)
  out~append('3. Do not use ADDRESS, CALL, INTERPRET, SIGNAL, PULL, directives (::), streams or commands.', .endOfLine)
  out~append('   Change files only through the protected methods listed. The security manager decides at run time whether each call is allowed; a refusal stops the run.', .endOfLine)
  out~append('4. End with RETURN. When the answer is a list of objects, return .ShellCollection~new(anArray) holding the objects themselves.', .endOfLine)
  out~append('5. Do not name a variable RESULT, RC or SIGL: ooRexx sets them itself (a message instruction such as x~append(y) sets RESULT).', .endOfLine)
  out~append('6. Reply with the code only: no explanation, no markdown fences, no USE ARG line.', .endOfLine, .endOfLine)
  out~append('Example (a different task: list the .log files):', .endOfLine)
  out~append('  found = .Array~new', .endOfLine)
  out~append('  do f over fs', .endOfLine)
  out~append("    if f~extension == 'log' then found~append(f)", .endOfLine)
  out~append('  end', .endOfLine)
  out~append('  return .ShellCollection~new(found)', .endOfLine)
  return out~string

/* Round 1 drafts; round 2 checks the draft against the source of every
   method it calls and replies with the final code. Nothing runs here. */
::method prompt
  expose names
  use strict arg task
  if names~items = 0 then raise syntax 93.900 array ('Provide an object first')
  system = self~systemPrompt
  .NewshellLog~event('PROMPT' quoteShort(task) '- round 1 (draft)')
  draft = self~ask(system, 'Task:' task)
  proposal = .Proposal~new(self, task, draft)
  sources = proposal~resolveSources
  review = .MutableBuffer~new
  review~append('Task: ', task, .endOfLine, .endOfLine, 'Your draft:', .endOfLine, draft, .endOfLine, .endOfLine)
  review~append('Here is the source of every method your draft calls, read from the live objects.', .endOfLine)
  review~append('Check each call against its source: what it returns, its units, its arguments.', .endOfLine)
  do s over sources; review~append(s~listing); end
  if proposal~unknownMethods~items > 0 then
    review~append('No provided object or built-in class has these methods:' shellJoin(proposal~unknownMethods)'. Do not call them.', .endOfLine)
  review~append(.endOfLine, 'Reply with the final code only.')
  .NewshellLog~event('PROMPT round 2 (review against' sources~items 'method sources)')
  final = self~ask(system, review~string)
  proposal~setFinal(final)
  -- one repair round: the shell's own problems go back to the model once
  if proposal~state == 'REJECTED' then do
    fix = .MutableBuffer~new
    fix~append('Task: ', task, .endOfLine, .endOfLine, 'Your code:', .endOfLine, proposal~code, .endOfLine, .endOfLine)
    fix~append('The shell rejected it:', .endOfLine)
    do p over proposal~problemList; fix~append('- ', p, .endOfLine); end
    fix~append(.endOfLine, 'Reply with corrected code only, keeping to the rules.')
    .NewshellLog~event('PROMPT round 3 (repair' proposal~problems 'problem(s))')
    proposal~setFinal(self~ask(system, fix~string))
  end
  return proposal

/* A plan stopped or a watch fired (called on the job's own thread).
   PASSED plans are only posted to the inbox unless notifyOnPass is set;
   anything else goes to the model with the job's report, and its short
   diagnosis is kept on the job. The model is told; it never polls. */
::method notifyOnPass
  expose notifyOnPass
  use strict arg value = .nil
  if value == .nil then do; if var('notifyOnPass') = 0 then return .false; return notifyOnPass; end
  notifyOnPass = value
  return self

::method jobFinished
  use strict arg job
  if job~state == 'PASSED', \self~notifyOnPass, \(job~hasMethod('NOTIFY') & job~notify == 'always') then return
  report = job~report
  .NewshellLog~event('NOTIFY' self~kind 'about' job~name '(' || report~length 'chars, state' job~state')')
  -- the stopped job is provided as job, so the follow-up can amend it
  self~provide('job', job)
  task = .MutableBuffer~new
  task~append(report, .endOfLine)
  task~append('The job above has stopped (or fired). You registered it. Decide the next single action and write the code for it:', .endOfLine)
  task~append('- If a step DIED (was killed) or the cause is not clear from the report, do not guess: write a review plan whose steps only look (ws~list, ws~tail), with plan~notify(''always'') so you are sent what they found.', .endOfLine)
  task~append('- If you know what was left behind, write a cleanup plan (ws~remove, or the project''s own clean target), with plan~notify(''always'').', .endOfLine)
  task~append('- If the workspace is clean, write the amended plan: amend the plan that originally failed (job, or jobs~find(name) for one in the History); amend(newName) copies its steps; insert or change steps so the failure cannot recur.', .endOfLine)
  task~append('- Do not plan a second review that looks at the same things: if a review in the History did not settle it, clean up what it showed.', .endOfLine)
  task~append('- If nothing needs doing, return .nil.', .endOfLine)
  task~append('Start with a comment of at most 4 lines: what happened, and what this code does next. Submit the plan with jobs~submit(...) and return it.', .endOfLine)
  p = self~prompt(task~string)
  p~setOrigin(job)
  job~setDiagnosis(leadingComment(p~code))
  job~setFollowUp(p)
  .NewshellLog~event('FOLLOW-UP for' job~name':' p~state', ' || p~lines 'lines')
  return

::method ask private
  expose client model prompts costUsd
  use strict arg system, text
  req = .AnthropicMessageRequest~new(model, system, .true, 2048)
  req~thinkingOff
  req~addText(text)
  reply = client~send(req)
  prompts += 1
  if \reply~ok then do
    .NewshellLog~event('REPLY FAILED' reply~code reply~message)
    raise syntax 93.900 array ('LLM call failed:' reply~code reply~message)
  end
  cost = reply~costUsd(.AnthropicModelCatalog~new)
  if cost == '' then cost = 0
  costUsd += cost
  .NewshellLog~event('REPLY ok in' reply~inputTokens 'out' reply~outputTokens 'cache read' reply~cacheReadTokens 'ms' reply~latencyMs 'usd' cost~format(, 6))
  return stripFences(reply~text)

/* ------------------------------------------------------------- proposal -- */
::class Proposal public inherit ShellObject
::method init
  expose llm task draft final state problems sources unknown notes ranItems
  use strict arg llm, task, draft
  final = draft; state = 'DRAFT'; problems = .Array~new; sources = .Array~new
  unknown = .Array~new; notes = .Array~new; ranItems = ''

/* The job this proposal follows up; jobs it submits remember it. */
::method origin
  expose origin
  if var('origin') = 0 then return .nil
  return origin
::method setOrigin
  expose origin
  use strict arg origin

::method setFinal
  expose final state
  use strict arg text
  final = text
  state = 'PROPOSED'
  self~check
  return self

::method task
  expose task
  return task
::method model
  expose llm
  return llm~model
::method state
  expose state
  return state
::method lines
  expose final
  return final~countStr('0a'x) + 1
::method methodsChecked
  expose sources
  return sources~items
::method problems
  expose problems
  return problems~items
::method problemList
  expose problems
  return problems~copy
::method unknownMethods
  expose unknown
  return unknown
::method code
  expose final
  return final
::method draft
  expose draft
  return draft
::method fields
  return .Array~of('task', 'model', 'state', 'lines', 'methodsChecked', 'problems')

::method show
  expose final problems notes
  n = 0
  do l over final~makeArray('0a'x)
    n += 1
    say n~right(3) l
  end
  do p over problems; say 'PROBLEM:' p; end
  do x over notes; say 'note:' x; end

::method sources
  expose sources
  .ShellCollection~new(sources)~table

/* Find the source of each method the code calls, through the cache. */
::method resolveSources
  expose llm final sources unknown
  cache = .MethodSourceCache~current
  sources = .Array~new; unknown = .Array~new
  samples = llm~samples
  -- built-in instances, plus the two class objects a proposal may name
  builtin = .Array~of('', .Array~new, .MutableBuffer~new, .Directory~new, .Array, .ShellCollection)
  do name over messageNames(scrub(final))
    found = .false
    do sample over samples
      if sample~hasMethod(name) then do
        found = .true
        entry = cache~lookup(sample, name)
        if sources~index(entry) == .nil then sources~append(entry)
      end
    end
    if \found then do b over builtin
      if b~hasMethod(name) then do; found = .true; leave; end
    end
    if \found then unknown~append(name~lower)
  end
  .NewshellLog~event('SOURCES' sources~items 'checked, cache hits' cache~hits 'misses' cache~misses)
  return sources

::method check
  expose final state problems unknown notes
  -- the shell sets the variables; drop a USE ARG line if the model wrote one
  lines = final~makeArray('0a'x)
  if lines~items > 0, lines[1]~strip~word(1)~upper == 'USE' then do
    lines~delete(1); final = lines~makeString('LINE', '0a'x)
    notes~append('dropped the USE ARG line; the shell sets the variables')
  end
  problems = .ProposalCheck~new~problems(final)
  self~resolveSources
  do u over unknown; problems~append('calls ~'u', which no provided object or built-in class has'); end
  if problems~items = 0 then state = 'CHECKED'; else state = 'REJECTED'
  .NewshellLog~event('CHECK' state problems~items 'problem(s)')
  return problems~items = 0

::method decisions
  expose manager
  if var('manager') = 0 then return .ShellCollection~new
  return manager~decisions

::method run
  expose llm final state problems sources ranItems manager
  if state == 'REJECTED' then raise syntax 93.900 array ('Proposal was rejected:' problems[1])
  if state \== 'CHECKED' & state \== 'RAN' then raise syntax 93.900 array ('Proposal is' state', not CHECKED')
  -- the code was checked against these sources; refuse if any has changed
  samples = llm~samples
  do s over sources
    do sample over samples
      if sample~class~id == s~receiver, \s~matches(sample) then
        raise syntax 93.900 array ('Source of' s~receiver'~'s~name 'changed since the check; prompt again')
    end
  end
  src = .Array~new
  argLine = ''
  do n over llm~names; argLine = argLine',' n; end
  src~append('use strict arg' argLine~substr(3))
  src~append('address NEWSHELL_NONE')
  do l over final~makeArray('0a'x); src~append(l); end
  routine = .Routine~new('proposal', src, .context~package)
  manager = .ShellSecurityManager~new('llm')
  routine~setSecurityManager(manager)
  .NewshellLog~event('RUN start under the security manager, principal llm, policy' .ShellPolicy~current~path)
  t0 = time('E')
  if self~origin \== .nil then .local['NEWSHELL.ORIGIN'] = self~origin
  signal on syntax name failed
  value = routine~callWith(llm~objects)
  signal off syntax
  .local~remove('NEWSHELL.ORIGIN')
  if value == .nil then do
    state = 'RAN'; ranItems = 0
    .NewshellLog~event('RUN done in' (time('E') - t0)~format(, 3)'s, returned nothing')
    return .nil
  end
  state = 'RAN'
  if value~isA(.ShellCollection) then ranItems = value~items~items
  else ranItems = 1
  .NewshellLog~event('RUN done in' (time('E') - t0)~format(, 3)'s, returned a' value~class~id)
  return value
failed:
  .local~remove('NEWSHELL.ORIGIN')
  state = 'FAILED'
  c = condition('O')
  .NewshellLog~event('RUN failed' c~code c~message)
  raise propagate

::class ProposalCheck public
::method problems
  use strict arg code
  found = .Array~new
  text = scrub(code)
  if text~pos('::') > 0 then found~append('directives (::) are not allowed')
  banned = .Set~of('ADDRESS', 'CALL', 'INTERPRET', 'SIGNAL', 'PULL', 'REPLY', 'USE', 'PUSH', 'QUEUE')
  funcs = .Set~of('LINEOUT', 'CHAROUT', 'LINEIN', 'CHARIN', 'LINES', 'CHARS', 'STREAM', 'VALUE', 'DIRECTORY', 'RXFUNCADD', 'RXFUNCDROP')
  dots = .Set~of('ARRAY', 'SHELLCOLLECTION', 'TRUE', 'FALSE', 'NIL', 'ENDOFLINE')
  msgs = .Set~of('CLASS', 'SEND', 'SENDWITH', 'START', 'STARTWITH', 'SETMETHOD', 'UNSETMETHOD', -
                 'UNKNOWN', 'INIT', 'INSTANCEMETHOD', 'INSTANCEMETHODS', 'OBJECTNAME=', 'CALLWITH', 'NEW', -
                 'LAUNCH', 'EXECUTE', 'POLL')
  sawReturn = .false
  do clause over clauses(text)
    -- a keyword counts where an instruction can start: first, or after THEN/ELSE/OTHERWISE
    words = clause~upper~translate(' ', ':')~space~makeArray(' ')
    prev = ''
    do w over words
      if prev == '' | wordpos(prev, 'THEN ELSE OTHERWISE') > 0 then do
        if w == 'PARSE' then nop
        else if banned~hasIndex(w) then found~append(w 'is not allowed:' clause~strip)
        if w == 'RETURN' then sawReturn = .true
      end
      if prev == 'PARSE' & wordpos(w, 'PULL LINEIN') > 0 then found~append('PARSE' w 'is not allowed:' clause~strip)
      prev = w
    end
    if clause~strip~left(2) == "''" then found~append('a bare string is a command:' clause~strip)
  end
  do w over callNames(text)
    if funcs~hasIndex(w) | w~left(3) == 'SYS' then found~append(w'() is not allowed')
  end
  do d over dotNames(text)
    if \dots~hasIndex(d) then found~append('.'d~lower 'is not allowed')
  end
  do m over messageNames(text)
    if msgs~hasIndex(m) then do
      if m == 'NEW' & allowedNew(text) then iterate
      found~append('~'m~lower 'is not allowed')
    end
  end
  -- ooRexx sets these itself: x~append(y) as an instruction sets RESULT
  do v over specialVariables(text)
    found~append(v~lower 'is set by ooRexx itself; use another variable name')
  end
  if \sawReturn then found~append('no RETURN')
  return found

/* ------------------------------------------------------------- helpers -- */
/* Blank out string literals (kept as '') and comments, keeping line breaks. */
::routine scrub public
  use strict arg code
  out = .MutableBuffer~new
  i = 1; n = code~length; depth = 0
  do while i <= n
    c = code~subchar(i)
    if depth > 0 then do
      if code~substr(i, 2) == '*/' then do; depth -= 1; i += 2; iterate; end
      if code~substr(i, 2) == '/*' then do; depth += 1; i += 2; iterate; end
      if c == '0a'x then out~append(c)
      i += 1; iterate
    end
    if code~substr(i, 2) == '/*' then do; depth = 1; i += 2; iterate; end
    if code~substr(i, 2) == '--' then do
      e = code~pos('0a'x, i); if e = 0 then e = n + 1
      i = e; iterate
    end
    if c == "'" | c == '"' then do
      j = i + 1
      do forever
        j = code~pos(c, j)
        if j = 0 then do; j = n; leave; end
        if code~subchar(j + 1) == c then do; j += 2; iterate; end
        leave
      end
      out~append("''"); i = j + 1; iterate
    end
    out~append(c); i += 1
  end
  return out~string

::routine clauses
  use strict arg text
  list = .Array~new
  do line over text~makeArray('0a'x)
    do part over line~makeArray(';')
      if part~strip \== '' then list~append(part)
    end
  end
  return list

::routine isNameChar
  use strict arg c
  if c == '' then return .false
  return c~datatype('A') | pos(c, '_!?.') > 0

::routine charAt
  use strict arg text, i
  if i < 1 | i > text~length then return ''
  return text~subchar(i)

/* Message names: the symbol after ~ or ~~ */
::routine messageNames public
  use strict arg text
  names = .Array~new
  p = text~pos('~')
  do while p > 0
    q = p + 1
    if text~subchar(q) == '~' then q += 1
    e = q
    do while e <= text~length, isNameChar(text~subchar(e)) & text~subchar(e) \== '.'
      e += 1
    end
    if text~subchar(e) == '=' then e += 1
    name = text~substr(q, e - q)~upper
    if name \== '', names~index(name) == .nil then names~append(name)
    p = text~pos('~', max(e, p + 1))
  end
  return names

/* Environment symbols: a . that starts a name, not part of one or a number */
::routine dotNames
  use strict arg text
  names = .Array~new
  p = text~pos('.')
  do while p > 0
    before = charAt(text, p - 1)
    if \isNameChar(before) then do
      e = p + 1
      do while e <= text~length, isNameChar(text~subchar(e)) & text~subchar(e) \== '.'
        e += 1
      end
      name = text~substr(p + 1, e - p - 1)~upper
      if name \== '', name~left(1)~datatype('M'), names~index(name) == .nil then names~append(name)
    end
    p = text~pos('.', p + 1)
  end
  return names

/* Function calls: a name directly followed by ( and not after ~ */
::routine callNames
  use strict arg text
  names = .Array~new
  p = text~pos('(')
  do while p > 0
    e = p - 1
    s = e
    do while s >= 1, isNameChar(text~subchar(s)) & text~subchar(s) \== '.'
      s -= 1
    end
    name = text~substr(s + 1, e - s)~upper
    if name \== '', charAt(text, s) \== '~', names~index(name) == .nil then names~append(name)
    p = text~pos('(', p + 1)
  end
  return names

/* RESULT, RC and SIGL used as variables (not as a message name after ~) */
::routine specialVariables
  use strict arg text
  found = .Array~new
  t = text~upper
  do v over .Array~of('RESULT', 'RC', 'SIGL')
    p = t~pos(v)
    do while p > 0
      before = charAt(t, p - 1); after = charAt(t, p + v~length)
      if (p = 1 | \isNameChar(before)) & before \== '~' & \isNameChar(after) then do
        found~append(v); leave
      end
      p = t~pos(v, p + 1)
    end
  end
  return found

/* ~new is allowed only straight after .Array or .ShellCollection */
::routine allowedNew
  use strict arg text
  t = text~upper~space(0)
  p = t~pos('~NEW')
  do while p > 0
    if t~substr(1, p - 1)~right(6) \== '.ARRAY' & t~substr(1, p - 1)~right(16) \== '.SHELLCOLLECTION' then return .false
    p = t~pos('~NEW', p + 1)
  end
  return .true

/* The comment block a follow-up starts with: its diagnosis. */
::routine leadingComment public
  use strict arg code
  out = .Array~new
  inBlock = .false
  do l over code~makeArray('0a'x)
    t = l~strip
    if inBlock then do
      if t~pos('*/') > 0 then do; out~append(t~left(t~pos('*/') - 1)~strip('L', '*')~strip); leave; end
      out~append(t~strip('L', '*')~strip); iterate
    end
    if t~left(2) == '--' then do; out~append(t~substr(3)~strip); iterate; end
    if t~left(2) == '/*' then do
      body = t~substr(3)
      if body~pos('*/') > 0 then do; out~append(body~left(body~pos('*/') - 1)~strip); iterate; end
      out~append(body~strip); inBlock = .true; iterate
    end
    if t == '' & out~items = 0 then iterate
    leave
  end
  return out~makeString('LINE', '0a'x)

::routine stripFences
  use strict arg text
  keep = .Array~new
  do l over text~makeArray('0a'x)
    if l~strip~left(3) == '```' then iterate
    keep~append(l)
  end
  return keep~makeString('LINE', '0a'x)~strip('B', '0a'x)

::routine quoteShort
  use strict arg text
  if text~length > 60 then text = text~left(57)'...'
  return '"'text'"'
