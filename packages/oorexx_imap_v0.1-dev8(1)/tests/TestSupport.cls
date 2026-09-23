::class ImapScriptedTransport public
::attribute writes get
::method init
  expose chunks chunkIndex pending writes closed
  use strict arg chunksArg
  chunks = chunksArg
  chunkIndex = 1
  pending = ""
  writes = .array~new
  closed = .false
::method read
  expose chunks chunkIndex pending
  use strict arg maximum = 0
  if pending <> "" then chunk = pending
  else do
    if chunkIndex > chunks~items then return ""
    chunk = chunks[chunkIndex]
    chunkIndex += 1
  end
  pending = ""
  if maximum > 0 & chunk~length > maximum then do
    head = chunk~left(maximum)
    pending = chunk~substr(maximum + 1)
    return head
  end
  return chunk
::method writeAll
  expose writes
  use strict arg data
  writes~append(data)
  return .true
::method close
  expose closed; closed = .true

::class ImapChunkLiteralSource public
::method init
  expose chunks chunkIndex pending
  use strict arg chunksArg
  chunks = chunksArg; chunkIndex = 1; pending = ""
::method read
  expose chunks chunkIndex pending
  use strict arg maximum = 16384
  if pending <> "" then chunk = pending
  else do
    if chunkIndex > chunks~items then return ""
    chunk = chunks[chunkIndex]; chunkIndex += 1
  end
  pending = ""
  if chunk~length > maximum then do
    head = chunk~left(maximum); pending = chunk~substr(maximum + 1); return head
  end
  return chunk
