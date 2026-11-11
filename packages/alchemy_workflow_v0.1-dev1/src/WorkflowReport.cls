/* WorkflowReport.cls - Alchemy Workflow v0.1-dev1: telling the task what it did wrong, and remembering
 * what has been judged.
 *
 * Architecture: Tom Dyer (a failure sends a message back to the task telling it what it did wrong).
 * Code: Claude (Opus 5.5), 2026-11-11.
 *
 * WorkflowFailureReport turns a receipt into a mailbox message for the lane that submitted the package:
 * one numbered entry per FAIL (then the WARNs), each with the step and its version, the rule and the layer
 * that set it, where (file:line), what was found, the fix, and the command that shows it again. A step
 * that broke (ERROR) is reported as the workflow's defect, not the author's. The nudge is one sentence
 * and carries no content: the content is in the mailbox (the ALCHEMYFETCH contract).
 *
 * v0.1-dev1 writes the message to an outbox file (one .json file per message in out/outbox: recipientId, componentId,
 * parentRequestId, subject, body, nudge); whoever runs the workflow posts it. An ooRexx mailbox client
 * that posts it directly is the next increment.
 *
 * WorkflowLedger remembers each judgement by (tree sha256, workflow version, rule book sha256), so an
 * identical resubmission gets the earlier receipt back instead of a second run.
 */
::requires 'AlchemyWorkflow.cls'
::requires 'json.cls'

::class WorkflowFailureReport public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'
::attribute receipt get
::attribute to get
::attribute lane get
::attribute parent get

::method init
  expose receipt to lane parent
  use strict arg receipt, to = 'TOM', lane = '', parent = ''

::method needed
  expose receipt
  return .WorkflowStepResult~rank(receipt~verdict) >= .WorkflowStepResult~rank('WARN')

::method subject
  expose receipt
  fails = receipt~findingsAtLeast('FAIL')~items
  warns = receipt~findingsAtLeast('WARN')~items - fails
  return 'Workflow' receipt~verdict 'for' receipt~ctx~relDir || ':' fails 'to fix,' warns 'warning(s)'

::method body
  expose receipt to lane
  wf = receipt~workflow
  ctx = receipt~ctx
  b = .array~new
  b~append('For:' to || '. From: Alchemy Workflow' wf~module_version || ', lane' lane || '.')
  b~append('')
  b~append('Architecture: Tom Dyer')
  b~append('Coding: Claude (Opus 5.5) (Alchemy Workflow' wf~module_version || ')')
  b~append('Message written by: Alchemy Workflow' wf~module_version || ', from a template by Claude (Opus 5.5)')
  b~append('')
  b~append('Verdict:' receipt~verdict 'for' ctx~relDir '(workflow' wf~name wf~module_version || ').')
  if receipt~treeHash \== '' then b~append('Tree sha256:' receipt~treeHash)
  b~append('')
  b~append('To run the checks below yourself, first, from the repository root:')
  b~append('. ' || ctx~setting('HOME_REL', 'packages/alchemy_workflow_v0.1-dev1') || '/bin/workflow_env.sh')
  b~append('')
  errors = .array~new
  do r over receipt~results
    if r~verdict == 'ERROR' then errors~append(r)
  end
  if errors~items > 0 then do
    b~append('The workflow itself broke on these steps. This is a defect in the tooling, not in your package:')
    do r over errors
      b~append('- step' r~stepId r~stepVersion || ':' r~notes[r~notes~items])
    end
    b~append('')
  end
  n = 0
  fails = receipt~findingsAtLeast('FAIL')
  if fails~items > 0 then b~append('What failed, and what to do:')
  do pair over fails
    n += 1
    self~entry(b, n, pair[1], pair[2])
  end
  warns = .array~new
  do pair over receipt~findingsAtLeast('WARN')
    if pair[2]~severity == 'WARN' then warns~append(pair)
  end
  if warns~items > 0 then do
    if fails~items > 0 then b~append('')
    b~append('Warnings (they do not stop the build):')
  end
  do pair over warns
    n += 1
    self~entry(b, n, pair[1], pair[2])
  end
  b~append('')
  if fails~items > 0 then b~append('Fix exactly these and resubmit. A resubmission with the same tree is not run again: it gets this receipt back.')
  else b~append('Nothing blocks the build. The warnings are worth fixing while you are in the files.')
  return b~makeString('L', '0a'x)

::method entry
  use strict arg b, n, r, f
  b~append(n || '.' f~severity f~rule '- step' r~stepId r~stepVersion '(' || r~mode || ', decided by' r~decidedBy || ')')
  b~append('   where:' f~where)
  b~append('   found:' f~evidence)
  b~append('   fix:  ' f~fix)
  if f~decidedBy \== '' then b~append('   severity:' f~decidedBy)
  b~append('   check it yourself:')
  b~append(f~reproduce)

::method nudge
  expose receipt lane
  return 'Alchemy Workflow: a' receipt~verdict 'for' receipt~ctx~relDir 'is in your mailbox on lane' lane || '; read it, fix what it names, resubmit.'

/* the outbox file; returns its path */
::method write
  expose receipt to lane parent
  use strict arg outboxDir
  call SysMkDir outboxDir
  stamp = .DateTime~new~isoDate~changeStr('-', '')~changeStr(':', '')~left(15)
  path = outboxDir || '/' || stamp || '_' || receipt~ctx~name || '.json'
  d = .directory~new
  d['recipientId'] = .JsonString~new(to)
  d['componentId'] = .JsonString~new(lane)
  d['parentRequestId'] = .JsonString~new(parent)
  d['subject'] = .JsonString~new(self~subject)
  d['body'] = .JsonString~new(self~body)
  d['nudge'] = .JsonString~new(self~nudge)
  d['verdict'] = .JsonString~new(receipt~verdict)
  call SysFileDelete path
  s = .stream~new(path)
  s~open('write replace')
  s~charOut(.json~toJson(d))
  s~lineOut('')
  s~close
  return path

/* ------------------------------------------------------------------------------------------------ */
::class WorkflowLedger public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'
::attribute path get

::method init
  expose path
  use strict arg path

::method key class
  use strict arg treeHash, workflowVersion, rulesHash
  return treeHash || '|' || workflowVersion || '|' || rulesHash

/* the earlier judgement for this key: a directory (VERDICT, RECEIPT, WHEN), or .nil */
::method find
  expose path
  use strict arg key
  if \SysFileExists(path) then return .nil
  s = .stream~new(path)
  s~open('read shareread')
  found = .nil
  do while s~lines > 0
    parse value s~lineIn with t '|' w '|' h '|' verdict '|' receipt '|' when
    if t || '|' || w || '|' || h \== key then iterate
    found = .directory~new
    found['VERDICT'] = verdict
    found['RECEIPT'] = receipt
    found['WHEN'] = when
  end
  s~close
  return found

::method record
  expose path
  use strict arg key, verdict, receiptPath
  s = .stream~new(path)
  s~open('write append')
  s~lineOut(key || '|' || verdict || '|' || receiptPath || '|' || .DateTime~new~isoDate)
  s~close
