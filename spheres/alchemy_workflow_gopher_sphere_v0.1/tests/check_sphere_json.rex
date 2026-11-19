/* check_sphere_json.rex - Alchemy Workflow sphere v0.1: every JSON document parses with ooRexx json.cls, every
 * article names this sphere and has a summary, and no provenance entry is left unsealed ("FILL").
 * Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-11-19. The Gopher activation test needs an LLM Gopher host.
 */
parse arg root
if root = '' then root = '.'
signal on syntax name bad
call SysFileTree root || '/*.json', 'f.', 'FSO'
docs = .array~new
do i = 1 to f.0
  docs~append(f.i)
end
ok = 0
articles = 0
do path over docs
  s = .stream~new(path)
  s~open('read')
  text = s~charIn(1, s~chars)
  s~close
  if text~pos('"FILL"') > 0 then do
    say 'FAIL unsealed provenance in' path '(run tools/wf_sphere_seal.rex)'
    exit 1
  end
  doc = .json~fromJson(text)
  ok += 1
  if \doc~isA(.Directory) then iterate
  if doc['kind'] \== 'article' then iterate
  articles += 1
  if doc['sphere'] \== 'alchemy-workflow' then do
    say 'FAIL' path 'names sphere' doc['sphere']
    exit 1
  end
  if doc['summary'] == .nil then do
    say 'FAIL' path 'has no summary'
    exit 1
  end
end
if articles < 6 then do
  say 'FAIL expected at least 6 articles, found' articles
  exit 1
end
say 'PASS sphere JSON documents parse:' ok '| articles:' articles
exit 0
bad:
  say 'FAIL JSON' path
  exit 1
::requires 'json.cls'
