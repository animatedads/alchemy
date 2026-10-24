/* MVS Alchemy Services -> Instrumentation Mesh adapter.
 *
 * MAS remains authoritative for session, frame and operation semantics.
 * Instrumentation Mesh owns common observation vocabulary, snapshots,
 * publication/history and collector query semantics.  This adapter grants no
 * mutation authority and carries no credentials or provider-private handles.
 */

::class MasInstrumentationBuild public
::constant API "mvs.alchemy.instrumentation/0.1"
::constant RELEASE "0.1-dev3-pre22"
::constant PRODUCT "mvs-alchemy-services"
::constant PROTOCOL "mvs.alchemy/1"

::class MasInstrumentationMetric public
::constant SESSIONS_ACCEPTED_TOTAL "mas.sessions.accepted.total"
::constant SESSIONS_CLOSED_TOTAL "mas.sessions.closed.total"
::constant SESSIONS_ACTIVE "mas.sessions.active"
::constant FRAMES_RECEIVED_TOTAL "mas.frames.received.total"
::constant FRAMES_SENT_TOTAL "mas.frames.sent.total"
::constant IO_BYTES_IN_TOTAL "mas.io.bytes.in.total"
::constant IO_BYTES_OUT_TOTAL "mas.io.bytes.out.total"
::constant OPERATION_ACCEPTED_TOTAL "mas.operation.accepted.total"
::constant OPERATION_COMPLETED_TOTAL "mas.operation.completed.total"
::constant OPERATION_FAILED_TOTAL "mas.operation.failed.total"
::constant PROTOCOL_ERRORS_TOTAL "mas.protocol.errors.total"
::constant TRANSPORT_FAILURES_TOTAL "mas.transport.failures.total"

::class MasInstrumentationSource public
::method init
  expose emitter activeSessions baseDimensions identity
  use strict arg identityArg, dimensionsArg=.nil
  if identityArg == .nil then raise syntax 88.900 array("MAS_INSTRUMENTATION_IDENTITY_REQUIRED")
  identity=.InstrumentationCodec~copyDirectory(identityArg)
  baseDimensions=.InstrumentationCodec~copyDirectory(dimensionsArg)
  baseDimensions["product"]=.MasInstrumentationBuild~PRODUCT
  baseDimensions["release"]=.MasInstrumentationBuild~RELEASE
  baseDimensions["protocol"]=.MasInstrumentationBuild~PROTOCOL
  baseDimensions["service_role"]="gateway"
  emitter=.InstrumentationEmitter~new(identity)
  activeSessions=0
  emitter~gaugeSet(.MasInstrumentationMetric~SESSIONS_ACTIVE,0,"count",baseDimensions)
  emitter~setHealth(.InstrumentationHealth~STARTING)

::method identity
  expose identity
  return .InstrumentationCodec~copyDirectory(identity)

::method semanticRef
  expose identity
  return .InstrumentationCodec~semanticRef(identity)

::method serviceHealthy
  expose emitter
  emitter~setHealth(.InstrumentationHealth~HEALTHY)
  return self

::method serviceStopping
  expose emitter
  emitter~setHealth(.InstrumentationHealth~STOPPING)
  return self

::method sessionOpened
  expose emitter activeSessions baseDimensions
  activeSessions+=1
  emitter~counterAdd(.MasInstrumentationMetric~SESSIONS_ACCEPTED_TOTAL,1,"count",baseDimensions)
  emitter~gaugeSet(.MasInstrumentationMetric~SESSIONS_ACTIVE,activeSessions,"count",baseDimensions)
  return self

::method sessionClosed
  expose emitter activeSessions baseDimensions
  if activeSessions>0 then activeSessions-=1
  emitter~counterAdd(.MasInstrumentationMetric~SESSIONS_CLOSED_TOTAL,1,"count",baseDimensions)
  emitter~gaugeSet(.MasInstrumentationMetric~SESSIONS_ACTIVE,activeSessions,"count",baseDimensions)
  return self

::method frameReceived
  expose emitter baseDimensions
  use strict arg operationArg,bytesArg
  dims=self~operationDimensions(operationArg)
  emitter~counterAdd(.MasInstrumentationMetric~FRAMES_RECEIVED_TOTAL,1,"count",dims)
  if datatype(bytesArg,"W") then if bytesArg>=0 then do
    emitter~bytesIn(bytesArg)
    emitter~counterAdd(.MasInstrumentationMetric~IO_BYTES_IN_TOTAL,bytesArg,"bytes",dims)
  end
  return self

::method frameSent
  expose emitter baseDimensions
  use strict arg operationArg,bytesArg
  dims=self~operationDimensions(operationArg)
  emitter~counterAdd(.MasInstrumentationMetric~FRAMES_SENT_TOTAL,1,"count",dims)
  if datatype(bytesArg,"W") then if bytesArg>=0 then do
    emitter~bytesOut(bytesArg)
    emitter~counterAdd(.MasInstrumentationMetric~IO_BYTES_OUT_TOTAL,bytesArg,"bytes",dims)
  end
  return self

::method requestAccepted
  expose emitter
  use strict arg operationArg
  dims=self~operationDimensions(operationArg)
  emitter~requestAccepted
  emitter~counterAdd(.MasInstrumentationMetric~OPERATION_ACCEPTED_TOTAL,1,"count",dims)
  return self

::method requestCompleted
  expose emitter
  use strict arg operationArg,statusArg=0
  dims=self~operationDimensions(operationArg)
  emitter~requestCompleted
  emitter~counterAdd(.MasInstrumentationMetric~OPERATION_COMPLETED_TOTAL,1,"count",dims)
  if statusArg<>0 then emitter~counterAdd(.MasInstrumentationMetric~PROTOCOL_ERRORS_TOTAL,1,"count",dims)
  return self

::method requestFailed
  expose emitter
  use strict arg operationArg,statusArg=0
  dims=self~operationDimensions(operationArg)
  emitter~requestFailed
  emitter~counterAdd(.MasInstrumentationMetric~OPERATION_FAILED_TOTAL,1,"count",dims)
  emitter~counterAdd(.MasInstrumentationMetric~PROTOCOL_ERRORS_TOTAL,1,"count",dims)
  return self

::method requestRejected
  expose emitter
  use strict arg operationArg
  dims=self~operationDimensions(operationArg)
  emitter~requestRejected
  emitter~counterAdd(.MasInstrumentationMetric~PROTOCOL_ERRORS_TOTAL,1,"count",dims)
  return self

::method transportFailure
  expose emitter baseDimensions
  use strict arg codeArg=""
  dims=.InstrumentationCodec~copyDirectory(baseDimensions)
  if codeArg<>"" then dims["code"]=codeArg~string
  emitter~counterAdd(.MasInstrumentationMetric~TRANSPORT_FAILURES_TOTAL,1,"count",dims)
  emitter~setHealth(.InstrumentationHealth~DEGRADED)
  return self

::method snapshot
  expose emitter
  use strict arg observedAt=""
  return emitter~snapshot(observedAt)

::method capability
  expose identity
  ops=.array~new
  do name over self~operationNames; ops~append(name); end
  metrics=.array~of(.MasInstrumentationMetric~SESSIONS_ACCEPTED_TOTAL, -
    .MasInstrumentationMetric~SESSIONS_CLOSED_TOTAL,.MasInstrumentationMetric~SESSIONS_ACTIVE, -
    .MasInstrumentationMetric~FRAMES_RECEIVED_TOTAL,.MasInstrumentationMetric~FRAMES_SENT_TOTAL, -
    .MasInstrumentationMetric~IO_BYTES_IN_TOTAL,.MasInstrumentationMetric~IO_BYTES_OUT_TOTAL, -
    .MasInstrumentationMetric~OPERATION_ACCEPTED_TOTAL,.MasInstrumentationMetric~OPERATION_COMPLETED_TOTAL, -
    .MasInstrumentationMetric~OPERATION_FAILED_TOTAL,.MasInstrumentationMetric~PROTOCOL_ERRORS_TOTAL, -
    .MasInstrumentationMetric~TRANSPORT_FAILURES_TOTAL)
  return .InstrumentationCodec~capability(.InstrumentationCodec~copyDirectory(identity),ops,metrics,.array~new)

::method operationDimensions private
  expose baseDimensions
  use strict arg operationArg
  dims=.InstrumentationCodec~copyDirectory(baseDimensions)
  dims["operation"]=self~metricOperation(operationArg)
  dims["operation_code"]=operationArg~string
  dims["family"]=self~metricFamily(operationArg)
  return dims

::method operationNames private
  a=.array~new
  do op over .array~of(.MasWire~OP_HELLO,.MasWire~OP_ACCEPT,.MasWire~OP_PING,.MasWire~OP_DISCONNECT, -
    .MasWire~OP_QOPEN,.MasWire~OP_QPUT,.MasWire~OP_QGET,.MasWire~OP_QDEPTH,.MasWire~OP_QCLOSE, -
    .MasWire~OP_DBOPEN,.MasWire~OP_DBGET,.MasWire~OP_DBPUT,.MasWire~OP_DBDELETE,.MasWire~OP_DBSCAN,.MasWire~OP_DBCLOSE, -
    .MasWire~OP_MAILINIT,.MasWire~OP_MAILBOX,.MasWire~OP_MAILLIST,.MasWire~OP_MAILOPEN,.MasWire~OP_MAILENV, -
    .MasWire~OP_MAILHEAD,.MasWire~OP_MAILBODY,.MasWire~OP_MAILPART,.MasWire~OP_MAILNEXT,.MasWire~OP_MAILSEEN, -
    .MasWire~OP_MAILCLOS,.MasWire~OP_MAILTERM,.MasWire~OP_MAILNEW,.MasWire~OP_MAILFROM,.MasWire~OP_MAILTO, -
    .MasWire~OP_MAILTEXT,.MasWire~OP_MAILSIGN,.MasWire~OP_MAILSEND,.MasWire~OP_MAILSTAT, -
    .MasWire~OP_PATHOPEN,.MasWire~OP_PATHREAD,.MasWire~OP_PATHWRITE,.MasWire~OP_PATHAPPEND,.MasWire~OP_PATHCLOSE, -
    .MasWire~OP_PATHSTAT,.MasWire~OP_PATHLIST)
    a~append(self~metricOperation(op))
  end
  return a

::method metricFamily private
  use strict arg operationArg
  if operationArg>=.MasWire~OP_QOPEN & operationArg<=.MasWire~OP_QCLOSE then return "queue"
  if operationArg>=.MasWire~OP_DBOPEN & operationArg<=.MasWire~OP_DBCLOSE then return "database"
  if operationArg>=.MasWire~OP_MAILINIT & operationArg<=.MasWire~OP_MAILSTAT then return "mail"
  if operationArg>=.MasWire~OP_PATHOPEN & operationArg<=.MasWire~OP_PATHLIST then return "path"
  return "protocol"

::method metricOperation private
  use strict arg operationArg
  select
    when operationArg=.MasWire~OP_HELLO then return "hello"
    when operationArg=.MasWire~OP_ACCEPT then return "accept"
    when operationArg=.MasWire~OP_PING then return "ping"
    when operationArg=.MasWire~OP_DISCONNECT then return "disconnect"
    when operationArg=.MasWire~OP_QOPEN then return "queue.open"
    when operationArg=.MasWire~OP_QPUT then return "queue.put"
    when operationArg=.MasWire~OP_QGET then return "queue.get"
    when operationArg=.MasWire~OP_QDEPTH then return "queue.depth"
    when operationArg=.MasWire~OP_QCLOSE then return "queue.close"
    when operationArg=.MasWire~OP_DBOPEN then return "database.open"
    when operationArg=.MasWire~OP_DBGET then return "database.get"
    when operationArg=.MasWire~OP_DBPUT then return "database.put"
    when operationArg=.MasWire~OP_DBDELETE then return "database.delete"
    when operationArg=.MasWire~OP_DBSCAN then return "database.scan"
    when operationArg=.MasWire~OP_DBCLOSE then return "database.close"
    when operationArg=.MasWire~OP_MAILINIT then return "mail.init"
    when operationArg=.MasWire~OP_MAILBOX then return "mail.mailbox"
    when operationArg=.MasWire~OP_MAILLIST then return "mail.list"
    when operationArg=.MasWire~OP_MAILOPEN then return "mail.open"
    when operationArg=.MasWire~OP_MAILENV then return "mail.envelope"
    when operationArg=.MasWire~OP_MAILHEAD then return "mail.head"
    when operationArg=.MasWire~OP_MAILBODY then return "mail.body"
    when operationArg=.MasWire~OP_MAILPART then return "mail.part"
    when operationArg=.MasWire~OP_MAILNEXT then return "mail.next"
    when operationArg=.MasWire~OP_MAILSEEN then return "mail.seen"
    when operationArg=.MasWire~OP_MAILCLOS then return "mail.close"
    when operationArg=.MasWire~OP_MAILTERM then return "mail.term"
    when operationArg=.MasWire~OP_MAILNEW then return "smtp.new"
    when operationArg=.MasWire~OP_MAILFROM then return "smtp.from"
    when operationArg=.MasWire~OP_MAILTO then return "smtp.to"
    when operationArg=.MasWire~OP_MAILTEXT then return "smtp.text"
    when operationArg=.MasWire~OP_MAILSIGN then return "smtp.sign"
    when operationArg=.MasWire~OP_MAILSEND then return "smtp.send"
    when operationArg=.MasWire~OP_MAILSTAT then return "smtp.status"
    when operationArg=.MasWire~OP_PATHOPEN then return "path.open"
    when operationArg=.MasWire~OP_PATHREAD then return "path.read"
    when operationArg=.MasWire~OP_PATHWRITE then return "path.write"
    when operationArg=.MasWire~OP_PATHAPPEND then return "path.append"
    when operationArg=.MasWire~OP_PATHCLOSE then return "path.close"
    when operationArg=.MasWire~OP_PATHSTAT then return "path.stat"
    when operationArg=.MasWire~OP_PATHLIST then return "path.list"
    otherwise return "op."||operationArg
  end

::requires "MasWire.cls"
::requires "InstrumentationMesh.cls"
