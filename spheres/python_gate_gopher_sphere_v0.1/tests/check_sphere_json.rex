/* The Python gate (oorexx_python_gate, Autobuild v0.5.3) sphere v0.1 structural check: every JSON document parses with ooRexx json.cls,
 * and every article has the fields a Gopher article needs, with at least one provenance entry.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-15. */
parse arg root
if root = "" then root = "."
call SysFileTree root || "/packs/*.json", "f.", "FSO"
ok = 0; articles = 0
do i = 1 to f.0
  signal on syntax name bad
  doc = .json~fromJsonFile(f.i)
  signal off syntax
  ok += 1
  if doc["kind"] == "article" then do
    articles += 1
    do field over .array~of("id", "version", "sphere", "title", "summary", "invariants", "provenance")
      if \doc~hasIndex(field) then do; say "FAIL" f.i "has no" field; exit 1; end
    end
    if doc["provenance"]~items < 1 then do; say "FAIL" f.i "cites nothing"; exit 1; end
  end
end
if articles < 3 then do; say "FAIL expected 3 articles, found" articles; exit 1; end
say "PASS" ok "JSON documents parse;" articles "articles have their fields and sources"
exit 0
bad:
  say "FAIL JSON" f.i
  exit 1
::requires "json.cls"
