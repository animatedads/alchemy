/* test_live.rex ROOT [MODEL] - newshell_llm v0.1-dev1 against the real API.
   Architecture: Tom Dyer. Coding: Claude (Opus 5.5).
   Needs ANTHROPIC_API_KEY in the environment; it is read by the Secret
   Broker and reaches curl only on stdin. */
use strict arg root, model = 'claude-haiku-5-5'
proto = root'/build/proto_fs'
'rexx' root'/tests/make_proto_fs.rex' proto '>/dev/null'
claude = .Llm~start('claude', model)
claude~provide('fs', .FileSystem~new(proto))
p = claude~prompt('find largest file')
say '--- draft'; say p~draft
say '--- proposal'; p~~table~~show~~sources
if p~state \== 'CHECKED' then do; say 'FAILED: proposal' p~state; exit 85; end
list = p~run
say '--- result'; list~~table
claude~~table
if list~isA(.ShellCollection), list~items~items > 0, list~items[1]~relPath == 'media/video.bin' then do
  say 'NEWSHELL_LLM LIVE: OK'
  exit 0
end
say 'FAILED: largest file was not media/video.bin'
exit 85
::requires 'FileSystem.cls'
::requires 'ShellLlm.cls'
