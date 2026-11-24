/* test_security.rex ROOT - newshell_llm v0.1-dev2: the security manager
   decides protected calls from the object's path.
   Architecture: Tom Dyer. Coding: Claude (Opus 5.5). No network. */
use strict arg root
proto = root'/build/sec_fs'
'rm -rf' proto
'rexx' root'/tests/make_proto_fs.rex' proto '>/dev/null'
'ln -s /etc' proto'/notes/etclink'
policy = root'/build/test.policy'
call SysFileDelete policy
call lineout policy, '# test policy: llm may change files only under notes/'
call lineout policy, 'allow llm FileSystem create' proto'/notes'
call lineout policy, 'allow llm FsFile edit' proto'/notes'
call lineout policy, 'allow llm FileEditor addline' proto'/notes'
call lineout policy, 'deny * * * *'
call stream policy, 'c', 'close'
call value 'NEWSHELL_POLICY', policy, 'ENVIRONMENT'
call value 'NEWSHELL_FAKE_KEY', 'FAKE-NEWSHELL-KEY', 'ENVIRONMENT'
pol = .ShellPolicy~reload
call check pol~ruleCount = 4, 'policy loaded: 4 rules'

fs = .FileSystem~new(proto)
claude = .Llm~start('claude', 'claude-haiku-5-5', 'NEWSHELL_FAKE_KEY', root'/tests/fixtures/fake_claude_curl.sh')
claude~provide('fs', fs)
sp = claude~systemPrompt
call check sp~pos('protected') > 0 & sp~pos('create') > 0 & sp~pos('addline') > 0, 'system prompt lists the protected methods'
call check sp~pos('FILEEDITOR') > 0, 'system prompt describes FileEditor (reached through relatedSamples)'

-- 1. allowed: create, edit, addLine under notes/
p = proposal(claude, "f = fs~create('notes/test.txt')" || '0a'x || "f~edit~addLine('test 1234')" || '0a'x || 'return .ShellCollection~new(.Array~of(f))')
call check p~state == 'CHECKED', 'allowed proposal checks'
list = p~run
call check readFile(proto'/notes/test.txt') == 'test 1234', 'notes/test.txt holds "test 1234"'
d = p~decisions
call check d~items~items = 3, 'three decisions recorded'
ok = .true; do x over d~items; if x~verdict \== 'allow' then ok = .false; end
call check ok, 'all three allowed'
d~~table

-- 2. denied: edit outside notes/
before = readFile(proto'/logs/app.log')~length
p = proposal(claude, "fs~file('logs/app.log')~edit~addLine('intruder')" || '0a'x || 'return 1')
call check p~state == 'CHECKED', 'denied proposal still passes the lint (the manager decides)'
call refused p, 'FsFile~edit', 'edit of logs/app.log refused'
call check readFile(proto'/logs/app.log')~length = before, 'logs/app.log unchanged'
call check p~state == 'FAILED', 'proposal state FAILED'
p~decisions~~table

-- 3. a path through a symbolic link is refused before any rule is read
p = proposal(claude, "f = fs~create('notes/etclink/newshell_evil')" || '0a'x || 'return 1')
call refused p, 'through link', 'create through notes/etclink (-> /etc) refused'
call check \.File~new('/etc/newshell_evil')~exists, 'nothing created in /etc'

-- 4. the manager alone, with the lint and ADDRESS NEWSHELL_NONE out of the way
call raw 'llm', "'touch" proto"/HACKED'", 'command refused for llm'
call check \.File~new(proto'/HACKED')~exists, 'command did not run'
call raw 'llm', 'x = lineout("'proto'/S", "y")', 'stream refused for llm'
call check \.File~new(proto'/S')~exists, 'stream not written'
call raw 'llm', 'x = .Foo', '.foo refused for llm'
call raw 'llm', 'x = SysFileDelete("'proto'/notes/readme.txt")', 'external call refused for llm'
call check .File~new(proto'/notes/readme.txt')~exists, 'readme.txt still there'

-- 5. console principal: no console rule in this policy, so even a person is refused
call raw 'console', "f = .FileSystem~new('"proto"')~create('notes/by_hand.txt')", 'console create refused: no rule for console'

-- 6. a rule is matched on path boundaries: notes2 is not under notes
'mkdir -p' proto'/notes2'
p = proposal(claude, "f = fs~create('notes2/x.txt')" || '0a'x || 'return 1')
call refused p, 'rule 5', 'notes2/ does not match the notes rule (falls to the catch-all deny)'

-- 7. policy file errors are reported
bad = root'/build/bad.policy'
call SysFileDelete bad
call lineout bad, 'allow llm FsFile edit'
call stream bad, 'c', 'close'
signal on syntax name badPolicy
x = .ShellPolicy~load(bad)
call check .false, 'a 4-word rule should be refused'
badPolicy:
  signal off syntax
  call check condition('O')~message~pos('need verdict principal class method path') > 0, 'malformed policy line refused'

say 'NEWSHELL_LLM SECURITY: OK'
exit 0

proposal: procedure
  use strict arg llm, code
  p = .Proposal~new(llm, 'test', code)
  p~setFinal(code)
  return p

refused: procedure
  use strict arg p, expect, label
  signal on syntax name wasRefused
  x = p~run
  say 'FAILED: not refused:' label; exit 85
wasRefused:
  c = condition('O')
  if c~code \== '98.948' then do; say 'FAILED:' label '- wrong error' c~code c~message; exit 85; end
  found = .false
  do d over p~decisions~items; if d~verdict == 'deny', (d~target~caselessPos(expect) > 0 | d~rule~caselessPos(expect) > 0) then found = .true; end
  if \found then do; say 'FAILED:' label '- no deny decision naming' expect; exit 85; end
  say 'ok  ' label
  return

raw: procedure
  use strict arg principal, line, label
  r = .Routine~new('raw', .Array~of(line, 'return 0'), .context~package)
  r~setSecurityManager(.ShellSecurityManager~new(principal))
  signal on syntax name rawRefused
  r~call
  say 'FAILED: not refused:' label; exit 85
rawRefused:
  if condition('O')~code \== '98.948' then do; say 'FAILED:' label condition('O')~message; exit 85; end
  say 'ok  ' label
  return

readFile: procedure
  use strict arg path
  s = .Stream~new(path); s~open('READ')
  text = s~charIn(1, s~chars)~strip('T', '0a'x)
  s~close
  return text

check: procedure
  use arg ok, label
  if \ok then do; say 'FAILED:' label; exit 85; end
  say 'ok  ' label
  return

::requires 'FileSystem.cls'
::requires 'ShellLlm.cls'
