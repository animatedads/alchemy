/* ModuleStampStep.cls - Alchemy Workflow v0.1-dev1 step "ModuleStamp" (stage stamp): does every class
 * answer ~module_version and ~module_lastChanged, with the right values?
 *
 * Architecture: Tom Dyer (11 Nov 2026: every Alchemy ooRexx object reports the actual version of its own
 * component and when it last changed; named module_* so they never clash with a business version()).
 * Code: Claude (Opus 5.5), 2026-11-11.
 *
 * A class answers them when it has a ::constant, ::method or ::attribute MODULE_VERSION and
 * MODULE_LASTCHANGED of its own, or inherits them from a class of the same package (the same component,
 * so the same version). Inheriting them from another package is the case the rule exists for: the class
 * would report that package's version.
 *
 * Rules:
 *   MS-MISSING  FAIL  a class answers neither (or only one) of the two
 *   MS-VERSION  FAIL  ::constant MODULE_VERSION is not the manifest's package.version (a stale stamp)
 *   MS-DATE     WARN  ::constant MODULE_LASTCHANGED is older than the file's last commit
 *
 * v0.1-dev1 reports only. The fix it names is exactly the stamp a fix-mode step will write (through SSC's
 * object-level edits, not text substitution): the two ::constant lines after the ::class line.
 */
::requires 'AlchemyWorkflow.cls'

::class ModuleStampStep public subclass WorkflowStep
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'

::method id
  return 'ModuleStamp'

::method stage
  return 'stamp'

::method describe
  return 'check that every class answers ~module_version and ~module_lastChanged with the package version and its last change'

::method skipReason
  use strict arg ctx
  if ctx~sourceFiles~items = 0 then return 'no ooRexx files'
  return ''

::method intends
  use strict arg ctx
  return 'read' ctx~sourceFiles~items 'ooRexx file(s); report each class without the two stamps (version' self~versionFor(ctx) || ')'

/* the version a stamp should carry: the directory's (the name the package is published and required
   under), else the manifest's. Where the two differ, Manifest reports it (MF-NAME) */
::method versionFor
  use strict arg ctx
  v = ctx~version
  if v \== '' then return v
  m = ctx~manifest
  if \m~isA(.Directory) then return ''
  if \m['package']~isA(.Directory) then return ''
  v = m['package']['version']
  if v == .nil then v = ''
  return v

::method run
  use strict arg ctx, res
  want = self~versionFor(ctx)
  /* every class of the package, by upper-case name: (file, directive, source) */
  classes = .directory~new
  do rel over ctx~sourceFiles
    src = ctx~source(rel)
    do d over src~ofKind('CLASS')
      e = .directory~new
      e['FILE'] = rel
      e['DIR'] = d
      e['SRC'] = src
      classes[d['NAME']~upper] = e
    end
  end
  checked = 0
  do key over classes~allIndexes~sort
    checked += 1
    e = classes[key]
    self~checkClass(ctx, res, classes, e, want)
  end
  res~note(checked 'class(es) checked, stamp version' want)

/* the stamps a class answers: a directory MODULE_VERSION / MODULE_LASTCHANGED -> (directive, source, via) */
::method stampsOf
  use strict arg classes, e, seen
  d = e['DIR']
  if seen~hasIndex(d['NAME']~upper) then return .directory~new
  seen[d['NAME']~upper] = 1
  out = .directory~new
  mem = e['SRC']~members(d['NAME'])
  do k over .array~of('MODULE_VERSION', 'MODULE_LASTCHANGED')
    if mem[k] \== .nil then out[k] = .array~of(mem[k], e['SRC'], '')
  end
  /* from a superclass or mixin of the same package */
  opts = d['OPTIONS']
  supers = .array~new
  p = wordpos('SUBCLASS', opts)
  if p > 0 then supers~append(word(opts, p + 1))
  p = wordpos('INHERIT', opts)
  if p > 0 then do i = p + 1 to words(opts)
    supers~append(word(opts, i))
  end
  do sup over supers
    sup = sup~strip('B', "'")~strip('B', '"')~upper
    if classes[sup] == .nil then iterate
    got = self~stampsOf(classes, classes[sup], seen)
    do k over got~allIndexes
      if out[k] == .nil then out[k] = .array~of(got[k][1], got[k][2], 'inherited from' classes[sup]['DIR']['NAME'])
    end
  end
  return out

::method checkClass
  use strict arg ctx, res, classes, e, want
  d = e['DIR']
  rel = e['FILE']
  stamps = self~stampsOf(classes, e, .directory~new)
  missing = .array~new
  do k over .array~of('MODULE_VERSION', 'MODULE_LASTCHANGED')
    if stamps[k] == .nil then missing~append(.array~of('module_version', 'module_lastChanged')[wordpos(k, 'MODULE_VERSION MODULE_LASTCHANGED')])
  end
  last = ctx~lastChanged(rel)
  date = last
  if date == '' then date = .DateTime~new~isoDate~left(10)
  if missing~items > 0 then do
    res~add(self~finding('MS-MISSING', 'FAIL', rel, d['LINE'], 'class' d['NAME'] 'does not answer ~' || missing~makeString('L', ' or ~'), 'after line' d['LINE'] 'add:' "::constant MODULE_VERSION '" || want || "'" 'and' "::constant MODULE_LASTCHANGED '" || date || "'"))
    return
  end
  /* the values, where they are constants of this class */
  sv = stamps['MODULE_VERSION']
  if sv[3] == '' then if sv[1]['KIND'] == 'CONSTANT' then do
    v = sv[2]~constantValue(sv[1])
    if v \== want then res~add(self~finding('MS-VERSION', 'FAIL', rel, sv[1]['LINE'], 'class' d['NAME'] 'says MODULE_VERSION' v 'but the package is version' want, "make it ::constant MODULE_VERSION '" || want || "'"))
  end
  sl = stamps['MODULE_LASTCHANGED']
  if last \== '' then if sl[3] == '' then if sl[1]['KIND'] == 'CONSTANT' then do
    v = sl[2]~constantValue(sl[1])
    if v < last then res~add(self~finding('MS-DATE', 'WARN', rel, sl[1]['LINE'], 'class' d['NAME'] 'says MODULE_LASTCHANGED' v 'but' rel 'last changed on' last, "make it ::constant MODULE_LASTCHANGED '" || last || "'"))
  end
