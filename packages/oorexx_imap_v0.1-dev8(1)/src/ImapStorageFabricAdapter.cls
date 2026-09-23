/* Optional Storage Fabric literal sink adapter.
 * Large IMAP response literals can be streamed directly into any
 * StorageByteSink without becoming a giant ooRexx String.
 */

::class ImapStorageLiteralSink public
::attribute length get
::method init
  expose sink length reference closed
  use strict arg sinkArg, totalLength
  sink = sinkArg; length = 0; closed = .false
  if \sink~hasMethod("OPENAT") | \sink~hasMethod("WRITECHUNK") then raise syntax 88.900 array("IMAP_STORAGE_SINK_INVALID")
  sink~openAt(0, totalLength)
  reference = ""
  if sink~hasMethod("RESUMEIDENTITY") then reference = sink~resumeIdentity
::method write
  expose sink length
  use strict arg chunk
  wrote = sink~writeChunk(chunk)
  if wrote <> chunk~length then return wrote
  length += wrote
  return wrote
::method finish
  expose sink closed
  if closed then return self
  if sink~hasMethod("FLUSH") then sink~flush
  sink~close
  closed = .true
  return self
::method kind
  return "STORAGE_FABRIC"
::method bytes
  return ""
::method reference
  expose reference
  return reference
::method uninit
  expose sink closed
  if \closed & sink <> .nil then sink~close

::class ImapStorageLiteralSinkFactory public
::method init
  expose provider
  use strict arg providerArg
  if \providerArg~hasMethod("CREATESTORAGESINK") then raise syntax 88.900 array("IMAP_STORAGE_PROVIDER_INVALID")
  provider = providerArg
::method createLiteralSink
  expose provider
  use strict arg length, record
  sink = provider~createStorageSink(length, record)
  if sink == .nil then raise syntax 88.900 array("IMAP_STORAGE_PROVIDER_NO_SINK")
  return .ImapStorageLiteralSink~new(sink, length)

::requires "ImapCore.cls"
::requires "StorageStreaming.cls"
