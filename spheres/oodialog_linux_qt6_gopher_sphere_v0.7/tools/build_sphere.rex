/* build_sphere.rex -- make a Gopher sphere pack whose provenance is computed from git, not typed.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-15.
 *
 *   rexx tools/build_sphere.rex SPHERE_DIR REPO_DIR COMMIT
 *
 * SPHERE_DIR/source/sphere.json and SPHERE_DIR/source/access-policy.json are copied into
 * SPHERE_DIR/packs/<sphere id>/ as 00-sphere.json and 01-access-policy.json.  Each
 * SPHERE_DIR/source/articles/NAME.json is an article whose provenance entries name a member (a file of
 * REPO_DIR, as it is at COMMIT), the text the claim starts at ("find": the first line that contains it)
 * and how many lines it spans ("lines", 1 if absent).  The built article, in packs/<id>/articles/, has
 * instead artifact "<repo>@<commit>", sha256 of the member at COMMIT, line_start and line_end.
 * A "find" that is not in the member is an error: the build stops, and nothing is half-written.
 * Exit 0 when every article is built.
 */
parse arg sphereDir repoDir commit .
if commit == "" then do
  .error~lineout("usage: rexx build_sphere.rex SPHERE_DIR REPO_DIR COMMIT")
  exit 2
end
log = .ToolProgress~new("sphere-build", .context~package, "BUILD")~logger
tmp = value("TMPDIR",, "ENVIRONMENT"); if tmp == "" then tmp = "/tmp"
work = tmp"/sphere-build-"random(1, 99999)
call SysMkDir work

spec = .json~fromJsonFile(sphereDir"/source/sphere.json")
id = spec["id"]
repoName = spec["repository"]                         -- e.g. animatedads/oorexx
pack = sphereDir"/packs/"id
address system 'mkdir -p "'pack'/articles"'

members = .directory~new                                -- member -> (lines array, sha256)
built = .array~new
call SysFileTree sphereDir"/source/articles/*.json", "f.", "FO"
do i = 1 to f.0
  article = .json~fromJsonFile(f.i)
  out = .array~new
  do p over article["provenance"]
    m = p["member"]
    if \members~hasIndex(m) then members[m] = loadMember(repoDir, commit, m, work)
    lines = members[m][1]
    at = 0
    do n = 1 to lines~items
      if lines[n]~pos(p["find"]) > 0 then do; at = n; leave; end
    end
    if at == 0 then do
      log~log(.Log~ERROR, article["id"]": '"p["find"]"' is not in" m "at" commit)
      address system 'rm -r "'work'"'
      exit 1
    end
    span = 1; if p~hasIndex("lines") then span = p["lines"]
    e = .directory~new
    e["artifact"] = repoName"@"commit
    e["sha256"] = members[m][2]
    e["member"] = m
    e["line_start"] = at
    e["line_end"] = at + span - 1
    e["claim"] = p["claim"]
    out~append(e)
  end
  article["provenance"] = out
  article["sphere"] = id
  built~append(article)
  log~log(.Log~INFO, "built" article["id"] "(" out~items "sources)")
end
-- written only when every article resolved
do a over built
  .json~toJsonFile(pack"/articles/"a["id"]".json", a, .true)
end
s = .directory~new
do k over spec~allIndexes
  if k \== "repository" then s[k] = spec[k]
end
.json~toJsonFile(pack"/00-sphere.json", s, .true)
.json~toJsonFile(pack"/01-access-policy.json", .json~fromJsonFile(sphereDir"/source/access-policy.json"), .true)
-- The Gopher index loads a sphere through its profile: without profiles/<id>.json the sphere is never
-- listed (v0.1 of these spheres was merged without one and stayed unreadable).
prof = .directory~new
prof["kind"] = "profile"; prof["id"] = id; prof["version"] = spec["version"]
prof["packs"] = .array~of("packs/core", "packs/"id)
address system 'mkdir -p "'sphereDir'/profiles"'
.json~toJsonFile(sphereDir"/profiles/"id".json", prof, .true)
-- MANIFEST.sha256 lists every other file of the sphere; until v0.6 it was written by hand and went stale.
call SysFileTree sphereDir"/*", "found", "FSO"
names = .array~new
do i = 1 to found.0
  rel = found.i~substr(sphereDir~length + 2)
  if rel \== "MANIFEST.sha256" then names~append(rel)
end
names = names~sort
list = work"/manifest.list"
do n over names
  call lineout list, n
end
call stream list, "c", "close"
address system 'cd "'sphereDir'" && xargs -d "\n" sha256sum < "'list'" > MANIFEST.sha256'
if rc \== 0 then raise syntax 93.900 array ("MANIFEST.sha256 not written")
log~log(.Log~INFO, "MANIFEST.sha256:" names~items "files")
address system 'rm -r "'work'"'
log~log(.Log~INFO, built~items "articles in" pack)
exit 0

loadMember: procedure                                 -- the member's lines and sha256 at the commit
  use arg repoDir, commit, member, work
  file = work"/m"random(1, 999999)
  address system 'git -C "'repoDir'" show "'commit':'member'" > "'file'"'
  if rc \== 0 then raise syntax 93.900 array ("cannot read" member "at" commit)
  address system 'sha256sum "'file'" > "'file'.sha"'
  sha = linein(file".sha")~word(1)
  call stream file".sha", "c", "close"
  text = charin(file, 1, chars(file))
  call stream file, "c", "close"
  return .array~of(text~makeArray("0a"x), sha)

::requires "json.cls"
::requires "LogStreamTarget.cls"
