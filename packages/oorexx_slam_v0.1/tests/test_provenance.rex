/* Which tool wrote which code, and what happened to it (SlamProvenance.cls).
 * Architecture: Tom Dyer: "Failure to credit tools used in generation is a technical weakness. By knowing
 * which tool generated which code, if the tool has a habit of embedding a given error that error can be
 * identified at a tool level."  Code: Claude (Opus 5.5), 2026-10-29.
 * Args: scratch dir | alchemy checkout
 *
 *  1. credit lines: what counts as one, and one spelling per tool across levels
 *  2. each level on real files: HEADER, PROVENANCE (vendored code), README (MIXED), NOT_RECORDED
 *  3. GIT per line: FDSqrt's lines split between the fix's commit and older lines; a shallow clone's
 *     boundary is UNKNOWN_HISTORY, never the boundary commit's tool
 *  4. a store: provenance for every unit, and the conflict when a session commits another tool's code
 *  5. a habit, found by shape: a Newton square root inside a fixed-count loop (FDSqrt's error), estate-wide
 *     in the files given; each find is then judged by certificate, not by its shape
 *  6. outcomes by tool: proofs and lessons counted against the tool that wrote the code
 */
signal on syntax name onSyntax
parse arg work '|' repo
checks = 0
P = repo || '/packages'
slam = P || '/oorexx_slam_v0.1'
door = P || '/fd_door_micro_motion_v0.2-dev8/src/FDDoorMicroMotion.cls'
brand = P || '/brand_intervention_effectiveness_v0.2/src/BrandInterventionEffectiveness.cls'
fixture = slam || '/tests/fixtures/fdsqrt_fixed14.cls'

say '== 1. credit lines'
cases = .array~of( -
  .array~of('Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-28.', 'Claude (Opus 5.5)'), -
  .array~of('Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.', 'Claude (Opus 4.8)'), -
  .array~of('Architecture: Tom Dyer. Coding: ChatGPT GPT-6.', 'ChatGPT GPT-6'), -
  .array~of(' * false.  Code: ChatGPT (the door package).  Do not use', 'ChatGPT'), -
  .array~of('**Architecture:** Tom Dyer. **dev26 coding:** Claude (Opus 5.5), 23 Oct 2026.', 'Claude (Opus 5.5)'), -
  .array~of('- Authors: the rx2cpp lane (ChatGPT and Claude); architecture Tom Dyer.', 'ChatGPT and Claude'), -
  .array~of('**Coding:** ChatGPT and Codex (dev1 to dev25); Claude (Opus 5.5) for dev26.', 'MIXED: ChatGPT and Codex (dev1 to dev25); Claude (Opus 5.5) for dev26'), -
  .array~of('Architecture: Tom Dyer.', ''), -
  .array~of("  c = .Client~new('codex:mcp')", ''), -
  .array~of('barcode: ABC123', ''), -
  .array~of('code: see below', ''))
bad = 0
do c over cases
  got = .SlamProvenance~credit(c[1])
  if got \== c[2] then do; bad += 1; say '       got [' || got || '] for' c[1]; end
end
call check bad = 0, cases~items 'lines: 7 credits read (one MIXED, kept whole), 4 that are not credits refused (codex:mcp is a name in code, barcode: is not code:)'
call check .SlamProvenance~normal('Claude Opus 5.5 <noreply@anthropic.com>') == .SlamProvenance~credit('Code: Claude (Opus 5.5), 2026-10-28.'), 'a commit trailer and a header name the same tool the same way: Claude (Opus 5.5)'

say '== 2. each level on real files'
call level slam || '/src/SlamProof.cls', 'HEADER', 'Claude (Opus 5.5)'
call level fixture, 'HEADER', 'ChatGPT'
call level slam || '/vendor/rx2cpp/core/RxLexer.cls', 'PROVENANCE', 'ChatGPT and Claude'
d = .SlamProvenance~ofFile(P || '/oorexx_xtp_v0.1-dev26/rexx/XTP.cls')
call check d['LEVEL'] == 'README' & d['TOOL']~left(6) == 'MIXED:', 'XTP.cls: README, MIXED (' || d['TOOL']~left(60) || '...): several tools, none picked'
call level door, 'NOT_RECORDED', 'NOT_RECORDED'
call level brand, 'NOT_RECORDED', 'NOT_RECORDED'

say '== 3. git, per line'
address system 'git -C "' || repo || '" rev-parse --is-shallow-repository' with output stem sh.
shallow = sh.0 > 0 & sh.1 == 'true'
fdLines = findLines(door, '::routine FDSqrt public')
g = .SlamProvenance~ofLines(repo, door~substr(repo~length + 2), fdLines[1], fdLines[2], .directory~new)
say '      ' g['EVIDENCE']
ev = g['EVIDENCE']
parse var ev . 'Claude (Opus 5.5)=' nClaude .
call check g['TOOL'] == 'Claude (Opus 5.5)' & nClaude = 9, 'FDSqrt now: the 9 lines of the fix (3761f57c) are Claude (Opus 5.5)'
if shallow then call check g['EVIDENCE']~pos('UNKNOWN_HISTORY=' || (fdLines[2] - fdLines[1] + 1 - 9)) > 0, 'this clone is shallow: the' fdLines[2] - fdLines[1] + 1 - 9 'older lines are UNKNOWN_HISTORY, not the boundary commit''s tool'
else call check .true, 'full history: the older lines are credited by their own commits'

say '== 4. a store: every unit, and the conflict'
db = work || '/prov.db'
call SysFileDelete db; call SysFileDelete db || '-wal'; call SysFileDelete db || '-shm'
dirs = filespec('L', door) filespec('L', brand) slam || '/tests/fixtures' slam || '/vendor/rx2cpp/core'
address system 'rexx "' || slam || '/bin/slam.rex" ingest "' || db || '"' dirs with output stem ig.
store = .SlamStore~new(db)
counts = .SlamProvenance~recordAll(store, repo)
say '       units by level: GIT' counts['GIT'] '| HEADER' counts['HEADER'] '| PROVENANCE' counts['PROVENANCE'] '| README' counts['README'] '| NOT_RECORDED' counts['NOT_RECORDED']
do r over store~toolUnits
  say '      ' r['TOOL']~left(44) r['LEVEL']~left(13) r['UNITS']~right(5) 'units in' r['FILES'] 'files'
end
total = store~scalar('SELECT count(*) AS n FROM unit')
call check store~scalar('SELECT count(*) AS n FROM provenance') = total & total > 0, 'every one of the' total 'units has a provenance row, unknown ones included'
conflict = store~scalar("SELECT p.evidence AS e FROM provenance p JOIN unit u ON u.id = p.unit_id WHERE u.path LIKE '%fdsqrt_fixed14.cls' LIMIT 1")
say '       fixture:' conflict~left(160)
tool = store~scalar("SELECT p.tool AS t FROM provenance p JOIN unit u ON u.id = p.unit_id WHERE u.path LIKE '%fdsqrt_fixed14.cls' LIMIT 1")
call check tool == 'ChatGPT' & conflict~pos('CONFLICT: GIT says Claude (Opus 5.5)') > 0, 'the old FDSqrt is ChatGPT''s by its header; the commit holding it is a Claude session''s: the claim of authorship decides, the commit record is kept, flagged'

say '== 5. a habit by shape: Newton''s step inside a fixed-count loop'
sql = "SELECT DISTINCT u.id AS id, u.path AS path, u.selector AS sel, u.line AS line, p.tool AS tool, p.level AS level" ,
      "FROM instance l JOIN shape sl ON sl.id = l.shape_id JOIN instance r ON r.parent_id = l.id JOIN shape sr ON sr.id = r.shape_id" ,
      "JOIN unit u ON u.id = l.unit_id JOIN provenance p ON p.unit_id = u.id" ,
      "WHERE sl.canon LIKE 'LOOP: do N %' AND sr.canon LIKE 'RUN: L1 = ( L1 + %A1 / L1%' ORDER BY u.path"
finds = store~q(sql)~rows
names = ''; doorFound = .false
do f over finds
  if f['PATH'] == door then doorFound = .true
  say '      ' filespec('N', f['PATH'])~left(38) f['SEL']~left(14) 'line' f['LINE']~left(5) 'tool:' f['TOOL'] '(' || f['LEVEL'] || ')'
  names = names f['SEL']
end
call check finds~items = 2 & wordpos('FDSQRT', names~upper) > 0 & wordpos('SQRTNUMBER', names~upper) > 0, 'found 2: the old FDSqrt, and sqrtNumber in brand_intervention_effectiveness (the same error shape, in another package)'
call check \doorFound, 'the fixed FDSqrt (in the door file) is not found: its loop has no count'
h = store~toolHabit('LOOP: do N %')
do r over h
  if r['WITH'] > 0 then say '       fixed-count loops:' r['TOOL']~left(44) r['WITH'] 'of' r['UNITS'] 'units'
end

say '== 5b. judged by certificate, not by shape'
body = methodBody(brand, 'sqrtNumber')
sq = .Routine~new('SQRTNUMBER', body)
worst = 0
do n = 1 to 60
  do k = 0 to n
    p = k / n; z2 = 1.96 * 1.96
    v = p * (1 - p) / n + z2 / (4 * n * n)
    if v > worst then worst = v
    r = sq~call(v)
    if .SlamCertify~sqrtWithin(v, r, 0.00000001)~outcome \== 'PROVED' then do
      call check .false, 'sqrtNumber wrong at its own input' v
    end
  end
end
call check worst < 1.22, 'every input its caller can give (the Wilson variance, n = 1 to 60, all k: at most' format(worst, , 4) || ') PROVED within 1e-8: the habit is there, the harm is not'
limit = ''
do e = 6 to 30
  x = 10 ** e
  if .SlamCertify~sqrtWithin(x, sq~call(x), 0.00000001)~outcome \== 'PROVED' then do; limit = x; leave; end
end
call check limit \== '', 'as a general square root it is DISPROVED from x =' limit '(20 steps, where FDSqrt''s 14 failed from 1e7)'
nb = store~codeNode('sqrtNumber (brand)')
store~tagNode(nb, .SlamProvenance~ofFile(brand))
ignored = store~proof(nb, .SlamCertify~sqrtWithin(worst, sq~call(worst), 0.00000001), 'largest caller input' worst)
ignored = store~proof(nb, .SlamCertify~sqrtWithin(limit, sq~call(limit), 0.00000001), 'general input' limit)
ignored = store~proof(nb, .SlamCertify~forAll('sqrtNumber is right for every input its caller can give'), 'n >= 1')

say '== 6. outcomes by tool'
c = .SlamComposer~new
old = c~lift(fixture, 'FDSqrt', 'OLD')
now = c~lift(door, 'FDSqrt', 'NOW')
nOld = store~codeNode('FDSqrt before 3761f57c'); store~tagNode(nOld, .SlamProvenance~ofFile(fixture))
nNow = store~codeNode('FDSqrt now'); store~tagNode(nNow, g)
values = .array~of(0.25, 2, 10, 1000, 999999, 1000001, 10000000, 99999999, 100000000, 1000000000, 1E12, 4E18)
store~begin
do x over values
  ignored = store~proof(nOld, .SlamCertify~sqrtWithin(x, old~routine~call(x), 0.00000001), 'x=' || x)
  ignored = store~proof(nNow, .SlamCertify~sqrtWithin(x, now~routine~call(x), 0.00000001), 'x=' || x)
end
store~commit
rows = store~toolOutcomes
byTool = .directory~new
do r over rows
  say '      ' r['TOOL']~left(26) r['KIND']~left(7) r['OUTCOME']~left(14) r['N']
  byTool[r['TOOL'] '/' r['OUTCOME']] = r['N']
end
call check byTool['ChatGPT / DISPROVED'] = 6 & byTool['ChatGPT / PROVED'] = 6, 'ChatGPT (the old FDSqrt, by its header): 6 DISPROVED (every value above 1e6 but 1000001), 6 PROVED'
call check byTool['Claude (Opus 5.5) / PROVED'] = values~items & \byTool~hasIndex('Claude (Opus 5.5) / DISPROVED'), 'Claude (Opus 5.5) (the fix, by git lines): all' values~items 'PROVED'
call check byTool['NOT_RECORDED / DISPROVED'] = 1 & byTool['NOT_RECORDED / INDETERMINATE'] = 1, 'sqrtNumber: the tool is NOT_RECORDED, so its DISPROVED result counts against no tool: the gap, shown'
store~close
say 'PROVENANCE TEST: PASS (' || checks || ' checks)'
exit 0

level: procedure expose checks
  use arg path, lv, tool
  d = .SlamProvenance~ofFile(path)
  call check d['LEVEL'] == lv & d['TOOL'] == tool, filespec('N', path) || ':' lv tool
  return

/* first and last line of the unit that starts with HEAD (to the next :: directive, less trailing blanks) */
findLines: procedure
  use arg path, head
  s = .stream~new(path); s~open('READ'); n = 0; first = 0; last = 0
  do while s~lines > 0
    t = s~linein; n += 1
    if first = 0 then do
      if t~strip == head then first = n
      iterate
    end
    if t~strip~left(2) == '::' then leave
    if t~strip \== '' then last = n
  end
  s~close
  return .array~of(first, last)

/* the body of ::method NAME (lines after the directive, to the next directive) */
methodBody: procedure
  use arg path, name
  s = .stream~new(path); s~open('READ'); out = .array~new; on = .false
  do while s~lines > 0
    t = s~linein
    if on then do
      if t~strip~left(2) == '::' then leave
      out~append(t)
    end
    else if t~strip~upper~word(1) == '::METHOD' & t~strip~upper~word(2) == name~upper then on = .true
  end
  s~close
  return out

check: procedure expose checks
  use arg ok, label
  checks += 1
  if ok then say 'PASS ' label
  else do
    say 'FAIL ' label
    exit 1
  end
  return

onSyntax:
  say 'SYNTAX rc=' || rc 'sigl=' || sigl condition('C') condition('D')
  exit 1

::requires 'SlamProvenance.cls'
::requires 'SlamCompose.cls'
::requires 'SlamProof.cls'
