#!/usr/bin/env rexx
/* workflow.rex - Alchemy Workflow v0.1-dev1, from the command line.
 *
 * Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-11-11.
 * Source bin/workflow_env.sh first (REXX_PATH and LD_LIBRARY_PATH for logging, crypto and Body Slam).
 *
 *   rexx bin/workflow.rex steps                     the registered steps, with ~module_version
 *   rexx bin/workflow.rex plan PKGDIR [options]     what would run, in which mode, decided by which rule
 *   rexx bin/workflow.rex run PKGDIR [options]      run it: receipt, ledger, and the failure report
 *   rexx bin/workflow.rex survey LIST [options]     run over every package directory named in LIST
 *                                                   (one per line): one line each, then rule totals
 * Options:
 *   --repo DIR     the checkout (default ALCHEMY_ROOT, else two directories above this package)
 *   --db FILE      Body Slam's database of the estate (for KitRun; default BODYSLAM_DB)
 *   --only "A B"   run only these steps
 *   --rule K=M,... submission-layer rules, e.g. ModuleStamp=enforce,HouseRules.HR-INDEX-LOOP=off
 *   --lane L --to P --parent REQ   where the failure report goes (default lane workflow, to TOM)
 *   --work DIR     scratch and output (default /tmp/alchemy_workflow)
 *   --again        run even when the ledger has judged this tree already
 *   --quiet        the log goes to its file only
 * Exit: 0 PASS or FIXED, 1 WARN, 3 FAIL, 4 a step broke (ERROR), 2 usage.
 */
parse arg cmd rest
signal on syntax name failed
parse source . . me
home = me~left(me~lastPos('/bin/') - 1)
cmd = cmd~lower
opts = .directory~new
pos = .array~new
q = .queue~new
do t over rest~space~makeArray(' ')
  if t \== '' then q~queue(t)
end
do while q~items > 0
  t = q~pull
  if t~left(2) \== '--' then do
    pos~append(t)
    iterate
  end
  key = t~substr(3)~lower
  if wordpos(key, 'again quiet') > 0 then opts[key] = 1
  else do
    v = q~pull
    if v == .nil then call usage
    opts[key] = v
  end
end

repo = opts['repo']
if repo == .nil then repo = value('ALCHEMY_ROOT',, 'ENVIRONMENT')
if repo == '' then repo = .File~new(home || '/../..')~absolutePath
work = opts['work']
if work == .nil then work = '/tmp/alchemy_workflow'
db = opts['db']
if db == .nil then db = value('BODYSLAM_DB',, 'ENVIRONMENT')
out = work || '/out'
call SysMkDir work
call SysMkDir out
call SysMkDir out || '/receipts'

rulebook = .WorkflowRuleBook~new~load(home || '/etc/house.rules')
if opts['rule'] \== .nil then do r over opts['rule']~makeArray(',')
  parse var r k '=' m
  rulebook~add('submission', '*', k~strip, m~strip, 'command line')
end
log = .WorkflowLog~new(out || '/workflow.log', opts['quiet'] == .nil)
registry = .WorkflowRegistry~new~loadList(home || '/etc/steps.list', home)
wf = .Workflow~new('autobuild-shadow', registry, rulebook, log)

select
  when cmd == 'steps' then do
    say 'workflow' wf~name wf~module_version '(' || wf~module_lastChanged || ')'
    do s over wf~ordered
      say '  ' s~stage~left(9) s~id~left(12) s~module_version~left(9) s~module_lastChanged ' ' s~describe
    end
    do u over registry~unavailable
      say '   unavailable:' u
    end
  end
  when cmd == 'plan' then do
    if pos~items < 1 then call usage
    ctx = newContext(pos[1], repo, work, rulebook, db, opts, home)
    do line over wf~plan(ctx)~lines
      say line
    end
  end
  when cmd == 'run' then do
    if pos~items < 1 then call usage
    ctx = newContext(pos[1], repo, work, rulebook, db, opts, home)
    receipt = judge(wf, ctx, opts, out, log, .true)
    log~close
    exit exitFor(receipt)
  end
  when cmd == 'survey' then do
    if pos~items < 1 then call usage
    totals = .directory~new
    verdicts = .directory~new
    s = .stream~new(pos[1])
    if s~open('read shareread') \= 'READY:' then call usage
    list = .array~new
    do while s~lines > 0
      t = s~lineIn~strip
      if t \== '' then if t~left(1) \== '#' then list~append(t)
    end
    s~close
    do dir over list
      ctx = newContext(dir, repo, work, rulebook, db, opts, home)
      receipt = judge(wf, ctx, opts, out, log, .false)
      call bump verdicts, receipt~verdict
      seen = .set~new
      fails = 0
      warns = 0
      do r over receipt~results
        do f over r~findings
          call bump totals, r~stepId || '.' || f~rule f~severity
          if f~severity == 'FAIL' then fails += 1
          if f~severity == 'WARN' then warns += 1
          seen~put(f~rule)
        end
      end
      say receipt~verdict~left(5) ctx~relDir '| FAIL' fails 'WARN' warns '|' seen~makeArray~sort~makeString('L', ' ')
    end
    say '--' list~items 'package(s):' verdicts~allIndexes~sort~makeString('L', ' ') '=' countsOf(verdicts)
    do k over totals~allIndexes~sort
      say '  ' k~left(40) totals[k]
    end
  end
  otherwise call usage
end
log~close
exit 0

newContext: procedure
  use strict arg dir, repo, work, rulebook, db, opts, home
  ctx = .WorkflowContext~new(dir, repo, work, rulebook)
  if db \== .nil then ctx~put('BODYSLAM_DB', db)
  if opts['only'] \== .nil then ctx~put('ONLY', opts['only'])
  homeRel = home
  if home~left(ctx~repoRoot~length + 1) == ctx~repoRoot || '/' then homeRel = home~substr(ctx~repoRoot~length + 2)
  ctx~put('HOME_REL', homeRel)
  return ctx

/* run one package: ledger first, then the workflow, the receipt, the failure report */
judge: procedure
  use strict arg wf, ctx, opts, out, log, show
  tree = ''
  rules = ''
  why = ''
  if .WorkflowHash~available then do
    lines = ''
    do rel over ctx~allFiles
      lines = lines || rel .WorkflowHash~file(ctx~pkgDir || '/' || rel) || '0a'x
    end
    tree = .WorkflowHash~sha256(lines)
    rules = .WorkflowHash~sha256(wf~rulebook~identity)
  end
  else why = 'unhashed:' .WorkflowHash~why '(the ledger cannot recognise a resubmission)'
  ledger = .WorkflowLedger~new(out || '/ledger.words')
  key = .WorkflowLedger~key(tree, wf~module_version || '+' || ctx~setting('ONLY')~space(1, '+'), rules)
  if tree \== '' then if opts['again'] == .nil then do
    before = ledger~find(key)
    if before \== .nil then do
      log~info('already judged' before['WHEN'] || ':' before['VERDICT'] 'for' ctx~relDir || ', receipt' before['RECEIPT'] '(--again to run it again)')
      return .WorkflowLedgerReceipt~new(ctx, before['VERDICT'], before['RECEIPT'])
    end
  end
  receipt = wf~run(ctx)
  receipt~treeHash = tree
  receipt~rulesHash = rules
  receipt~hashNote = why
  stamp = .DateTime~new~isoDate~changeStr('-', '')~changeStr(':', '')~left(15)
  path = out || '/receipts/' || stamp || '_' || ctx~name || '.txt'
  text = receipt~lines~makeString('L', '0a'x)
  s = .stream~new(path)
  s~open('write replace')
  s~lineOut(text)
  if tree \== '' then s~lineOut('receipt sha256' .WorkflowHash~sha256(text))
  s~close
  if tree \== '' then ledger~record(key, receipt~verdict, path)
  if show then do line over receipt~lines
    say line
  end
  log~info('receipt' path)
  report = .WorkflowFailureReport~new(receipt, opt(opts, 'to', 'TOM'), opt(opts, 'lane', 'workflow'), opt(opts, 'parent', ''))
  if report~needed then log~info('failure report' report~write(out || '/outbox'))
  return receipt

exitFor: procedure
  use strict arg receipt
  select
    when receipt~verdict == 'ERROR' then return 4
    when receipt~verdict == 'FAIL' then return 3
    when receipt~verdict == 'WARN' then return 1
    otherwise return 0
  end

opt: procedure
  use strict arg opts, key, default
  v = opts[key]
  if v == .nil then return default
  return v

bump: procedure
  use strict arg d, key
  if d~hasIndex(key) then d[key] = d[key] + 1
  else d[key] = 1
  return

countsOf: procedure
  use strict arg d
  t = ''
  do k over d~allIndexes~sort
    t = t d[k]
  end
  return t~strip

usage:
  say 'usage: rexx bin/workflow.rex steps | plan PKGDIR | run PKGDIR | survey LIST  [--repo DIR] [--db FILE] [--only "A B"] [--rule K=M,...] [--lane L] [--to P] [--parent REQ] [--work DIR] [--again] [--quiet]'
  exit 2

failed:
  c = condition('O')
  say 'workflow: Error' c['CODE'] c['ERRORTEXT']
  say '   ' c['MESSAGE']
  say '    line' c['POSITION'] 'of' c['PROGRAM']
  exit 4

::requires 'AlchemyWorkflow.cls'
::requires 'WorkflowLog.cls'
::requires 'WorkflowHash.cls'
::requires 'WorkflowReport.cls'

/* a receipt the ledger answered: the earlier verdict, no new run */
::class WorkflowLedgerReceipt public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'
::attribute ctx get
::attribute verdict get
::attribute path get
::method init
  expose ctx verdict path
  use strict arg ctx, verdict, path
::method results
  return .array~new
