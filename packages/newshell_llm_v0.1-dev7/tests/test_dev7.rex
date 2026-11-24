/* test_dev7.rex ROOT - newshell_llm v0.1-dev7: the native providers under the file
   objects, FsFolder, the disk watch, and the source editor as a shell object.
   Architecture: Tom Dyer. Coding: Claude (Opus 5.5). Providers: ChatGPT (dev10).
   Runs in both modes: native when the providers load (ooRexx 5.3 with the library),
   plain Rexx otherwise; the mode is printed and the native checks run only in it. */
use strict arg root
numeric digits 20          -- byte counts run past 9 digits
mode = .ShellNative~mode
say 'mode' mode .ShellNative~whyNot
call check .ShellNative~pageSize > 0, 'page size' .ShellNative~pageSize
call check .LinuxProcess~pageSizeAware == .true, 'LinuxProcess says it is page-size aware (ChatGPT override steps aside)'
me = .Computer~new~process(SysQueryProcess('PID'))
call check me~rssKiB > 0, 'own rssKiB' me~rssKiB

proto = root'/build/dev7_fs'
'rm -rf' proto
'mkdir -p' proto'/notes/sub' proto'/logs'
call put proto'/notes/hello.rex', 'say "hello"' || '0a'x || 'call x~y' || '0a'x || 'exit 0'
call put proto'/logs/app.rex', 'say "app"' || '0a'x || 'exit 0'
'chmod 640' proto'/notes/hello.rex'
'ln -s /etc' proto'/notes/etclink'
fs = .FileSystem~new(proto)

-- FsFolder
d = fs~folder('notes')
call check d~kind == 'folder' & d~class~id == 'FSFOLDER', 'fs~folder gives an FsFolder'
names = .Array~new; do e over d~entries; names~append(e~kind':'e~name); end
names = names~sort~makeString('L', ' ')
call check names == 'file:hello.rex folder:sub link:etclink', 'entries: own files, folders, link listed ('names')'
call check d~files~items~items = 1 & d~folders~items~items = 1, 'files and folders split'
call check fs~file('notes')~class~id == 'FSFOLDER', 'fs~file on a folder gives an FsFolder'
call check fs~folders~items~items = 3, 'fs~folders walks the tree (notes, notes/sub, logs)'
call check d~entries(2)~items~items = 2, 'entries(n) is bounded'

-- native metadata and identity
f = fs~file('notes/hello.rex')
if mode == 'native' then do
  call check f~mode == '0640', 'mode 0640 from stat'
  call check f~identity~pos('@') > 0, 'identity carries device:inode ('f~identity')'
  before = f~identity
  call put proto'/notes/hello.new', 'say "replaced"'
  'mv' proto'/notes/hello.new' proto'/notes/hello.rex'
  call check \f~isCurrent, 'a file replaced by rename is no longer current (inode changed)'
  call check fs~file('notes/hello.rex')~identity \== before, 'and has a new identity'
  call put proto'/notes/hello.rex', 'say "hello"' || '0a'x || 'call x~y' || '0a'x || 'exit 0'
end
else say 'skip  native metadata checks (mode rexx)'

-- disk watch: free bytes from statvfs (native) or df
free = diskFreeProbe(proto)
call check datatype(free, 'W') & free > 0, 'free bytes under the test root:' free

-- source editor as a shell object, as llm, under a policy that allows notes/ only
policy = root'/build/dev7.policy'
call SysFileDelete policy
do line over .Array~of('allow llm SourceFile amend' proto'/notes', 'allow llm SourceFile save' proto'/notes', 'deny * * * *')
  call lineout policy, line
end
call stream policy, 'c', 'close'
call value 'NEWSHELL_POLICY', policy, 'ENVIRONMENT'
call value 'NEWSHELL_FAKE_KEY', 'FAKE-NEWSHELL-KEY', 'ENVIRONMENT'
pol = .ShellPolicy~reload
claude = .Llm~start('claude', 'claude-haiku-5-5', 'NEWSHELL_FAKE_KEY', root'/tests/fixtures/fake_claude_curl.sh')
claude~provide('fs', fs)
sp = claude~systemPrompt
call check sp~pos('SOURCEFILE') > 0 & sp~pos('amend') > 0, 'the LLM is told about SourceFile (via FsFile~relatedSamples)'

src = fs~file('notes/hello.rex')~openSource
call check src~lineCount = 3 & src~line(1) == 'say "hello"', 'read: lineCount and line'
call check src~find('say')~items~items = 1, 'find'
call check src~grep('?ello')~items~items = 1, 'grep: ? is any one character'
lint = src~lint
call check lint~items~items = 1 & lint~items[1]~rule == 'P7', 'lint finds P7 (call x~y)'
ck = src~check
call check \ck~ok & ck~line = 2, 'check: call x~y does not compile, reported on line 2 ('ck~code ck~message')'

p = proposal(claude, "s = fs~file('notes/hello.rex')~openSource" || '0a'x ||,
  "old = s~amend(2, 2, 'x~y')" || '0a'x || "s~save" || '0a'x || 'return old')
call check p~state == 'CHECKED', 'amend-and-save proposal passes the check'
old = p~run
call check readFile(proto'/notes/hello.rex')~pos('call x~y') = 0, 'notes/hello.rex amended and saved'
call check fs~file('notes/hello.rex')~openSource~lint~items~items = 0, 'and its lint is now clean'
call check fs~file('notes/hello.rex')~openSource~check~ok, 'and it now compiles'

before = readFile(proto'/logs/app.rex')
p = proposal(claude, "s = fs~file('logs/app.rex')~openSource" || '0a'x || "s~amend(1, 1, 'say 1')" || '0a'x || 'return 1')
call refused p, 'SourceFile~amend', 'amend outside notes/ refused by the security manager'
call check readFile(proto'/logs/app.rex') == before, 'logs/app.rex unchanged'

p = proposal(claude, "s = fs~file('notes/hello.rex')~openSource" || '0a'x || "s~amend(1, 1, 'do forever')" || '0a'x || "s~save" || '0a'x || 'return 1')
call failsWith p, 'edit refused', 'save refuses an edit that breaks a compiling file'
call check readFile(proto'/notes/hello.rex')~pos('do forever') = 0, 'the broken text was not written'

say 'NEWSHELL_LLM DEV7: OK ('mode')'
exit 0

diskFreeProbe: procedure
  use strict arg path
  c = .ShellNative~capacity(path)
  if c \== .nil then return c['free']
  return 1      -- rexx mode: diskFree uses df, covered by test_jobs

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

failsWith: procedure
  use strict arg p, expect, label
  signal on syntax name failed
  x = p~run
  say 'FAILED: did not fail:' label; exit 85
failed:
  c = condition('O')
  text = c~message
  if c~additional \== .nil then text = text c~additional~makeString('L', ' ')
  if text~pos(expect) = 0 then do; say 'FAILED:' label '-' c~code text; exit 85; end
  say 'ok  ' label
  return

put: procedure
  use strict arg path, text
  s = .Stream~new(path); s~open('WRITE REPLACE'); s~lineOut(text); s~close
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
::requires 'Computer.cls'
::requires 'ShellLlm.cls'
::requires 'ShellNative.cls'
