/* AlchemyWorkflow.cls - Alchemy Workflow v0.1-dev1: the workflow planner the build runs on.
 *
 * Architecture: Tom Dyer (11 Nov 2026: an autobuild should have a workflow planner where a workflow is
 * laid out for planning; workflow objects are registered into it, each easily maintained; one stamps
 * ~module_version and ~module_lastChanged on classes as they go through, others do the tidy-up; rules
 * decide what applies; a failure sends a message back to the task telling it what it did wrong).
 * Code: Claude (Opus 5.5), 2026-11-11.
 *
 * The objects:
 *   Workflow            a named list of stages, with a registry of steps and a rule book
 *   WorkflowStep        the protocol every step follows: id, stage, describe, skipReason(ctx),
 *                       intends(ctx), run(ctx, result). Steps live in their own files (src/steps)
 *   WorkflowRegistry    the steps registered into a workflow, loaded from etc/steps.list
 *   WorkflowRuleBook    layered rules: house, area, family, package, submission. The highest layer that
 *                       matches decides, and the receipt says which rule decided
 *   WorkflowContext     the candidate package: where it is, its family and version, its manifest, its
 *                       ooRexx files (each read once, as a WorkflowSource)
 *   WorkflowPlan        what would run, in which mode, decided by which rule, and what each step would do.
 *                       "plan" runs nothing
 *   WorkflowStepResult  PASS, FIXED, WARN, FAIL, SKIP or ERROR, with findings
 *   WorkflowFinding     rule id, severity, file:line, evidence, fix, and the command that shows it again
 *   WorkflowReceipt     every step's result, the package's tree hash, the rule book's hash, the verdict
 *
 * ERROR means the step broke, not the package: the failure report says so and names the step's version,
 * so a defect in the tooling is never charged to the package's author.
 *
 * Every class answers ~module_version and ~module_lastChanged (Tom's rule, REQ-00003463/65).
 */
::requires 'WorkflowSource.cls'
::requires 'json.cls'

::routine wfq public
  use strict arg s
  return "'" || s~changeStr("'", "'\''") || "'"

/* ------------------------------------------------------------------------------------------------ */
::class WorkflowFinding public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'
::attribute rule get
::attribute severity
::attribute file get
::attribute line get
::attribute evidence get
::attribute fix get
::attribute reproduce
::attribute decidedBy

::method init
  expose rule severity file line evidence fix reproduce decidedBy
  use strict arg rule, severity, file, line, evidence, fix, reproduce = ''
  decidedBy = ''

::method where
  expose file line
  if line == '' then return file
  if line = 0 then return file
  return file || ':' || line

::method text
  expose rule severity evidence fix decidedBy
  t = severity rule self~where '|' evidence '| fix:' fix
  if decidedBy \== '' then t = t '| severity set by' decidedBy
  return t

/* ------------------------------------------------------------------------------------------------ */
::class WorkflowStepResult public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'
::attribute stepId get
::attribute stepVersion get
::attribute verdict
::attribute findings get
::attribute notes get
::attribute mode
::attribute decidedBy
::attribute seconds

::method rank class
  use strict arg v
  select
    when v == 'ERROR' then return 4
    when v == 'FAIL' then return 3
    when v == 'WARN' then return 2
    when v == 'FIXED' then return 1
    otherwise return 0
  end

::method init
  expose stepId stepVersion verdict findings notes mode decidedBy seconds
  use strict arg stepId, stepVersion
  verdict = 'PASS'
  findings = .array~new
  notes = .array~new
  mode = ''
  decidedBy = ''
  seconds = 0

::method add
  expose findings
  use strict arg finding
  findings~append(finding)
  self~settle
  return finding

::method replaceFindings
  expose findings
  use strict arg list
  findings = list
  self~settle

::method note
  expose notes
  use strict arg text
  notes~append(text)

/* the verdict from the findings; SKIP and ERROR are set by the workflow and stay */
::method settle
  expose verdict findings
  if verdict == 'SKIP' then return verdict
  if verdict == 'ERROR' then return verdict
  v = 'PASS'
  do f over findings
    if .WorkflowStepResult~rank(f~severity) > .WorkflowStepResult~rank(v) then v = f~severity
  end
  verdict = v
  return v

/* ------------------------------------------------------------------------------------------------ */
::class WorkflowRuleBook public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'
::attribute rules get

::method layers class
  return .array~of('house', 'area', 'family', 'package', 'submission')

::method layerRank class
  use strict arg layer
  n = 0
  do l over self~layers
    n += 1
    if l == layer then return n
  end
  return 0

::method init
  expose rules
  rules = .array~new

/* lines "layer | match | key | mode"; # starts a comment */
::method load
  use strict arg path
  s = .stream~new(path)
  if s~open('read shareread') \= 'READY:' then raise syntax 98.900 array('Workflow: cannot read rule book' path)
  n = 0
  do while s~lines > 0
    n += 1
    t = s~lineIn
    if t~pos('#') > 0 then t = t~left(t~pos('#') - 1)
    if t~strip == '' then iterate
    parse var t layer '|' match '|' key '|' mode
    self~add(layer~strip~lower, match~strip, key~strip, mode~strip, path~substr(path~lastPos('/') + 1) || ':' || n)
  end
  s~close
  return self

::method add
  expose rules
  use strict arg layer, match, key, mode, origin = 'submission'
  if .WorkflowRuleBook~layerRank(layer) = 0 then raise syntax 98.900 array('Workflow rule' origin || ': unknown layer' layer '(house, area, family, package or submission)')
  r = .directory~new
  r['LAYER'] = layer
  r['MATCH'] = match
  r['KEY'] = key~upper
  r['MODE'] = mode
  r['ORIGIN'] = origin
  rules~append(r)
  return r

::method matches
  use strict arg r, ctx
  m = r['MATCH']
  if m == '*' then return .true
  select
    when r['LAYER'] == 'area' then return m == ctx~area
    when r['LAYER'] == 'family' then return m == ctx~family
    when r['LAYER'] == 'package' then return m == ctx~name
    otherwise return .true
  end

/* the rule that decides key for this package: the highest layer that matches; in a layer, the last line */
::method decide
  expose rules
  use strict arg key, ctx, default = ''
  key = key~upper
  best = .nil
  bestRank = 0
  do r over rules
    if r['KEY'] \== key then iterate
    if \self~matches(r, ctx) then iterate
    k = .WorkflowRuleBook~layerRank(r['LAYER'])
    if k >= bestRank then do
      best = r
      bestRank = k
    end
  end
  d = .directory~new
  if best == .nil then do
    d['MODE'] = default
    d['BY'] = 'default'
    return d
  end
  d['MODE'] = best['MODE']
  d['BY'] = best['LAYER'] 'rule' best['ORIGIN']
  return d

/* the rule book as text, for its hash in the receipt */
::method identity
  expose rules
  t = ''
  do r over rules
    t = t || r['LAYER'] '|' r['MATCH'] '|' r['KEY'] '|' r['MODE'] || '0a'x
  end
  return t

/* ------------------------------------------------------------------------------------------------ */
::class WorkflowContext public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'
::attribute pkgDir get
::attribute repoRoot get
::attribute work get
::attribute name get
::attribute family get
::attribute version get
::attribute area get
::attribute relDir get
::attribute manifest get
::attribute manifestError get
::attribute manifestPath get
::attribute rulebook get
::attribute settings get

/* family and version from a directory name: alchemy_website_publisher_v0.4 -> (alchemy_website_publisher, 0.4) */
::method splitName class
  use strict arg name
  p = name~length
  do while p > 0
    p = name~lastPos('_v', p)
    if p = 0 then leave
    if datatype(name~subchar(p + 2), 'W') then return .array~of(name~left(p - 1), name~substr(p + 2))
    p -= 1
  end
  return .array~of(name, '')

::method init
  expose pkgDir repoRoot work name family version area relDir manifest manifestError manifestPath rulebook settings files sources
  use strict arg pkgDir, repoRoot, work, rulebook
  pkgDir = .File~new(pkgDir)~absolutePath~strip('T', '/')
  repoRoot = .File~new(repoRoot)~absolutePath~strip('T', '/')
  work = work~strip('T', '/')
  name = pkgDir~substr(pkgDir~lastPos('/') + 1)
  fv = .WorkflowContext~splitName(name)
  family = fv[1]
  version = fv[2]
  relDir = pkgDir
  if pkgDir~left(repoRoot~length + 1) == repoRoot || '/' then relDir = pkgDir~substr(repoRoot~length + 2)
  area = 'root'
  if relDir~pos('/') > 0 then area = relDir~left(relDir~pos('/') - 1)
  settings = .directory~new
  files = .nil
  sources = .directory~new
  manifest = .nil
  manifestError = ''
  manifestPath = pkgDir || '/integration.json'
  if \SysFileExists(manifestPath) then manifestError = 'no integration.json'
  else manifest = self~readJson(manifestPath)

::method readJson
  expose manifestError
  use strict arg f
  signal on syntax name bad
  s = .stream~new(f)
  s~open('read shareread')
  body = s~charIn(1, s~chars)
  s~close
  return .json~fromJson(body)
bad:
  c = condition('O')
  manifestError = 'integration.json does not parse:' c['MESSAGE']
  return .nil

::method setting
  expose settings
  use strict arg key, default = ''
  v = settings[key~upper]
  if v == .nil then return default
  return v

::method put
  expose settings
  use strict arg key, value
  settings[key~upper] = value

/* the package's ooRexx files (.cls .rex .rexx .orx), relative, sorted; less the prefixes named by the
   rule book key FILES.EXCLUDE (words) */
::method sourceFiles
  expose files pkgDir rulebook
  if files \== .nil then return files
  ex = rulebook~decide('FILES.EXCLUDE', self, '')['MODE']
  all = .array~new
  call SysFileTree pkgDir || '/*', 'f.', 'FSO'
  do i = 1 to f.0
    rel = f.i~substr(pkgDir~length + 2)
    ext = rel~substr(rel~lastPos('.') + 1)~lower
    if wordpos(ext, 'cls rex rexx orx') = 0 then iterate
    skip = .false
    do w over ex~makeArray(' ')
      if w \== '' then if rel~left(w~length) == w then skip = .true
    end
    if \skip then all~append(rel)
  end
  files = all~sort
  return files

/* every file of the package, relative and sorted: what the tree hash covers */
::method allFiles
  expose pkgDir
  all = .array~new
  call SysFileTree pkgDir || '/*', 'f.', 'FSO'
  do i = 1 to f.0
    all~append(f.i~substr(pkgDir~length + 2))
  end
  return all~sort

::method source
  expose sources pkgDir
  use strict arg rel
  s = sources[rel]
  if s == .nil then do
    s = .WorkflowSource~new(pkgDir || '/' || rel)
    sources[rel] = s
  end
  return s

/* the date (YYYY-MM-DD) of the last commit that changed rel; '' when git does not know it */
::method lastChanged
  expose repoRoot relDir
  use strict arg rel
  cmd = 'git -C' wfq(repoRoot) 'log -1 --format=%cs --' wfq(relDir || '/' || rel) '2>/dev/null'
  address system cmd with output stem o.
  if o.0 = 0 then return ''
  return o.1~strip

/* ------------------------------------------------------------------------------------------------ */
::class WorkflowStep public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'

::method id
  return self~class~id

::method stage
  return 'inspect'

::method describe
  return 'a workflow step'

/* '' when the step applies to this package, else why not */
::method skipReason
  use strict arg ctx
  return ''

/* what the step would do to this package (shown by plan) */
::method intends
  use strict arg ctx
  return self~describe

::method run
  use strict arg ctx, res
  raise syntax 98.900 array('Workflow step' self~id 'has no run method')

::method finding
  use strict arg rule, severity, file, line, evidence, fix
  return .WorkflowFinding~new(rule, severity, file, line, evidence, fix)

/* ------------------------------------------------------------------------------------------------ */
::class WorkflowRegistry public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'
::attribute steps get
::attribute unavailable get

::method init
  expose steps unavailable
  steps = .array~new
  unavailable = .array~new

::method register
  expose steps
  use strict arg step
  do s over steps
    if s~id~upper == step~id~upper then raise syntax 98.900 array('Workflow registry: step' step~id 'is registered twice')
  end
  steps~append(step)
  return step

/* a step from its file; a step that cannot load is listed as unavailable, with why, and the rest go on */
::method load
  expose unavailable
  use strict arg file, className
  step = self~tryLoad(file, className)
  if step~isA(.String) then do
    unavailable~append(className '|' file '|' step)
    return .nil
  end
  return self~register(step)

::method tryLoad
  use strict arg file, className
  signal on syntax name broken
  pkg = .context~package~loadPackage(file)
  cls = pkg~findClass(className)
  if cls == .nil then return 'no class' className 'in the file'
  return cls~new
broken:
  c = condition('O')
  return 'does not load: Error' c['CODE'] c['MESSAGE']

/* lines "file | className" (file relative to home); # starts a comment */
::method loadList
  use strict arg listPath, home
  s = .stream~new(listPath)
  if s~open('read shareread') \= 'READY:' then raise syntax 98.900 array('Workflow: cannot read step list' listPath)
  do while s~lines > 0
    t = s~lineIn
    if t~pos('#') > 0 then t = t~left(t~pos('#') - 1)
    if t~strip == '' then iterate
    parse var t file '|' className
    self~load(home || '/' || file~strip, className~strip)
  end
  s~close
  return self

/* ------------------------------------------------------------------------------------------------ */
::class Workflow public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'
::attribute name get
::attribute stages get
::attribute registry get
::attribute rulebook get
::attribute log get

::method init
  expose name stages registry rulebook log
  use strict arg name, registry, rulebook, log
  stages = .array~of('intake', 'inspect', 'normalise', 'stamp', 'qualify', 'publish', 'report')

/* the steps in stage order; inside a stage, in the order they were registered */
::method ordered
  expose name stages registry
  out = .array~new
  do st over stages
    do s over registry~steps
      if s~stage == st then out~append(s)
    end
  end
  do s over registry~steps
    if stages~hasItem(s~stage) then iterate
    raise syntax 98.900 array('Workflow' name || ': step' s~id 'names stage' s~stage || ', not one of' stages~makeString('L', ' '))
  end
  return out

/* what would run: nothing is run */
::method plan
  expose rulebook
  use strict arg ctx
  only = ctx~setting('ONLY')~upper
  rows = .array~new
  do s over self~ordered
    d = rulebook~decide(s~id, ctx, 'enforce')
    if wordpos(d['MODE'], 'enforce report off') = 0 then raise syntax 98.900 array('Workflow rule for' s~id 'says' d['MODE'] '(' || d['BY'] || '); the modes are enforce, report and off')
    row = .directory~new
    row['STEP'] = s
    row['MODE'] = d['MODE']
    row['BY'] = d['BY']
    row['SKIP'] = ''
    if d['MODE'] == 'off' then row['SKIP'] = 'switched off by' d['BY']
    if row['SKIP'] == '' then if only \== '' then if wordpos(s~id~upper, only) = 0 then row['SKIP'] = 'not asked for (--only' only~lower || ')'
    if row['SKIP'] == '' then row['SKIP'] = s~skipReason(ctx)
    row['INTENDS'] = s~intends(ctx)
    rows~append(row)
  end
  return .WorkflowPlan~new(self, ctx, rows)

::method run
  expose log
  use strict arg ctx
  plan = self~plan(ctx)
  receipt = .WorkflowReceipt~new(self, ctx, plan)
  log~info('workflow' self~name self~module_version 'on' ctx~relDir || ':' plan~rows~items 'steps planned')
  do row over plan~rows
    s = row['STEP']
    res = .WorkflowStepResult~new(s~id, s~module_version)
    res~mode = row['MODE']
    res~decidedBy = row['BY']
    if row['SKIP'] \== '' then do
      res~verdict = 'SKIP'
      res~note(row['SKIP'])
      log~info('step' s~id 'skipped:' row['SKIP'])
      receipt~add(res)
      iterate
    end
    log~info('step' s~id s~module_version 'starts:' row['MODE'] || ', decided by' row['BY'])
    t0 = .DateTime~new
    self~runStep(s, ctx, res)
    self~applyRules(res, ctx)
    res~seconds = (.DateTime~new - t0)~totalSeconds~format(, 2)
    if res~verdict == 'ERROR' then log~error('step' s~id 'broke:' res~notes[res~notes~items])
    else log~info('step' s~id res~verdict '|' res~findings~items 'finding(s) |' res~seconds 's')
    receipt~add(res)
  end
  receipt~finish
  log~info('workflow verdict' receipt~verdict 'for' ctx~relDir)
  return receipt

/* a step that raises a condition gets ERROR: the step broke, not the package */
::method runStep
  use strict arg s, ctx, res
  signal on syntax name broken
  s~run(ctx, res)
  return
broken:
  c = condition('O')
  res~verdict = 'ERROR'
  res~note('the step itself failed, not the package: Error' c['CODE'] c['MESSAGE'] '(line' c['POSITION'] 'of' c['PROGRAM'] || ')')
  return

/* finding-level rules (STEP.RULE: off or warn) and the step's report mode; the reproduce command */
::method applyRules
  expose rulebook
  use strict arg res, ctx
  if res~verdict == 'ERROR' then return
  keep = .array~new
  do f over res~findings
    d = rulebook~decide(res~stepId || '.' || f~rule, ctx, '')
    if d['MODE'] == 'off' then do
      res~note(f~rule 'at' f~where 'switched off by' d['BY'])
      iterate
    end
    if d['MODE'] == 'warn' then if f~severity == 'FAIL' then do
      f~severity = 'WARN'
      f~decidedBy = 'a FAIL, made a WARN by' d['BY']
    end
    if res~mode == 'report' then if f~severity == 'FAIL' then do
      f~severity = 'WARN'
      f~decidedBy = 'a FAIL when enforced; a WARN while the step is in report mode (' || res~decidedBy || ')'
    end
    if f~reproduce == '' then f~reproduce = 'rexx' ctx~setting('HOME_REL', 'packages/alchemy_workflow_v0.1-dev1') || '/bin/workflow.rex run' ctx~relDir '--only' res~stepId '--again'
    keep~append(f)
  end
  res~replaceFindings(keep)

/* ------------------------------------------------------------------------------------------------ */
::class WorkflowPlan public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'
::attribute workflow get
::attribute ctx get
::attribute rows get

::method init
  expose workflow ctx rows
  use strict arg workflow, ctx, rows

::method lines
  expose workflow ctx rows
  out = .array~new
  out~append('plan | workflow' workflow~name workflow~module_version '|' ctx~relDir '| family' ctx~family 'version' ctx~version '| area' ctx~area)
  if ctx~manifestError \== '' then out~append('     | manifest:' ctx~manifestError)
  n = 0
  do row over rows
    n += 1
    s = row['STEP']
    if row['SKIP'] \== '' then state = 'skip (' || row['SKIP'] || ')'
    else state = row['MODE']
    out~append(n~right(2) s~stage~left(9) s~id~left(11) s~module_version~left(9) state '| decided by' row['BY'])
    if row['SKIP'] == '' then out~append('   would:' row['INTENDS'])
  end
  do u over workflow~registry~unavailable
    out~append('   unavailable step:' u)
  end
  return out

/* ------------------------------------------------------------------------------------------------ */
::class WorkflowReceipt public
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'
::attribute workflow get
::attribute ctx get
::attribute plan get
::attribute results get
::attribute verdict get
::attribute started get
::attribute finished get
::attribute treeHash
::attribute rulesHash
::attribute digest
::attribute hashNote

::method init
  expose workflow ctx plan results verdict started finished treeHash rulesHash digest hashNote
  use strict arg workflow, ctx, plan
  results = .array~new
  verdict = 'PASS'
  started = .DateTime~new~isoDate
  finished = ''
  treeHash = ''
  rulesHash = ''
  digest = ''
  hashNote = ''

::method add
  expose results
  use strict arg res
  results~append(res)

::method finish
  expose results verdict finished
  v = 'PASS'
  do r over results
    if .WorkflowStepResult~rank(r~verdict) > .WorkflowStepResult~rank(v) then v = r~verdict
  end
  verdict = v
  finished = .DateTime~new~isoDate

/* findings at or above a severity, across all steps, each with its step */
::method findingsAtLeast
  expose results
  use strict arg severity
  out = .array~new
  floor = .WorkflowStepResult~rank(severity)
  do r over results
    do f over r~findings
      if .WorkflowStepResult~rank(f~severity) >= floor then out~append(.array~of(r, f))
    end
  end
  return out

::method lines
  expose workflow ctx results verdict started finished treeHash rulesHash hashNote
  out = .array~new
  out~append('receipt | workflow' workflow~name workflow~module_version '| verdict' verdict)
  out~append('package |' ctx~relDir '| family' ctx~family '| version' ctx~version '| area' ctx~area)
  if treeHash \== '' then out~append('tree    | sha256' treeHash)
  if rulesHash \== '' then out~append('rules   | sha256' rulesHash)
  if hashNote \== '' then out~append('hashing |' hashNote)
  out~append('time    |' started '->' finished)
  do r over results
    out~append('step    |' r~stepId r~stepVersion '|' r~verdict '|' r~mode '(' || r~decidedBy || ') |' r~seconds 's |' r~findings~items 'finding(s)')
    do f over r~findings
      out~append('   ' f~text)
    end
    do t over r~notes
      out~append('    note:' t)
    end
  end
  return out
