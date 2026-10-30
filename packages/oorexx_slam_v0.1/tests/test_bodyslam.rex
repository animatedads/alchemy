/* test_bodyslam.rex - Body Slam v0.1 qualification.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 *
 * Arg: WORK|REPO|SAMPLE   WORK a scratch directory; REPO the alchemy checkout (for the lexer check on real
 * files); SAMPLE every SAMPLE-th ooRexx file of the estate is read by both readers (default 25).
 *
 * 1. A fixture estate with one file for each way a require can resolve. Body Slam labels each one, then
 *    the interpreter (ooRexx on PATH) runs each one under the start-ups that decide it. Body Slam's
 *    label must say what the interpreter does.
 * 2. Uses of .Name, the same way: the label, then the run.
 * 3. Projects, families, topics, declared dependencies, cycles, blast radius on the fixture.
 * 4. The scanner against the rx2cpp lexer (RxLexer) on real estate files: the same required names,
 *    class names and .Names.
 */
parse arg work '|' repo '|' sample
if sample == '' then sample = 25
signal on syntax name failed
.local['BSPASS'] = 0
.local['BSFAIL'] = 0
est = work || '/bs_estate'
call SysFileTree est, 'gone.', 'DO'
if gone.0 > 0 then address system 'rm -rf "' || est || '"'
call build est

say '== 1. requires: the label, then the interpreter'
b = .BodySlam~new(est)
db = work || '/bs_fixture.db'
counts = b~ingest(db)
b~session~close
call check counts['SCANNED'] > 20, 'fixture read:' counts['FILES'] 'files,' counts['SCANNED'] 'ooRexx files,' counts['REQUIRES'] 'requires'
r = .BodySlamReport~new(db)

call label r, 'packages/alpha_v0.1/src/p_local.rex', 'Local.cls', 'LOCAL', 'packages/alpha_v0.1/src/Local.cls'
call label r, 'packages/alpha_v0.1/src/p_rel.rex', 'sub/Rel.cls', 'LOCAL', 'packages/alpha_v0.1/src/sub/Rel.cls'
call label r, 'packages/alpha_v0.1/src/p_noext.rex', 'NoExt', 'LOCAL', 'packages/alpha_v0.1/src/NoExt.cls'
call label r, 'packages/alpha_v0.1/src/p_proj.rex', 'Proj.cls', 'PROJECT', 'packages/alpha_v0.1/lib/Proj.cls'
call label r, 'packages/alpha_v0.1/src/p_est.rex', 'Est.cls', 'ESTATE', 'packages/beta_v0.2/src/Est.cls'
call label r, 'packages/alpha_v0.1/src/p_amb.rex', 'Amb.cls', 'AMBIGUOUS', 'packages/gamma_v0.1/src/Amb.cls packages/gamma_v0.2/src/Amb.cls'
call label r, 'packages/alpha_v0.1/src/p_ghost.rex', 'Ghost.cls', 'MISSING', ''
call label r, 'packages/alpha_v0.1/src/p_sys.rex', 'socket.cls', 'SYSTEM', ''
call label r, 'packages/alpha_v0.1/src/p_case.rex', 'case.cls', 'CASE_ONLY', 'packages/beta_v0.2/src/Case.cls'
call label r, 'packages/alpha_v0.1/src/p_lib.rex', 'rxmath', 'LIBRARY', ''
call label r, 'packages/alpha_v0.1/src/p_invalid.rex', '::requires (lib)', 'INVALID', ''
call label r, 'packages/alpha_v0.1/src/p_json.rex', 'json.cls', 'ESTATE', 'packages/beta_v0.2/src/json.cls'
call check r~one("SELECT shadows AS v FROM req WHERE name = 'json.cls'") = 1, 'an estate json.cls is marked as shadowing the json.cls shipped with ooRexx'

a = est || '/packages/alpha_v0.1'
beta = est || '/packages/beta_v0.2/src'
g1 = est || '/packages/gamma_v0.1/src'
g2 = est || '/packages/gamma_v0.2/src'
decoy = est || '/decoys'
call ran 'LOCAL: the local copy, even with a decoy on REXX_PATH and in the current directory', a'/src/p_local.rex', decoy, decoy, 'packages/alpha_v0.1/src/Local.cls'
call ran 'LOCAL: a relative name is relative to the requiring file', a'/src/p_rel.rex', decoy, decoy, 'packages/alpha_v0.1/src/sub/Rel.cls'
call ran 'LOCAL: no extension finds NoExt.cls', a'/src/p_noext.rex', decoy, '', 'packages/alpha_v0.1/src/NoExt.cls'
call ran 'PROJECT: found when the project directory is on REXX_PATH', a'/src/p_proj.rex', work, a'/lib', 'packages/alpha_v0.1/lib/Proj.cls'
call ran 'PROJECT: and not found when it is not', a'/src/p_proj.rex', work, '', 'ERROR 43'
call ran 'ESTATE: found when REXX_PATH names the other project', a'/src/p_est.rex', work, beta, 'packages/beta_v0.2/src/Est.cls'
call ran 'ESTATE: and not found when it does not', a'/src/p_est.rex', work, '', 'ERROR 43'
call ran 'AMBIGUOUS: REXX_PATH gamma 0.1 first loads 0.1', a'/src/p_amb.rex', work, g1':'g2, 'packages/gamma_v0.1/src/Amb.cls'
call ran 'AMBIGUOUS: REXX_PATH gamma 0.2 first loads 0.2', a'/src/p_amb.rex', work, g2':'g1, 'packages/gamma_v0.2/src/Amb.cls'
call ran 'MISSING: not found with every fixture directory on REXX_PATH', a'/src/p_ghost.rex', work, a'/src:'a'/lib:'beta':'g1':'g2, 'ERROR 43'
call ran 'SYSTEM: socket.cls loads from the ooRexx install', a'/src/p_sys.rex', work, '', 'SYSTEM'
call ran 'CASE_ONLY: case.cls is not found though Case.cls is on REXX_PATH', a'/src/p_case.rex', work, beta, 'ERROR 43'
call ran 'INVALID: ooRexx refuses ::requires (lib)', a'/src/p_invalid.rex', work, '', 'ERROR 19'
call ran 'shadowing: with beta on REXX_PATH the estate json.cls replaces the shipped one', a'/src/p_json.rex', work, beta, 'packages/beta_v0.2/src/json.cls'

say '== 2. uses of .Name: the label, then the run'
call uses r, 'packages/alpha_v0.1/src/u_main.rex', 'DEEP', 'REQUIRED'
call uses r, 'packages/alpha_v0.1/src/u_main.rex', 'MID', 'REQUIRED'
call uses r, 'packages/alpha_v0.1/src/u_main.rex', 'OWN', 'SELF'
call uses r, 'packages/alpha_v0.1/src/u_hidden.rex', 'HIDDEN', 'NOT_PUBLIC'
call uses r, 'packages/alpha_v0.1/src/u_lonely.rex', 'LONELY', 'UNDECLARED'
call uses r, 'packages/alpha_v0.1/src/u_behind.rex', 'LONELY', 'BEHIND_MISSING'
call uses r, 'packages/alpha_v0.1/src/u_unknown.rex', 'NOWHERE', 'UNKNOWN'
call uses r, 'packages/alpha_v0.1/src/u_mixin.rex', 'MIXER', 'REQUIRED'
call check r~one("SELECT COUNT(*) AS v FROM use u JOIN file f ON f.id = u.file_id WHERE f.path LIKE '%u_main.rex' AND u.name = 'DIRECTORY'") = 0, 'builtin .Directory is not stored as a use'
call check r~one("SELECT COUNT(*) AS v FROM use WHERE name IN ('FAKE', 'INSTRING')") = 0, '.Names in comments (nested) and in strings are not read'
call check r~one("SELECT COUNT(*) AS v FROM req WHERE name = 'Fake.cls'") = 0, '::requires inside a nested comment is not read'
call check r~one("SELECT COUNT(*) AS v FROM use WHERE name IN ('B', 'C', 'X')") = 0, 'compound tails (a.b.c) and numbers (0.5) are not uses'
call ran 'REQUIRED: .Deep through two requires runs', a'/src/u_main.rex', work, '', 'deep'
call ran 'NOT_PUBLIC: .Hidden from a required file fails', a'/src/u_hidden.rex', work, '', 'ERROR 97'
call ran 'UNDECLARED: .Lonely, defined in delta and required by nothing, is not found', a'/src/u_lonely.rex', work, est'/packages/delta_v0.1/src', 'ERROR 97'
call ran 'REQUIRED through INHERIT of a public mixin runs', a'/src/u_mixin.rex', work, '', 'mixed'

say '== 3. projects, families, topics, declared, cycles, blast radius'
call check .BodySlam~familyOf('packages/alchemy_objects_v0.8')~makeString('L', ' ') == 'alchemy_objects 0.8', 'family alchemy_objects_v0.8: alchemy_objects, 0.8'
call check .BodySlam~familyOf('packages/oorexx_db_skeleton_v0_46')~makeString('L', ' ') == 'oorexx_db_skeleton 0_46', 'family oorexx_db_skeleton_v0_46: oorexx_db_skeleton, 0_46'
call check .BodySlam~familyOf('spheres/access-permissions-sphere-v0.3')~makeString('L', ' ') == 'access-permissions-sphere 0.3', 'family access-permissions-sphere-v0.3: access-permissions-sphere, 0.3'
fv = .BodySlam~familyOf('packages/oorexx_vision')
call check fv[1] == 'oorexx_vision' & fv[2] == '', 'oorexx_vision has no version'
call check .BodySlam~familyOf('packages/fd_door_micro_motion_v0.2-dev8')~makeString('L', ' ') == 'fd_door_micro_motion 0.2-dev8', 'family fd_door_micro_motion_v0.2-dev8: version 0.2-dev8'
cyc = r~cycles
call check cyc[1]~pos('1 groups') > 0 & cyc~makeString('L', ' ')~pos('epsilon, zeta') > 0, 'one cycle: epsilon and zeta require each other'
call check r~one("SELECT COUNT(*) AS v FROM (" .BodySlamReport~edgeSql('DEFINITE') ") WHERE src = 'alpha' AND dst = 'beta'") = 1, 'family edge alpha -> beta (DEFINITE)'
call check r~one("SELECT COUNT(*) AS v FROM (" .BodySlamReport~edgeSql('DEFINITE') ") WHERE src = 'alpha' AND dst = 'gamma'") = 0, 'no DEFINITE edge alpha -> gamma (the only one is AMBIGUOUS)'
call check r~one("SELECT COUNT(*) AS v FROM (" .BodySlamReport~edgeSql('POSSIBLE') ") WHERE src = 'alpha' AND dst = 'gamma'") = 1, 'a POSSIBLE edge alpha -> gamma'
t = r~topics~makeString('L', '|')
call check t~pos('T.ORPHAN') > 0, 'topic T.ORPHAN published and never subscribed'
call check t~pos('T.DEAF') > 0, 'topic T.DEAF subscribed and never published'
call check t~pos('epsilon -> zeta |  T.SHARED')  > 0 | t~pos('epsilon -> zeta | T.SHARED') > 0, 'topic T.SHARED joins epsilon (publisher) to zeta (subscriber)'
d = r~declared~makeString('L', '|')
call check d~pos('gamma_v0.9') > 0 & d~pos('0.1 0.2') > 0, 'declared gamma_v0.9 is not here; nearest versions 0.1 0.2'
call check d~pos('beta_v0.2 |') = 0, 'declared beta_v0.2 is here, so not listed'
call check d~pos('packages/alpha_v0.1 | delta') = 0 & d~pos('packages/alpha_v0.1 | zeta') > 0, 'alpha requires zeta (DEFINITE) without declaring it'
bl = r~blast('Deep')
call check bl[2]~word(2) = 3, 'blast radius of class Deep: Deep.cls, MidLayer.cls, u_main.rex (' || bl[2] || ')'
bl = r~blast('src/Amb.cls')
pos2 = 0
do i = 1 to bl~items
  if bl[i]~left(9) == 'POSSIBLE:' then pos2 = i
end
call check bl[2]~word(2) = 2 & bl[pos2]~word(2) = 3, 'blast radius of file src/Amb.cls: DEFINITE its 2 copies, POSSIBLE also p_amb.rex (' || bl[pos2] || ')'
r~close

say '== 4. the scanner against RxLexer on real files (every' sample || 'th ooRexx file)'
if repo == '' then do
  say 'SKIP: no REPO given'
end
else call lexcheck repo, sample

say 'BODY SLAM TEST:' (.local['BSFAIL'] = 0)~?('PASS', 'FAIL') '(' || .local['BSPASS'] + .local['BSFAIL'] 'checks,' .local['BSFAIL'] 'failed)'
if .local['BSFAIL'] > 0 then exit 1
exit 0

failed:
  say 'test_bodyslam stopped: rc' rc 'at line' sigl '|' condition('C') '|' condition('D')
  c = condition('O')
  if c \== .nil then do
    if c~hasIndex('TRACEBACK') then do t over c['TRACEBACK']
      say t
    end
  end
  exit 1

check: procedure
  use arg ok, text
  if ok then do
    .local['BSPASS'] = .local['BSPASS'] + 1
    say 'PASS ' text
  end
  else do
    .local['BSFAIL'] = .local['BSFAIL'] + 1
    say 'FAIL ' text
  end
  return

/* Body Slam's label and targets for the one require in a probe file */
label: procedure
  use arg r, file, name, level, targets
  got = r~one("SELECT r.level AS v FROM req r JOIN file f ON f.id = r.file_id WHERE f.path = ? AND r.name = ?", file, name)
  rows = r~q("SELECT t.path AS p FROM req r JOIN file f ON f.id = r.file_id JOIN req_target rt ON rt.req_id = r.id JOIN file t ON t.id = rt.target_id WHERE f.path = ? AND r.name = ? ORDER BY t.path", file, name)
  have = .array~new
  do x over rows
    have~append(x['P'])
  end
  have = have~makeString('L', ' ')
  call check got == level & have == targets, 'label' name~left(12) level~left(10) targets '(got' got have || ')'
  return

uses: procedure
  use arg r, file, name, how
  got = r~one("SELECT u.how AS v FROM use u JOIN file f ON f.id = u.file_id WHERE f.path = ? AND u.name = ?", file, name)
  call check got == how, 'use .' || name~left(8) how '(got' got || ')'
  return

/* run a probe under the interpreter with a current directory and a REXX_PATH; compare its first line */
ran: procedure
  use arg text, probe, cwd, rexxPath, expect
  out = probe || '.out'
  address system 'cd "' || cwd || '" && REXX_PATH="' || rexxPath || '" rexx "' || probe || '" > "' || out || '" 2>&1'
  s = .stream~new(out)
  lines = s~arrayIn
  s~close
  first = ''
  if lines~items > 0 then first = lines[1]
  all = lines~makeString('L', ' ')
  if expect~left(5) == 'ERROR' then do
    code = expect~word(2)
    ok = all~pos('Error' code) > 0
    call check ok, 'run' text '(' || expect || ')'
  end
  else call check first == expect, 'run' text '(got' first || ')'
  return

/* ---------- the fixture ---------- */

put: procedure
  use arg path, text
  dir = path~left(path~lastPos('/') - 1)
  call SysMkDir dir
  if SysIsFileDirectory(dir) = 0 then address system 'mkdir -p "' || dir || '"'
  call SysFileDelete path
  s = .stream~new(path)
  s~open('write replace')
  do line over text~makeArray('|')
    s~lineout(line)
  end
  s~close
  return

/* a target file: a routine where() that says which file it is */
target: procedure
  use arg est, rel
  call put est || '/' || rel, '::routine where public|return "' || rel || '"'
  return

build: procedure
  use arg est
  a = 'packages/alpha_v0.1'
  call target est, a'/src/Local.cls'
  call target est, a'/src/sub/Rel.cls'
  call target est, a'/src/NoExt.cls'
  call target est, a'/lib/Proj.cls'
  call target est, 'packages/beta_v0.2/src/Est.cls'
  call target est, 'packages/beta_v0.2/src/Case.cls'
  call target est, 'packages/beta_v0.2/src/json.cls'
  call target est, 'packages/gamma_v0.1/src/Amb.cls'
  call target est, 'packages/gamma_v0.2/src/Amb.cls'
  call target est, 'decoys/Local.cls'
  call target est, 'decoys/sub/Rel.cls'
  call put est'/'a'/src/p_local.rex', 'say where()|::requires "Local.cls"'
  call put est'/'a'/src/p_rel.rex', 'say where()|::requires "sub/Rel.cls"'
  call put est'/'a'/src/p_noext.rex', 'say where()|::requires "NoExt"'
  call put est'/'a'/src/p_proj.rex', 'say where()|::requires "Proj.cls"'
  call put est'/'a'/src/p_est.rex', 'say where()|::requires "Est.cls"'
  call put est'/'a'/src/p_amb.rex', 'say where()|::requires "Amb.cls"'
  call put est'/'a'/src/p_ghost.rex', 'say where()|::requires "Ghost.cls"'
  call put est'/'a'/src/p_sys.rex', 'say "SYSTEM"|::requires "socket.cls"'
  call put est'/'a'/src/p_case.rex', 'say where()|::requires "case.cls"'
  call put est'/'a'/src/p_lib.rex', 'say "lib"|::requires "rxmath" LIBRARY'
  call put est'/'a'/src/p_invalid.rex', 'lib = "Local.cls"|say where()|::requires (lib)'
  call put est'/'a'/src/p_json.rex', 'say where()|::requires "json.cls"'
  /* uses */
  call put est'/'a'/src/Deep.cls', '::class Deep public|::method hi|return "deep"'
  call put est'/'a'/src/MidLayer.cls', '::requires "Deep.cls"|::class Mid public'
  call put est'/'a'/src/u_main.rex', 'x = .Mid~new|say .Deep~new~hi|y = .Own~new|d = .Directory~new|z = a.b.c + 0.5 + .5|/* outer /* .Fake ::requires "Fake.cls" */ still comment .Fake */|-- .Fake|s = "a .InString here"|::requires "MidLayer.cls"|::class Own'
  call put est'/'a'/src/Private.cls', '::class Hidden|::method hi|return "hidden"'
  call put est'/'a'/src/u_hidden.rex', 'say .Hidden~new~hi|::requires "Private.cls"'
  call put est'/packages/delta_v0.1/src/Lonely.cls', '::class Lonely public|::method hi|return "lonely"'
  call put est'/'a'/src/u_lonely.rex', 'say .Lonely~new~hi'
  call put est'/'a'/src/u_behind.rex', 'say .Lonely~new~hi|::requires "GoneLink.cls"'
  call put est'/'a'/src/u_unknown.rex', 'say .Nowhere'
  call put est'/'a'/src/Mixer.cls', '::class Mixer mixinclass Object public|::method hi|return "mixed"'
  call put est'/'a'/src/u_mixin.rex', 'say .Blend~new~hi|::requires "Mixer.cls"|::class Blend inherit Mixer'
  /* families that require each other; topics; alpha requires zeta */
  call put est'/packages/epsilon_v0.1/src/Eps.cls', '::requires "Zet.cls"|::class Eps public|::method go|.bus~publish("T.SHARED", 1)|.bus~publish("T.ORPHAN", 2)'
  call put est'/packages/zeta_v0.3/src/Zet.cls', '::requires "Eps.cls"|::class Zet public|::method go|.bus~subscribe("T.SHARED", self)|.bus~subscribe(''T.DEAF'', self)'
  call put est'/'a'/src/z_user.rex', 'say .Zet~new|::requires "Zet.cls"'
  call put est'/'a'/DEPENDENCIES.txt', 'Dependencies:|- beta_v0.2|- gamma_v0.9 (optional)|- delta_v0.1'
  return

/* ---------- part 4 ---------- */

lexcheck: procedure
  use arg repo, sample
  call SysFileTree repo || '/packages/*', 'f.', 'FSO'
  pick = .array~new
  n = 0
  do i = 1 to f.0
    low = f.i~lower
    if low~pos('/.git/') > 0 then iterate
    if \(low~right(4) == '.cls' | low~right(4) == '.rex') then iterate
    n += 1
    if n // sample = 0 then pick~append(f.i)
  end
  sc = .BodySlamScanner~new
  same = 0
  diff = 0
  refused = 0
  shown = 0
  nreq = 0
  ncls = 0
  nuse = 0
  do path over pick
    s = .stream~new(path)
    text = s~charIn(1, s~chars)
    s~close
    tokens = lexOrNil(text)
    if tokens == .nil then do
      refused += 1
      iterate
    end
    lexed = lexFacts(tokens)
    got = sc~scan(path)
    mine = .directory~of(('REQ', .array~new), ('CLS', .array~new), ('USE', .set~new))
    do fact over got[1]
      if fact[1] == 'REQUIRES' then do
        /* not a literal: the lexer's token is the '(' */
        if fact[4] == 'INVALID' then mine['REQ']~append('(')
        else mine['REQ']~append(fact[3])
      end
      if fact[1] == 'CLASS' then mine['CLS']~append(fact[3]~upper)
      if fact[1] == 'USE' then mine['USE']~put(fact[3])
    end
    a1 = mine['REQ']~makeString('L', ' ')
    b1 = lexed['REQ']~makeString('L', ' ')
    a2 = mine['CLS']~makeString('L', ' ')
    b2 = lexed['CLS']~makeString('L', ' ')
    a3 = mine['USE']~allItems~sort~makeString('L', ' ')
    b3 = lexed['USE']~allItems~sort~makeString('L', ' ')
    nreq += mine['REQ']~items
    ncls += mine['CLS']~items
    nuse += mine['USE']~items
    if a1 == b1 & a2 == b2 & a3 == b3 then same += 1
    else do
      diff += 1
      if shown < 5 then do
        shown += 1
        say '   differs:' path~substr(repo~length + 2)
        if a1 \== b1 then say '     requires: scanner [' || a1 || '] lexer [' || b1 || ']'
        if a2 \== b2 then say '     classes:  scanner [' || a2 || '] lexer [' || b2 || ']'
        if a3 \== b3 then say '     uses:     scanner [' || a3 || '] lexer [' || b3 || ']'
      end
    end
  end
  say '   files:' pick~items '(' || refused 'the lexer refuses, skipped); facts compared:' nreq 'requires,' ncls 'classes,' nuse 'uses'
  call check diff = 0, 'scanner and RxLexer agree on' same 'of' same + diff 'files (requires, class names, .Names)'
  return

/* RxLexer's tokens, or .nil when it refuses the file (a label outside any loop, as the house rule says) */
lexOrNil: procedure
  use arg text
  signal on syntax name refusedLex
  return .RxLexer~new(text)~scan
refusedLex:
  return .nil

/* the same facts from RxLexer tokens: a directive is '::' at the start of a clause */
lexFacts: procedure
  use arg tokens
  out = .directory~of(('REQ', .array~new), ('CLS', .array~new), ('USE', .set~new))
  atStart = .true
  n = tokens~items
  do i = 1 to n
    t = tokens[i]
    if t~kind == 'EOF' then leave
    if t~kind == 'SEP' then do
      atStart = .true
      iterate
    end
    isDirective = .false
    if atStart then if t~kind == 'OP' then if t~text == '::' then if i + 2 <= n then isDirective = .true
    if isDirective then do
      kw = tokens[i + 1]~text~upper
      nx = tokens[i + 2]
      v = nx~text
      if nx~kind == 'STRING' then v = unquote(v)
      else v = v~upper
      if kw == 'REQUIRES' then out['REQ']~append(v)
      if kw == 'CLASS' then out['CLS']~append(v~upper)
      /* the rest of a directive clause holds no uses */
      do while i < n
        if tokens[i + 1]~kind == 'SEP' then leave
        if tokens[i + 1]~kind == 'EOF' then leave
        i += 1
      end
      atStart = .false
      iterate
    end
    atStart = .false
    if t~kind == 'DOTIDENT' then do
      name = t~text
      if name~left(1) == '.' then name = name~substr(2)
      if name~pos('.') > 0 then name = name~left(name~pos('.') - 1)
      if name \== '' then if datatype(name~left(1), 'M') | '_!?'~pos(name~left(1)) > 0 then out['USE']~put(name~upper)
    end
  end
  return out

unquote: procedure
  use arg v
  q = v~left(1)
  if q == '"' | q == "'" then do
    v = v~substr(2)
    tail = v~lastPos(q)
    if tail > 0 then v = v~left(tail - 1)
    v = v~changestr(q || q, q)
  end
  return v

::requires 'BodySlam.cls'
::requires 'BodySlamReport.cls'
::requires 'core/RxLexer.cls'
