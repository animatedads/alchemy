/* make_proto_fs.rex DIR - builds the prototype file system the tests use.
   Architecture: Tom Dyer. Coding: Claude (Opus 5.5).
   Known sizes, so the answer is known: media/video.bin (250000) is largest.
   Also a symbolic link to / that a walk must not follow, and an empty dir. */
use strict arg dir
if dir == '' then do; say 'usage: make_proto_fs.rex DIR'; exit 2; end
call make dir'/notes/readme.txt', 120
call make dir'/logs/app.log', 4000
call make dir'/logs/old/app.1.log', 9000
call make dir'/media/video.bin', 250000
call make dir'/media/thumb.png', 3000
.File~new(dir'/empty')~makeDirs
if \SysIsFileLink(dir'/rootlink') then 'ln -s /' dir'/rootlink'
say 'prototype file system at' dir
exit 0
make: procedure
  use strict arg path, size
  .File~new(filespec('location', path))~makeDirs
  call SysFileDelete path
  call charout path, copies('x', size)
  call stream path, 'c', 'close'
  return
