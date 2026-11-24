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
::requires 'ShellProposal.cls'
::requires 'AnthropicMessages.cls'
::requires 'AnthropicProvider.cls'
::requires 'SecretBroker.cls'
::requires 'ShellLog.cls'

/* ------------------------------------------------------------------ LLM -- */
::class Llm public subclass ShellContext
::constant SECRET_REFERENCE 'newshell.llm.claude'

::method start class
  use strict arg kind = 'claude', model = 'claude-haiku-5-5', keyEnv = 'ANTHROPIC_API_KEY', curl = 'curl'
  if kind~lower \== 'claude' then raise syntax 93.900 array ('Only claude is wired in dev1, not' kind)
  return self~new(kind~lower, model, keyEnv, curl)

::method init
  expose kind model client prompts costUsd keyEnv
  use strict arg kind, model, keyEnv, curl
  self~init:super('llm')
  map = .Directory~new; map[self~SECRET_REFERENCE] = keyEnv
  broker = .SecretBroker~new(.MappedEnvironmentSecretProvider~new(map))
  cfg = .AnthropicRuntimeConfig~new(.AnthropicChannel~direct, broker, self~SECRET_REFERENCE, model, 2048, 90, curl)
  client = .AnthropicMessageClient~new(cfg)
  prompts = 0; costUsd = 0
  .NewshellLog~event('LLM START' kind 'model' model 'key from environment variable' keyEnv)

::method kind
  expose kind
  return kind
::method model
  expose model
  return model
::method prompts
  expose prompts
  return prompts
::method costUsd
  expose costUsd
  return costUsd~format(, 6)
::method fields
  return .Array~of('kind', 'model', 'provided', 'prompts', 'costUsd')
::method provided
  return shellJoin(self~names)
/* Round 1 drafts; round 2 checks the draft against the source of every
   method it calls and replies with the final code. Nothing runs here. */
::method prompt
  use strict arg task
  if self~names~items = 0 then raise syntax 93.900 array ('Provide an object first')
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
