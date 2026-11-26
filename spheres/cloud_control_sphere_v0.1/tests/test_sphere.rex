/* test_sphere.rex: structural and continuity check of the cloud-control sphere.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 26 November 2026.
 * No runtime or network needed.  Prints PASS or FAIL lines; exit 0 only if all pass.
 * Note: JSON objects come back from json.cls as directories, so keys are read
 * with [] (exact case), never hasEntry (which uppercases: pitfall P6). */
parse source . . me
root = filespec('location', me)'..'
fails = 0

sphere   = readJson(root'/packs/cloud-control/00-sphere.json')
profile  = readJson(root'/profiles/cloud-control.json')
policy   = readJson(root'/packs/cloud-control/01-access-policy.json')
manifest = readJson(root'/SOURCE_MANIFEST.json')
corpus   = readJson(root'/packs/cloud-control/corpora/cloud-control.continuity.json')

call check sphere['id'] = 'cloud-control' & sphere['kind'] = 'sphere', 'sphere id and kind'
call check profile['id'] = 'cloud-control' & profile['packs']~hasItem('packs/cloud-control'), 'profile names packs/cloud-control'
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
call check manifest['sources']~items >= 8, 'at least 8 pinned sources'

call SysFileTree root'/packs/cloud-control/articles/*.json', 'files.', 'FO'
articles = .directory~new
do i = 1 to files.0
  name = filespec('name', files.i)
  name = left(name, length(name) - 5)
  articles[name] = readJson(files.i)
end
call check articles~items >= 8, 'at least 8 articles ('articles~items')'
do name over articles~allIndexes
  a = articles[name]
  call check a['id'] = name & a['sphere'] = 'cloud-control' & a['kind'] = 'article', name': id, sphere, kind'
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
call check corpus['sphere'] = 'cloud-control' & corpus['kind'] = 'corpus' & corpus['records']~items >= 10, 'continuity corpus has 10 or more records'

/* the design's load-bearing words must be present somewhere in the packs */
all = ''
call SysFileTree root'/packs/*.json', 'every.', 'FOS'
do i = 1 to every.0
  s = .stream~new(every.i); all = all s~charin(1, s~chars); s~close
end
do needle over .array~of('--add-only', 'REMOVE CIDR', 'NOTE kept (add-only)', 'Read-only file system', 'AWS_PAGER', 'NEEDS TOM', 'Port 22 rules are never touched', 'oorexx_logging', 'Tom Dyer', 'Claude (Opus 5.5)', 'Codex')
  call check all~pos(needle) > 0, 'packs mention' needle
end
q = .stream~new(root'/qualification/QUALIFICATION.md'); text = q~charin(1, q~chars); q~close
call check text~pos('NOT QUALIFIED') > 0, 'qualification says NOT QUALIFIED'

if fails = 0 then say 'PASS cloud-control sphere:' articles~items 'articles,' corpus['records']~items 'continuity records,' manifest['sources']~items 'pinned sources'
else say 'FAIL cloud-control sphere:' fails 'check(s) failed'
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
