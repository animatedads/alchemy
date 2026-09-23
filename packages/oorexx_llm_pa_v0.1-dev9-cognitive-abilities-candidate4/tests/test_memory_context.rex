parse source . . here
root = filespec("L", here)
path = root || "/memory-context-test.journal"
address command "rm -f" path
m = .LlmPaMemoryStore~new(path)
call must m~remember("ED209A", "video worker; use SSH procedure", "codex", "r1"), "remember A"
call must m~remember("ED209B", "video worker; Oracle Linux; use SSH procedure", "codex", "r2"), "remember B"
call must m~remember("ED209C", "audio worker; Azure; use SSH procedure", "codex", "r3"), "remember C"
call must m~remember("ED209D", "video worker; AWS; use SSH procedure", "codex", "r4"), "remember D"
call must m~remember("ED209E", "video worker; Google Compute Engine; use GCloud and SSH procedures", "codex", "r5"), "remember E"
call must m~remember("ED209H", "audio worker; use SSH procedure", "codex", "r6"), "remember H"
call must m~remember("ED209I", "video worker; Azure; use SSH procedure", "codex", "r7"), "remember I"
call must m~remember("ED209X", "Android phone; use SSH procedure", "codex", "r8"), "remember X"
call must m~remember("SSH", "use ./sshnode.sh rather than inventing SSH commands", "codex", "r9"), "remember SSH"
call must m~remember("GCloud", "use the supplied GCloud tool for Google operations", "codex", "r10"), "remember GCloud"
call must m~remember("FLEET_ROLES", "A/B/D/E/I video; C/H audio; X Android", "codex", "r11"), "remember fleet"

ctx = m~context("Summarise the ED209 fleet by role and provider", 16)
call must ctx, "fleet context"
call mustBool hasKey(ctx~value, "ED209A"), "fleet includes A"
call mustBool hasKey(ctx~value, "ED209B"), "fleet includes B"
call mustBool hasKey(ctx~value, "ED209C"), "fleet includes C"
call mustBool hasKey(ctx~value, "ED209D"), "fleet includes D"
call mustBool hasKey(ctx~value, "ED209E"), "fleet includes E"
call mustBool hasKey(ctx~value, "ED209H"), "fleet includes H"
call mustBool hasKey(ctx~value, "ED209I"), "fleet includes I"
call mustBool hasKey(ctx~value, "ED209X"), "fleet includes X"
call mustBool hasKey(ctx~value, "FLEET_ROLES"), "fleet includes grouped facts"
call mustBool hasKey(ctx~value, "SSH"), "fleet follows SSH reference"
call mustBool hasKey(ctx~value, "GCloud"), "fleet follows GCloud reference"

node = m~context("ED209E stopped responding. What do you remember?", 12)
call must node, "node context"
call mustBool hasKey(node~value, "ED209E"), "node includes E"
call mustBool hasKey(node~value, "GCloud"), "node follows GCloud"
call mustBool hasKey(node~value, "SSH"), "node follows SSH"

/* Ordinary remind remains narrow and therefore does not implicitly dump fleet. */
narrow = m~remind("ED209E")
call must narrow, "narrow remind"
call mustBool narrow~value~items = 1, "remind remains narrow"

address command "rm -f" path
say "PASS test_memory_context"
exit 0

hasKey: procedure
  use arg records, wanted
  do rec over records
    if rec["key"]~caselessEquals(wanted) then return .true
  end
  return .false
must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
return
mustBool: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 1; end
return
::requires "LlmPaCore.cls"
