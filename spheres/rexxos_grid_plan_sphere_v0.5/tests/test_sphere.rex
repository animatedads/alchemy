/* test_sphere.rex: structural and continuity check of the rexxos-grid-plan sphere.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 25 November 2026.
 * No runtime or network needed.  Prints PASS or FAIL lines; exit 0 only if all pass.
 * Note: JSON objects come back from json.cls as directories, so keys are read
 * with [] (exact case), never hasEntry (which uppercases: pitfall P6). */
parse source . . me
root = filespec('location', me)'..'
fails = 0

sphere   = readJson(root'/packs/rexxos-grid-plan/00-sphere.json')
profile  = readJson(root'/profiles/rexxos-grid-plan.json')
policy   = readJson(root'/packs/rexxos-grid-plan/01-access-policy.json')
manifest = readJson(root'/SOURCE_MANIFEST.json')
corpus   = readJson(root'/packs/rexxos-grid-plan/corpora/rexxos-grid-plan.continuity.json')

call check sphere['id'] = 'rexxos-grid-plan' & sphere['kind'] = 'sphere', 'sphere id and kind'
call check profile['id'] = 'rexxos-grid-plan' & profile['packs']~hasItem('packs/rexxos-grid-plan'), 'profile names packs/rexxos-grid-plan'
call check policy['id'] = sphere['access_policy'], 'access policy matches the sphere'
writes = 0
do rule over policy['rules']
  if rule['actions']~hasItem('write') then writes = writes + 1
end
call check writes = 0, 'access policy grants no write'

sections = .set~new
do s over sphere['sections']; sections~put(s['id']); end
shas = .set~new
do key over manifest['sources']~allIndexes
  shas~put(manifest['sources'][key]['artifact'] manifest['sources'][key]['sha256'])
end
call check manifest['sources']~items >= 4, 'at least 4 pinned sources'

call SysFileTree root'/packs/rexxos-grid-plan/articles/*.json', 'files.', 'FO'
articles = .directory~new
do i = 1 to files.0
  name = filespec('name', files.i)
  name = left(name, length(name) - 5)
  articles[name] = readJson(files.i)
end
call check articles~items >= 4, 'at least 4 articles ('articles~items')'
do name over articles~allIndexes
  a = articles[name]
  call check a['id'] = name & a['sphere'] = 'rexxos-grid-plan' & a['kind'] = 'article', name': id, sphere, kind'
  call check sections~hasIndex(a['section']), name': section exists'
  call check a['invariants']~items > 0 & a['provenance']~items > 0, name': invariants and provenance'
  do p over a['provenance']
    call check verify(p['sha256'], '0123456789abcdef') = 0 & length(p['sha256']) = 64, name': sha256 is 64 hex'
    call check shas~hasIndex(p['artifact'] p['sha256']), name': provenance pinned in SOURCE_MANIFEST'
  end
  do r over a['related']
    call check articles~hasIndex(r), name': related' r 'exists'
  end
end
do entry over sphere['start_here']
  call check articles~hasIndex(entry), 'start_here' entry 'exists'
end
call check corpus['sphere'] = 'rexxos-grid-plan' & corpus['kind'] = 'corpus' & corpus['records']~items >= 7, 'continuity corpus has 7 or more records'

/* the design's load-bearing words must be present somewhere in the packs */
all = ''
call SysFileTree root'/packs/*.json', 'every.', 'FOS'
do i = 1 to every.0
  s = .stream~new(every.i); all = all s~charin(1, s~chars); s~close
end
do needle over .array~of('cats2', 'ed209l', 'rebooting and deallocating', 'network security group', 'serial console', 'MU_READY', 'advertise', 'cluster arbitrator', 'xtpd', 'Ed25519', 'namespace containers', 'rebuild', 'Tom Dyer', 'Claude (Opus 5.5)', 'Claude (Fable 5.2)', 'boot is the test')
  call check all~pos(needle) > 0, 'packs mention' needle
end
q = .stream~new(root'/qualification/QUALIFICATION.md'); text = q~charin(1, q~chars); q~close
call check text~pos('NOT QUALIFIED') > 0, 'qualification says NOT QUALIFIED'

if fails = 0 then say 'PASS rexxos-grid-plan sphere:' articles~items 'articles,' corpus['records']~items 'continuity records,' manifest['sources']~items 'pinned sources'
else say 'FAIL rexxos-grid-plan sphere:' fails 'check(s) failed'
exit (fails > 0)

check: procedure expose fails
  use arg ok, label
  if \ok then do
    fails = fails + 1
    say 'FAIL' label
  end
  return

readJson: procedure
  use arg path
  return .json~fromJsonFile(path)

::requires 'json.cls'
