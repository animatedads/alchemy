#!/usr/bin/env rexx
/* bodyslam.rex - Body Slam v0.1: how the estate hangs together.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-29.
 *
 *   rexx bin/bodyslam.rex ingest DB ROOT        read the estate under ROOT into DB (DB is made again)
 *   rexx bin/bodyslam.rex report DB [NAME [N]]  NAME: summary ambiguous clashes missing shadows caseonly duplicates
 *                                               undeclared notpublic edges hubs cycles topics declared all
 *   rexx bin/bodyslam.rex blast DB TARGET [N]   what can break if TARGET (a class, or a file path end) changes
 *   rexx bin/bodyslam.rex catalogue DB [AREA]  one line per family: newest version, size, public classes, README
 *                                             (AREA: a path start such as packages/ or examples/)
 *   rexx bin/bodyslam.rex find DB WORD [N]      families whose name, README or public classes contain WORD
 *   rexx bin/bodyslam.rex kit DB DIR [REXX_PATH|- [CWD]]  what DIR's package will load, each against the newest
 *                                             version of its family (exit 0 PASS, 1 WARN, 3 FAIL)
 *   rexx bin/bodyslam.rex drift DB SPHERES ROOT [N]  every sphere citation checked against the estate at ROOT
 *   rexx bin/bodyslam.rex kitrun DB PKGDIR REPO [WORK]  each test of PKGDIR run as Autobuild runs it, with a
 *                                             stand-in rexx that records each program; kit on each (exit 0, 1, 3)
 *   rexx bin/bodyslam.rex sphere DB OUT COMMIT ROOT  the catalogue as an LLM Gopher sphere (alchemy-estate) in the
 *                                             Sphere Editor work tree OUT; ROOT is the checkout DB was read from
 *
 * Needs librexxsql.so on LD_LIBRARY_PATH and REXX_PATH holding src and the Rexx/SQL backend src.
 */
parse arg cmd rest
signal on syntax name failed
cmd = cmd~lower
select
  when cmd == 'ingest' then do
    parse var rest db root .
    if root == '' then call usage
    b = .BodySlam~new(root)
    counts = b~ingest(db)
    do k over .array~of('FILES', 'SCANNED', 'REQUIRES', 'USES', 'DECLARED', 'ABOUT', 'READ_SECONDS', 'STORE_SECONDS')
      say k~lower~left(14) counts[k]
    end
    b~session~close
  end
  when cmd == 'report' then do
    parse var rest db name
    if db == '' then call usage
    n = 20
    if datatype(name~word(name~words), 'W') then do
      n = name~word(name~words)
      name = name~subword(1, name~words - 1)
    end
    if name~strip == '' then name = 'summary'
    r = .BodySlamReport~new(db)
    names = name~lower
    if names == 'all' then names = 'summary ambiguous clashes missing shadows invalid caseonly duplicates undeclared notpublic edges hubs cycles topics declared'
    do one over names~makeArray(' ')
      say '==' one
      lines = report(r, one, n)
      do line over lines
        say line
      end
    end
    r~close
  end
  when cmd == 'catalogue' then do
    parse var rest db area .
    if db == '' then call usage
    r = .BodySlamReport~new(db)
    do line over r~catalogue(100000, area)
      say line
    end
    r~close
  end
  when cmd == 'sphere' then do
    parse var rest db out commit root .
    if root == '' then call usage
    r = .BodySlamReport~new(db)
    n = .BodySlamSphere~new(r, root, commit)~write(out)
    say 'sphere alchemy-estate:' n 'family articles written to' out
    r~close
  end
  when cmd == 'kit' then do
    parse var rest db dir rp cwd .
    if dir == '' then call usage
    if rp == '' then rp = value('REXX_PATH',, 'ENVIRONMENT')
    if rp == '-' then rp = ''
    if cwd == '' then cwd = dir
    r = .BodySlamReport~new(db)
    out = .BodySlamKit~new(r)~kit(dir, rp, cwd)
    do line over out
      say line
    end
    r~close
    if out[1]~word(2) == 'FAIL' then exit 3
    if out[1]~word(2) == 'WARN' then exit 1
  end
  when cmd == 'drift' then do
    parse var rest db spheres root n .
    if root == '' then call usage
    if n == '' then n = 25
    r = .BodySlamReport~new(db)
    do line over .BodySlamSphere~new(r, root, '')~drift(spheres, root, n)
      say line
    end
    r~close
  end
  when cmd == 'kitrun' then do
    parse var rest db pkg repo work .
    if repo == '' then call usage
    if work == '' then work = '/tmp/bodyslam_kitrun'
    r = .BodySlamReport~new(db)
    out = .BodySlamKit~new(r)~run(pkg, repo, work)
    do line over out
      say line
    end
    r~close
    if out[out~items]~word(2) == 'FAIL' then exit 3
    if out[out~items]~word(2) == 'WARN' then exit 1
  end
  when cmd == 'find' then do
    parse var rest db word n .
    if word == '' then call usage
    if n == '' then n = 25
    r = .BodySlamReport~new(db)
    do line over r~find(word, n)
      say line
    end
    r~close
  end
  when cmd == 'blast' then do
    parse var rest db target n .
    if target == '' then call usage
    if n == '' then n = 25
    r = .BodySlamReport~new(db)
    do line over r~blast(target, n)
      say line
    end
    r~close
  end
  otherwise call usage
end
exit 0

report: procedure
  use arg r, one, n
  select
    when one == 'summary' then return r~summary
    when one == 'ambiguous' then return r~ambiguous(n)
    when one == 'clashes' then return r~clashes(n)
    when one == 'missing' then return r~missing(n)
    when one == 'shadows' then return r~shadows(n)
    when one == 'invalid' then return r~invalid(n)
    when one == 'caseonly' then return r~caseOnly(n)
    when one == 'duplicates' then return r~duplicates(n)
    when one == 'undeclared' then return r~undeclared(n)
    when one == 'notpublic' then return r~notPublic(n)
    when one == 'edges' then return r~familyEdges(n)
    when one == 'hubs' then return r~hubs(n)
    when one == 'cycles' then return r~cycles
    when one == 'topics' then return r~topics(n)
    when one == 'declared' then return r~declared(n)
    when one == 'catalogue' then return r~catalogue(n)
    otherwise return .array~of('no report named' one)
  end

usage:
  say 'rexx bin/bodyslam.rex ingest DB ROOT | report DB [NAME [N]] | blast DB TARGET [N] | catalogue DB [AREA] | find DB WORD [N] | sphere DB OUT COMMIT ROOT | kit DB DIR [REXX_PATH [CWD]] | drift DB SPHERES ROOT [N] | kitrun DB PKGDIR REPO [WORK]'
  exit 2

failed:
  say 'Body Slam stopped: rc' rc 'at line' sigl '|' condition('C') '|' condition('D')
  c = condition('O')
  if c \== .nil then do
    if c~hasIndex('MESSAGE') then say c['MESSAGE']
    if c~hasIndex('TRACEBACK') then do t over c['TRACEBACK']; say t; end
  end
  exit 1

::requires 'BodySlam.cls'
::requires 'BodySlamReport.cls'
::requires 'BodySlamSphere.cls'
::requires 'BodySlamKit.cls'
