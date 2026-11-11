/* ManifestStep.cls - Alchemy Workflow v0.1-dev1 step "Manifest" (stage intake): does the package's
 * integration.json say what its directory says, and can Autobuild start what it names?
 *
 * Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-11-11.
 *
 * Rules (each can be set per layer as Manifest.<rule> off|warn in the rule book):
 *   MF-MISSING  FAIL  no integration.json: Autobuild cannot run the package (Docy, 10 Nov)
 *   MF-PARSE    FAIL  integration.json does not parse
 *   MF-SCHEMA   WARN  no "schema"
 *   MF-PACKAGE  FAIL  "package" is text, not an object (the older form; found 11 Nov in oorexx_llm_pa)
 *   MF-NAME     FAIL  package.name and package.version do not give the directory name
 *                     (alchemy_website_publisher_v0.4 declares 0.3, found 10 Nov)
 *   MF-PUBLISH  FAIL  publish.tree.path is not this package's own directory: publishing would write over
 *                     another version (the same manifest publishes to ..._v0.3). An unversioned working
 *                     directory (oorexx_ldap_identity) may publish a versioned release of itself
 *                     (oorexx_ldap_identity_v0.1-dev13)
 *   MF-TESTS    WARN  no tests
 *   MF-CWD      FAIL  a test's cwd is not a directory of the package
 *   MF-PROGRAM  FAIL  a test starts python3, sh, bash or node on a relative file that is not there from its
 *                     cwd; for rexx, WARN, because ooRexx also looks on REXX_PATH (KitRun decides)
 *   MF-PYTHON   WARN  an ooRexx package whose test starts Python: the README should say why (house rule:
 *                     no unjustified Python)
 */
::requires 'AlchemyWorkflow.cls'

::class ManifestStep public subclass WorkflowStep
::constant MODULE_VERSION '0.1-dev1'
::constant MODULE_LASTCHANGED '2026-11-11'

::method id
  return 'Manifest'

::method stage
  return 'intake'

::method describe
  return 'check integration.json against the directory name, its publish path, and the programs its tests start'

/* the first line of integration.json holding text, for file:line */
::method lineOf
  use strict arg ctx, text
  if \SysFileExists(ctx~manifestPath) then return 0
  s = .stream~new(ctx~manifestPath)
  s~open('read shareread')
  n = 0
  at = 0
  do while s~lines > 0
    n += 1
    if s~lineIn~pos(text) > 0 then do
      at = n
      leave
    end
  end
  s~close
  return at

::method run
  use strict arg ctx, res
  f = 'integration.json'
  if ctx~manifest == .nil then do
    if ctx~manifestError == 'no integration.json' then res~add(self~finding('MF-MISSING', 'FAIL', f, 0, 'the package has no integration.json, so Autobuild cannot test or publish it', 'add integration.json (schema alchemy.autobuild.integration/0.2): package name and version, environment, tests, publish'))
    else res~add(self~finding('MF-PARSE', 'FAIL', f, 0, ctx~manifestError, 'make integration.json valid JSON'))
    return
  end
  m = ctx~manifest
  if \m~isA(.Directory) then do
    res~add(self~finding('MF-PARSE', 'FAIL', f, 1, 'integration.json is not a JSON object', 'make it an object: schema, package, environment, tests, publish'))
    return
  end
  if m['schema'] == .nil then res~add(self~finding('MF-SCHEMA', 'WARN', f, 1, 'no "schema" entry', 'add "schema": "alchemy.autobuild.integration/0.2"'))
  pkg = m['package']
  if pkg == .nil then pkg = .directory~new
  if \pkg~isA(.Directory) then do
    res~add(self~finding('MF-PACKAGE', 'FAIL', f, self~lineOf(ctx, '"package"'), '"package" is' pkg~string '(text), not an object with name, version and kind: Autobuild v0.2 and later cannot read it', 'make it "package": {"name": "' || ctx~family || '", "version": "' || ctx~version || '", "kind": "oorexx"}'))
    self~checkPublish(ctx, res, m)
    self~checkTests(ctx, res, m, .directory~new)
    return
  end
  name = pkg['name']
  version = pkg['version']
  if name == .nil then name = ''
  if version == .nil then version = ''
  expect = name || '_v' || version
  /* an unversioned working directory carries its family name; the version is the release it publishes */
  if ctx~version == '' then if name == ctx~name then expect = ctx~name
  if expect \== ctx~name then do
    at = self~lineOf(ctx, '"version"')
    res~add(self~finding('MF-NAME', 'FAIL', f, at, 'the directory is' ctx~name 'but the manifest says name' name 'version' version '(=' expect || ')', 'make package.name' ctx~family 'and package.version' ctx~version || ', or move the package to' expect))
  end
  self~checkPublish(ctx, res, m)
  self~checkTests(ctx, res, m, pkg)

::method checkPublish
  use strict arg ctx, res, m
  pub = m['publish']
  if pub == .nil then return
  tree = pub['tree']
  if tree == .nil then return
  dest = tree['path']
  if dest == .nil then return
  dest = dest~strip('T', '/')
  last = dest~substr(dest~lastPos('/') + 1)
  if last == ctx~name then return
  /* an unversioned working directory publishing a versioned release of itself is the estate's way */
  if ctx~version == '' then if last~left(ctx~name~length + 2) == ctx~name || '_v' then return
  res~add(self~finding('MF-PUBLISH', 'FAIL', 'integration.json', self~lineOf(ctx, '"path"'), 'publish.tree.path is' dest || ', not this package''s directory' ctx~relDir || ': publishing would write over another version', 'set publish.tree.path to' ctx~relDir))

::method checkTests
  use strict arg ctx, res, m, pkg
  tests = m['tests']
  if tests == .nil then tests = .array~new
  if tests~items = 0 then do
    res~add(self~finding('MF-TESTS', 'WARN', 'integration.json', 0, 'no tests: Autobuild would publish it untested', 'add at least one test that runs the package''s own checks'))
    return
  end
  kind = pkg['kind']
  if kind == .nil then kind = ''
  wd = m['working_directory']
  if wd == .nil then wd = '.'
  python = .false
  do t over tests
    if \t~isA(.Directory) then iterate
    tname = t['name']
    if tname == .nil then tname = '?'
    cwd = t['cwd']
    if cwd == .nil then cwd = wd
    if cwd~left(1) == '/' then cwdAbs = cwd
    else cwdAbs = ctx~pkgDir || '/' || cwd
    if \SysIsFileDirectory(cwdAbs) then do
      res~add(self~finding('MF-CWD', 'FAIL', 'integration.json', self~lineOf(ctx, '"' || tname || '"'), 'test' tname 'runs in' cwd || ', which is not a directory of the package', 'set the test''s cwd to a directory that exists, relative to the package'))
      iterate
    end
    argv = t['argv']
    if argv == .nil then iterate
    if argv~items < 2 then iterate
    prog = argv[1]~string
    prog = prog~substr(prog~lastPos('/') + 1)
    if prog~left(6) == 'python' then python = .true
    file = argv[2]~string
    if wordpos(prog, 'rexx python3 python sh bash node') = 0 then iterate
    if file~left(1) == '-' then iterate
    if file~pos('/') = 0 then if prog \== 'rexx' then iterate
    if file~left(1) == '/' then fileAbs = file
    else fileAbs = cwdAbs || '/' || file
    if SysFileExists(fileAbs) then iterate
    at = self~lineOf(ctx, '"' || tname || '"')
    if prog == 'rexx' then res~add(self~finding('MF-PROGRAM', 'WARN', 'integration.json', at, 'test' tname 'runs rexx' file 'from cwd' cwd || ': there is no' file 'there; ooRexx would look on REXX_PATH next', 'name the program relative to the test''s cwd (or set cwd); KitRun gives the verdict'))
    else res~add(self~finding('MF-PROGRAM', 'FAIL', 'integration.json', at, 'test' tname 'runs' prog file 'from cwd' cwd || ': there is no such file', 'name the file relative to the test''s cwd, or set cwd'))
  end
  if python then if kind == 'oorexx' then res~add(self~finding('MF-PYTHON', 'WARN', 'integration.json', self~lineOf(ctx, 'python'), 'an ooRexx package (kind oorexx) whose tests start Python', 'say in the README why Python is needed here, or write the test in ooRexx'))
