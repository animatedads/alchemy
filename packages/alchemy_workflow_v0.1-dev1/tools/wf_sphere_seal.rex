#!/usr/bin/env rexx
/* wf_sphere_seal.rex - Alchemy Workflow v0.1-dev1: seal a gopher sphere's provenance and manifest.
 *
 * Architecture: Tom Dyer (development is documented in a Rasen Falcon sphere, so other chats can read it).
 * Code: Claude (Opus 5.5), 2026-11-19.
 *
 *   rexx tools/wf_sphere_seal.rex SPHEREDIR REPO ARTIFACT
 *
 * Every provenance entry in the sphere's article packs is written with "sha256": "FILL". This fills each one,
 * in order, with the SHA-256 of the file its "member" names in REPO, sets "artifact" to ARTIFACT (for example
 * animatedads/alchemy@workflow/v0.1-dev1-20261111), checks that the cited line range exists in that file, and
 * writes MANIFEST.sha256 over every file of the sphere. Hashing goes through crypto v0.8.3 and the Foreign
 * Runtime (WorkflowHash). The JSON text is edited in place, never re-serialised, so "0.1" stays a string.
 * Exit 0 when sealed; 1 when a member or line range is wrong (nothing is written then).
 */
parse arg dir repo artifact .
signal on syntax name failed
if artifact == '' then do
  say 'usage: rexx tools/wf_sphere_seal.rex SPHEREDIR REPO ARTIFACT'
  exit 2
end
dir = .File~new(dir)~absolutePath
repo = .File~new(repo)~absolutePath
if \.WorkflowHash~available then do
  say 'wf_sphere_seal: no Foreign Runtime hashing:' .WorkflowHash~why
  exit 1
end
call SysFileTree dir || '/packs/*.json', 'f.', 'FSO'
packs = .array~new
do i = 1 to f.0
  packs~append(f.i)
end
bad = 0
sealed = .directory~new
do p over packs~sort
  text = readText(p)
  doc = .json~fromJson(text)
  if \doc~isA(.Directory) then iterate
  prov = doc['provenance']
  if prov == .nil then iterate
  do e over prov
    member = e['member']~string
    path = repo || '/' || member
    if \SysFileExists(path) then do
      say 'FAIL' p~substr(dir~length + 2) || ': no file' member
      bad += 1
      iterate
    end
    lines = countLines(path)
    if e['line_end'] > lines then do
      say 'FAIL' p~substr(dir~length + 2) || ':' member 'has' lines 'lines, the claim cites' e['line_start'] || '-' || e['line_end']
      bad += 1
      iterate
    end
    sum = .WorkflowHash~file(path)
    at = text~pos('"sha256": "FILL"')
    if at = 0 then iterate
    text = text~left(at - 1) || '"sha256": "' || sum || '"' || text~substr(at + 16)
    at = text~pos('"artifact": "FILL"')
    if at > 0 then text = text~left(at - 1) || '"artifact": "' || artifact || '"' || text~substr(at + 18)
  end
  sealed[p] = text
end
if bad > 0 then do
  say bad 'provenance entr(ies) wrong: nothing written'
  exit 1
end
n = 0
do p over sealed~allIndexes
  call writeText p, sealed[p]
  n += 1
end
/* the manifest: every file but itself, relative, sorted */
call SysFileTree dir || '/*', 'g.', 'FSO'
all = .array~new
do i = 1 to g.0
  rel = g.i~substr(dir~length + 2)
  if rel \== 'MANIFEST.sha256' then all~append(rel)
end
m = ''
do rel over all~sort
  m = m || .WorkflowHash~file(dir || '/' || rel) || '  ' || rel || '0a'x
end
call writeText dir || '/MANIFEST.sha256', m
say 'sealed' n 'pack file(s);' all~items 'file(s) in MANIFEST.sha256'
exit 0

readText: procedure
  use strict arg path
  s = .stream~new(path)
  s~open('read')
  t = s~charIn(1, s~chars)
  s~close
  return t

writeText: procedure
  use strict arg path, text
  call SysFileDelete path
  s = .stream~new(path)
  s~open('write replace')
  s~charOut(text)
  s~close
  return

countLines: procedure
  use strict arg path
  s = .stream~new(path)
  s~open('read')
  n = 0
  do while s~lines > 0
    t = s~lineIn
    n += 1
  end
  s~close
  return n

failed:
  c = condition('O')
  say 'wf_sphere_seal: Error' c['CODE'] c['ERRORTEXT']
  say '   ' c['MESSAGE']
  say '    line' c['POSITION'] 'of' c['PROGRAM']
  exit 3

::requires 'WorkflowHash.cls'
::requires 'json.cls'
