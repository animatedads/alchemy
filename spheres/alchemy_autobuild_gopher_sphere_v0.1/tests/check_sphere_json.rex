/* Alchemy Autobuild sphere v0.1 structural check: every pack/profile JSON parses with ooRexx json.cls.
 * Author: Claude (Opus 5.5), 2026-10-24. The Gopher activation test needs an LLM Gopher host. */
parse arg root
if root = "" then root = "."
call SysFileTree root || "/*.json", "f.", "FSO"
ok = 0
do i = 1 to f.0
  s = .stream~new(f.i); s~open("read"); text = s~charin(1, s~chars); s~close
  signal on syntax name bad
  doc = .json~fromJson(text)
  signal off syntax
  ok += 1
end
if ok < 12 then do; say "FAIL expected >= 12 JSON documents, found" ok; exit 1; end
say "PASS sphere JSON documents parse:" ok
exit 0
bad:
  say "FAIL JSON" f.i
  exit 1
::requires "json.cls"
