call testEofGuard
call testOverlongCompletedLine
call testUnterminatedMultilineBound
say 'review_repro_io: COMPLETE'
exit 0

testEofGuard:
  io=.SmtpClientIo~new(.EofTransport~new)
  signal on syntax name eofSyntax
  r=io~readReply
  signal off syntax
  if r==.nil then do; say 'EOF_GUARD: SAFE_NIL'; return; end
  say 'EOF_GUARD: UNEXPECTED_REPLY'; return
 eofSyntax:
  say "review eof syntax rc=" rc "sigl=" sigl "condition=" condition("C") "detail=" condition("D")
  say 'EOF_GUARD: SYNTAX' condition('D')
return

testOverlongCompletedLine:
  t=.OneChunkTransport~new('250 '||copies('A',64)||'0d0a'x)
  io=.SmtpClientIo~new(t)
  line=io~readLine(16)
  if line==.nil then say 'OVERLONG_COMPLETED: REJECTED'
  else say 'OVERLONG_COMPLETED: ACCEPTED len='||line~length
return

testUnterminatedMultilineBound:
  a=.array~new
  a~append('250-first'||'0d0a'x)
  do i=1 to 120; a~append('250-'||copies('B',20)||'0d0a'x); end
  a~append('250 done'||'0d0a'x)
  io=.SmtpClientIo~new(.ChunkListTransport~new(a))
  r=io~readReply
  if r==.nil then say 'MULTILINE_BOUND: REJECTED'
  else say 'MULTILINE_BOUND: ACCEPTED lines='||r~lines~items
return

::class EofTransport public
::method recv; use strict arg n; return ''
::method send; use strict arg data; return data~length

::class OneChunkTransport public
::method init; expose chunk used; use strict arg c; chunk=c; used=.false
::method recv; expose chunk used; use strict arg n; if used then return ''; used=.true; return chunk
::method send; use strict arg data; return data~length

::class ChunkListTransport public
::method init; expose chunks idx; use strict arg a; chunks=a; idx=1
::method recv
  expose chunks idx
  use strict arg n
  if idx>chunks~items then return ''
  c=chunks[idx]; idx+=1; return c
::method send; use strict arg data; return data~length

::requires 'src/SmtpOutboundDispatcher.cls'
