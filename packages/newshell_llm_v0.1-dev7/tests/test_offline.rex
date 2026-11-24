/* test_offline.rex ROOT - newshell_llm v0.1-dev1, no network.
   Architecture: Tom Dyer. Coding: Claude (Opus 5.5). */
use strict arg root
proto = root'/build/proto_fs'
'rexx' root'/tests/make_proto_fs.rex' proto '>/dev/null'
call value 'NEWSHELL_FAKE_KEY', 'FAKE-NEWSHELL-KEY', 'ENVIRONMENT'

fs = .FileSystem~new(proto)
call check fs~fileCount = 5, 'five regular files (the link to / is not followed)'
call check fs~links~items~items = 1, 'the link is listed as a link'
call check fs~totalBytes = 266120, 'total bytes'
top = fs~files~sortedBy('size', 'D')~first(2)
call check top~items[1]~relPath == 'media/video.bin' & top~items[2]~relPath == 'logs/old/app.1.log', 'sortedBy size D, first 2'
call check fs~files~sortedBy('relPath')~items[1]~relPath == 'logs/app.log', 'sortedBy relPath A (caseless)'
n = 0; do f over fs; n += 1; end
call check n = 5, 'DO OVER fs gives the files'

claude = .Llm~start('claude', 'claude-haiku-5-5', 'NEWSHELL_FAKE_KEY', root'/tests/fixtures/fake_claude_curl.sh')
claude~provide('fs', fs)
call check claude~systemPrompt~pos('fs: a FILESYSTEM object') > 0, 'system prompt describes fs from the class'
call check claude~systemPrompt~pos('relPath') > 0, 'system prompt describes the items'

p = claude~prompt('find largest file')
call check claude~prompts = 2, 'two rounds: draft and review'
call check p~draft~pos('~bytes') > 0, 'draft called ~bytes'
call check p~code~pos('~bytes') = 0 & p~code~pos('~size') > 0, 'final uses ~size after the review'
call check p~code~pos('```') = 0, 'fences stripped'
call check p~state == 'CHECKED', 'final proposal checked'
call check p~methodsChecked > 0, 'method sources checked'
p~~table~~show~~sources

list = p~run
call check list~isA(.ShellCollection), 'run returns a ShellCollection'
call check list~items~items = 1, 'one file'
call check list~items[1]~relPath == 'media/video.bin', 'largest is media/video.bin'
call check list~items[1]~size = 250000, 'its size'
list~~table

cache = .MethodSourceCache~current
before = cache~hits
q = claude~prompt('find largest file')
call check cache~hits > before, 'second prompt served method sources from the cache'

-- the check, case by case
c = .ProposalCheck~new
call rejects c, 'address system "rm -rf /"' || '0a'x || 'return 1', 'ADDRESS'
call rejects c, 'if 1 then call lineout "x", "y"' || '0a'x || 'return 1', 'CALL after THEN'
call rejects c, "'rm -rf /tmp/x'" || '0a'x || 'return 1', 'bare string command'
call rejects c, 'x = .File~new("/")' || '0a'x || 'return x', '.File'
call rejects c, 'x = fs~class~new("/")' || '0a'x || 'return x', '~class'
call rejects c, 'interpret "say 1"' || '0a'x || 'return 1', 'INTERPRET'
call rejects c, 'x = SysFileDelete("/tmp/x")' || '0a'x || 'return x', 'Sys* function'
call rejects c, 'x = value("HOME",, "ENVIRONMENT")' || '0a'x || 'return x', 'VALUE()'
call rejects c, '::requires "x.cls"' || '0a'x || 'return 1', 'directive'
call rejects c, 'x = 1', 'no RETURN'
call rejects c, 'result = .Array~new' || '0a'x || 'result~append(1)' || '0a'x || 'return .ShellCollection~new(result)', 'RESULT as a variable'   -- P9-ok: the string under test
call check c~problems('x = .Array~new' || '0a'x || 'x~append(f~result)' || '0a'x || 'return x')~items = 0, '~result as a message name is fine'
call check c~problems("s = 'call address .File ~class'" || '0a'x || 'return s')~items = 0, 'words inside a string are not flagged'

-- defence in depth: even unchecked, a command string does not execute
-- (the same prologue ~run puts in front of a proposal)
rc = .Routine~new('p', .Array~of('address NEWSHELL_NONE', "'touch" proto"/HACKED'", 'return rc'), .context~package)~call
call check rc = 30 & \.File~new(proto'/HACKED')~exists, 'ADDRESS NEWSHELL_NONE: command not executed (rc' rc')'

-- a changed method source makes ~run refuse
r = claude~prompt('find largest file')
.FsFile~define('SIZE', 'expose size; return size + 0')
signal on syntax name refused
r~run
call check .false, 'run should refuse after a source change'
refused:
  signal off syntax
  call check condition('O')~message~pos('changed since the check') > 0, 'run refuses when a checked source changed'

say 'NEWSHELL_LLM OFFLINE: OK'
exit 0

check: procedure
  use arg ok, label
  if \ok then do; say 'FAILED:' label; exit 85; end
  say 'ok  ' label
  return
rejects: procedure
  use arg c, code, label
  if c~problems(code)~items = 0 then do; say 'FAILED: not rejected:' label; exit 85; end
  say 'ok   rejects' label
  return

::requires 'FileSystem.cls'
::requires 'ShellLlm.cls'
