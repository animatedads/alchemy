/* test_workflow.rex - Alchemy Workflow v0.1-dev1 qualification.
 *
 * Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-11-11.
 * Run from the package directory with bin/workflow_env.sh sourced:
 *   rexx tests/test_workflow.rex
 * The fixtures (tests/fixtures) are a package that keeps every rule and one that breaks each, on a known
 * line. KitRun is not exercised here (it needs Body Slam's database); bin/workflow.rex runs it.
 */
signal on syntax name failed
parse source . . me
home = me~left(me~lastPos('/tests/') - 1)
fx = home || '/tests/fixtures'
work = '/tmp/alchemy_workflow_test'
address system 'rm -rf' work '&& mkdir -p' work
.local~wf.pass = 0
.local~wf.fail = 0

say '== 1 every class answers ~module_version and ~module_lastChanged'
classes = .array~of(.Workflow, .WorkflowStep, .WorkflowRegistry, .WorkflowRuleBook, .WorkflowContext, .WorkflowPlan, -
  .WorkflowReceipt, .WorkflowStepResult, .WorkflowFinding, .WorkflowSource, .WorkflowLog, .WorkflowLogFileTarget, -
  .WorkflowHash, .WorkflowFailureReport, .WorkflowLedger, .ManifestStep, .HouseRulesStep, .ModuleStampStep)
do c over classes
  call check c~module_version == '0.1-dev1', c~id 'module_version' c~module_version
  call check c~module_lastChanged == '2026-11-11', c~id 'module_lastChanged' c~module_lastChanged
end

say '== 2 family and version from a directory name'
call checkSplit 'alchemy_website_publisher_v0.4', 'alchemy_website_publisher', '0.4'
call checkSplit 'oorexx_slam450_flightplanner_v0.1-dev1', 'oorexx_slam450_flightplanner', '0.1-dev1'
call checkSplit 'oorexx_maths', 'oorexx_maths', ''
call checkSplit 'virtual_ryta_hardworld_v0.31_work', 'virtual_ryta_hardworld', '0.31_work'

say '== 3 the source reader'
good = .WorkflowSource~new(fx || '/good_pkg_v0.2/src/Good.cls')
call check good~code[2]~pos('result') = 0, 'a comment is blanked in code[]'
call check good~code[23]~pos('result') = 0, 'a string is blanked in code[] (line 23)'
call check good~code[23]~length = good~raw[23]~length, 'code[] keeps the line length'
call check good~traps~items = 0, "'0d0a'x and '0101'b are not traps (traps" good~traps~items || ')'
call check good~ofKind('CLASS')~items = 2, 'two classes found'
call check good~members('Good')['MODULE_VERSION'] \== .nil, 'members by name'
call check good~constantValue(good~members('Good')['MODULE_VERSION']) == '0.2', 'constant value read'
bad = .WorkflowSource~new(fx || '/bad_pkg_v0.4/src/Bad.cls')
call check trapAt(bad, 19) == 'BINARY', "'|'b on line 19 is a binary-literal trap"
call check trapAt(bad, 20) == 'CALL', "'" || '"' || "'(sep) on line 20 is a call trap"
unc = .WorkflowSource~new(fx || '/bad_pkg_v0.4/src/Unclosed.cls')
call check trapAt(unc, 1) == 'COMMENT', 'the slash-asterisk inside a comment is found (line 1)'

say '== 4 the rule book: the highest layer that matches decides'
rb = .WorkflowRuleBook~new
rb~add('house', '*', 'ModuleStamp', 'report', 't:1')
rb~add('family', 'bad_pkg', 'ModuleStamp', 'off', 't:2')
rb~add('house', '*', 'ModuleStamp', 'enforce', 't:3')
cg = .WorkflowContext~new(fx || '/good_pkg_v0.2', fx, work, rb)
cb = .WorkflowContext~new(fx || '/bad_pkg_v0.4', fx, work, rb)
call check rb~decide('ModuleStamp', cg)['MODE'] == 'enforce', 'house: the last line in a layer decides'
call check rb~decide('ModuleStamp', cb)['MODE'] == 'off', 'family beats house'
rb~add('package', 'bad_pkg_v0.4', 'ModuleStamp', 'report', 't:4')
call check rb~decide('ModuleStamp', cb)['MODE'] == 'report', 'package beats family'
rb~add('submission', '*', 'ModuleStamp', 'enforce', 'cmd')
d = rb~decide('ModuleStamp', cb)
call check d['MODE'] == 'enforce', 'submission beats package'
call check d['BY'] == 'submission rule cmd', 'and says which rule decided:' d['BY']
call check rb~decide('NoSuchStep', cb, 'enforce')['BY'] == 'default', 'no rule: the default'
call check cb~relDir == 'bad_pkg_v0.4', 'relDir' cb~relDir
call check cb~manifest~isA(.Directory), 'manifest parsed'

say '== 5 a package that keeps every rule: PASS'
enforce = .WorkflowRuleBook~new
rec = runOn(fx || '/good_pkg_v0.2', fx, work, enforce)
call check rec~verdict == 'PASS', 'good_pkg verdict' rec~verdict
do r over rec~results
  do f over r~findings
    call check .false, 'unexpected finding on good_pkg:' f~text
  end
end

say '== 6 a package that breaks each rule: each found on its line'
rec = runOn(fx || '/bad_pkg_v0.4', fx, work, enforce)
call check rec~verdict == 'FAIL', 'bad_pkg verdict' rec~verdict
expect = .array~of('Manifest MF-SCHEMA WARN integration.json:1', 'Manifest MF-NAME FAIL integration.json:2', -
  'Manifest MF-PUBLISH FAIL integration.json:9', 'Manifest MF-CWD FAIL integration.json:5', -
  'Manifest MF-PROGRAM FAIL integration.json:6', 'Manifest MF-PROGRAM WARN integration.json:7', -
  'Manifest MF-PYTHON WARN integration.json:6', -
  'HouseRules HR-EXPOSE-FIRST FAIL src/Bad.cls:8', 'HouseRules HR-PRIVATE FAIL src/Bad.cls:10', -
  'HouseRules HR-RESULT FAIL src/Bad.cls:15', 'HouseRules HR-INDEX-LOOP WARN src/Bad.cls:16', -
  'HouseRules HR-PLUS-ZERO FAIL src/Bad.cls:17', 'HouseRules HR-LITERAL-HEX FAIL src/Bad.cls:19', -
  'HouseRules HR-LITERAL-CALL FAIL src/Bad.cls:20', 'HouseRules HR-COMMENT FAIL src/Unclosed.cls:1', -
  'HouseRules HR-CREDITS WARN README.md', -
  'ModuleStamp MS-VERSION FAIL src/Bad.cls:3', 'ModuleStamp MS-MISSING FAIL src/Bad.cls:23')
got = .array~new
do r over rec~results
  do f over r~findings
    got~append(r~stepId f~rule f~severity f~where)
  end
end
do e over expect
  call check got~hasItem(e), 'found:' e
end
do g over got
  if \expect~hasItem(g) then call check .false, 'not expected:' g
end
call check got~items = expect~items, expect~items 'findings expected,' got~items 'found'

say '== 7 report mode: the FAILs become WARNs, and each says it'
rp = .WorkflowRuleBook~new
do s over .array~of('Manifest', 'HouseRules', 'ModuleStamp')
  rp~add('house', '*', s, 'report', 't')
end
rec = runOn(fx || '/bad_pkg_v0.4', fx, work, rp)
call check rec~verdict == 'WARN', 'verdict in report mode' rec~verdict
call check rec~findingsAtLeast('FAIL')~items = 0, 'no FAIL left'
f = rec~findingsAtLeast('WARN')[1][2]
call check rec~findingsAtLeast('WARN')~items = expect~items, 'every finding still reported'

say '== 8 a rule switched off for one family; a FAIL made a WARN'
ro = .WorkflowRuleBook~new
ro~add('family', 'bad_pkg', 'HouseRules.HR-INDEX-LOOP', 'off', 't:1')
ro~add('family', 'bad_pkg', 'HouseRules.HR-PRIVATE', 'warn', 't:2')
rec = runOn(fx || '/bad_pkg_v0.4', fx, work, ro)
hr = resultOf(rec, 'HouseRules')
rules = ''
sev = ''
do f over hr~findings
  rules = rules f~rule
  if f~rule == 'HR-PRIVATE' then sev = f~severity f~decidedBy
end
call check wordpos('HR-INDEX-LOOP', rules) = 0, 'HR-INDEX-LOOP switched off'
call check hr~notes~makeString('L', ' ')~pos('switched off by family rule t:1') > 0, 'and the note says by which rule'
call check sev~word(1) == 'WARN', 'HR-PRIVATE made a WARN:' sev

say '== 9 a step that breaks is ERROR, charged to the tooling'
reg = .WorkflowRegistry~new
reg~register(.ManifestStep~new)
reg~register(.BrokenStep~new)
log = .WorkflowLog~new(work || '/t9.log', .false)
wf = .Workflow~new('test', reg, .WorkflowRuleBook~new, log)
rec = wf~run(.WorkflowContext~new(fx || '/good_pkg_v0.2', fx, work, wf~rulebook))
log~close
call check rec~verdict == 'ERROR', 'verdict' rec~verdict
call check resultOf(rec, 'Manifest')~verdict == 'PASS', 'the other steps still ran'
body = .WorkflowFailureReport~new(rec, 'CLAUDE', 'slam-450')~body
call check body~pos('defect in the tooling, not in your package') > 0, 'the report says it is the tooling'
call check body~pos('Broken 0.1-dev1') > 0, 'and names the step and its version'

say '== 10 the failure report tells the task what it did wrong'
rec = runOn(fx || '/bad_pkg_v0.4', fx, work, enforce)
rpt = .WorkflowFailureReport~new(rec, 'CLAUDE', 'slam-450', 'REQ-1')
call check rpt~needed, 'a FAIL needs a report'
body = rpt~body
call check body~pos('Architecture: Tom Dyer') > 0, 'credits: architecture'
call check body~pos('Message written by: Alchemy Workflow 0.1-dev1') > 0, 'credits: who wrote it'
call check body~pos('What failed, and what to do:') > 0, 'the FAIL section'
call check body~pos('where: src/Bad.cls:10') > 0, 'file:line given'
call check body~pos('--only HouseRules --again') > 0, 'a command to see it again'
lines = body~makeArray('0a'x)
cmdLines = 0
do l over lines
  if l~left(5) == 'rexx ' then do
    cmdLines += 1
    call check l~right(1) \== '.', 'a command line ends without a period'
  end
end
call check cmdLines = got~items, 'one command line per finding (' || cmdLines || ')'
call check rpt~subject~pos('FAIL for bad_pkg_v0.4: 13 to fix, 5 warning(s)') > 0, 'subject:' rpt~subject
path = rpt~write(work || '/outbox')
s = .stream~new(path)
s~open('read')
j = .json~fromJson(s~charIn(1, s~chars))
s~close
call check j['parentRequestId'] == 'REQ-1', 'outbox: parent request'
call check j['nudge']~pos('in your mailbox on lane slam-450') > 0, 'outbox: the nudge carries only where to look'
call check j['nudge']~pos('HR-') = 0, 'outbox: the nudge carries no finding'

say '== 11 the plan runs nothing, and says why a step is skipped'
reg = .WorkflowRegistry~new~loadList(home || '/etc/steps.list', home)
rb = .WorkflowRuleBook~new
rb~add('house', '*', 'ModuleStamp', 'off', 't:1')
wf = .Workflow~new('test', reg, rb, .WorkflowLog~new(work || '/t11.log', .false))
cx = .WorkflowContext~new(fx || '/good_pkg_v0.2', fx, work, rb)
cx~put('ONLY', 'Manifest ModuleStamp KitRun')
skips = .directory~new
do row over wf~plan(cx)~rows
  skips[row['STEP']~id] = row['SKIP']
end
call check skips['Manifest'] == '', 'Manifest planned'
call check skips['HouseRules']~pos('not asked for') > 0, 'HouseRules: not asked for'
call check skips['ModuleStamp'] == 'switched off by house rule t:1', 'ModuleStamp:' skips['ModuleStamp']
call check skips['KitRun']~pos('Body Slam') > 0, 'KitRun:' skips['KitRun']
call check reg~steps~items + reg~unavailable~items = 4, 'four steps listed'

say '== 12 the ledger remembers a judgement'
ld = .WorkflowLedger~new(work || '/ledger.words')
k = .WorkflowLedger~key('aa', '0.1-dev1+', 'bb')
call check ld~find(k) == .nil, 'nothing before'
ld~record(k, 'WARN', '/x/r.txt')
call check ld~find(k)['VERDICT'] == 'WARN', 'found after'
call check ld~find(.WorkflowLedger~key('ab', '0.1-dev1+', 'bb')) == .nil, 'another tree is not found'

say '== 13 hashing goes through the Foreign Runtime'
if .WorkflowHash~available then do
  call check .WorkflowHash~sha256('abc') == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', 'SHA-256 of abc'
end
else say '   SKIP: provider not installed here (' || .WorkflowHash~why || ')'

say '== 14 the progress log goes through ooRexx Logging'
lg = .WorkflowLog~new(work || '/t14.log', .false)
lg~info('one')
lg~warn('two')
lg~close
s = .stream~new(work || '/t14.log')
s~open('read')
n = 0
do while s~lines > 0
  t = s~lineIn
  n += 1
end
s~close
call check n = 2, 'two log lines written (' || n || ')'
call check t~pos('WARN  two') > 0, 'level and text in the line:' t

say
say 'checks:' .wf.pass 'passed,' .wf.fail 'failed'
if .wf.fail > 0 then exit 1
exit 0

runOn: procedure
  use strict arg dir, repo, work, rb
  reg = .WorkflowRegistry~new
  reg~register(.ManifestStep~new)
  reg~register(.HouseRulesStep~new)
  reg~register(.ModuleStampStep~new)
  log = .WorkflowLog~new(work || '/run.log', .false)
  wf = .Workflow~new('test', reg, rb, log)
  rec = wf~run(.WorkflowContext~new(dir, repo, work, rb))
  log~close
  return rec

resultOf: procedure
  use strict arg rec, id
  do r over rec~results
    if r~stepId == id then return r
  end
  return .nil

trapAt: procedure
  use strict arg src, n
  do t over src~traps
    if t['LINE'] = n then return t['KIND']
  end
  return ''

checkSplit: procedure
  use strict arg name, fam, ver
  fv = .WorkflowContext~splitName(name)
  call check fv[1] == fam & fv[2] == ver, name '->' fv[1] fv[2]
  return

check: procedure
  use strict arg ok, what
  if ok then do
    .local~wf.pass = .wf.pass + 1
    return
  end
  .local~wf.fail = .wf.fail + 1
  say '   FAIL' what
  return

failed:
  c = condition('O')
  say 'test_workflow: Error' c['CODE'] c['ERRORTEXT']
  say '   ' c['MESSAGE']
  say '    line' c['POSITION'] 'of' c['PROGRAM']
  exit 2

::requires 'AlchemyWorkflow.cls'
::requires 'WorkflowLog.cls'
::requires 'WorkflowHash.cls'
::requires 'WorkflowReport.cls'
::requires 'ManifestStep.cls'
::requires 'HouseRulesStep.cls'
::requires 'ModuleStampStep.cls'

/* a step that breaks, for test 9 */
::class BrokenStep public subclass WorkflowStep
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'
::method id
  return 'Broken'
::method run
  use strict arg ctx, res
  x = .nil~noSuchMethod
