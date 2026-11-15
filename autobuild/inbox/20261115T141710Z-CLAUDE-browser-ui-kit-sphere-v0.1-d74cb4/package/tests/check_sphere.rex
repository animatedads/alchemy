/* check_sphere.rex -- the browser UI kit sphere: every JSON file parses with ooRexx json.cls, every article's id
 * starts with the sphere id (sphere.open finds the sphere from the article id), and start_here names articles that
 * exist.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 15 November 2026. */
parse arg root
if root = "" then root = "."
call SysFileTree root || "/*.json", "f.", "FSO"
docs = .array~new
bad = 0
do i = 1 to f.0
  s = .stream~new(f.i); s~open("read"); text = s~charin(1, s~chars); s~close
  d = parseDoc(text)
  if d = .nil then do
    say "FAIL JSON" f.i
    bad += 1
  end
  else docs~append(d)
end
ids = .directory~new
sphere = .nil
do d over docs
  if d["kind"] == "sphere" then sphere = d
  if d["kind"] == "article" then ids[d["id"]] = d
end
if sphere = .nil then do
  say "FAIL no sphere document"
  exit 1
end
do id over ids~allIndexes
  if id~left(sphere["id"]~length + 1) \== sphere["id"]"." then do
    say "FAIL article" id "does not start with" sphere["id"]"."
    bad += 1
  end
  if ids[id]["sphere"] \== sphere["id"] then do
    say "FAIL article" id "names sphere" ids[id]["sphere"]
    bad += 1
  end
end
do s over sphere["start_here"]
  if \ids~hasIndex(s) then do
    say "FAIL start_here names" s "which is not an article"
    bad += 1
  end
end
if ids~items < 6 then do
  say "FAIL expected at least 6 articles, found" ids~items
  bad += 1
end
if bad > 0 then exit 1
say "PASS sphere" sphere["id"]":" docs~items "JSON documents," ids~items "articles"
exit 0

parseDoc: procedure
  use arg text
  signal on syntax name unreadable
  return .json~new~fromJson(text)
unreadable:
  return .nil

::requires "json.cls"
