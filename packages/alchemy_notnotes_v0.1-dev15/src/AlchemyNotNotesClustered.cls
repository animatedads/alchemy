/* AlchemyNotNotesClustered.cls
 * Cluster/RTO binding for a logical NotNotes node.
 * Queue Fabric and socket carriage remain below AlchemyClusterTransport.
 */

::class AlchemyNotNotesClusteredNode public subclass AlchemyClusteredApp

::method init
  expose node committedState staged localUser localSecurityManager logicalNodeId
  use strict arg clusterId, instanceId, preferredRole, newLogicalNodeId, transport = .nil
  logicalNodeId = newLogicalNodeId~string
  if logicalNodeId = "" then raise syntax 93.900 array ("clustered NotNotes logical node id must not be empty")
  node = .AlchemyNotNotesNode~new(logicalNodeId)
  committedState = self~detach(node~rtoExportState)
  staged = .false
  localUser = .nil
  localSecurityManager = .nil
  forward class (super) arguments (clusterId, instanceId, preferredRole, transport)

::attribute logicalNodeId get

/* Install local authority.  These bindings are never included in RTO state. */
::method configureLocalAuthority
  expose node localUser localSecurityManager
  use strict arg user = .nil, securityManager = .nil
  localUser = user
  localSecurityManager = securityManager
  node~setCurrentUser(user)
  node~setSecurityManager(securityManager)
  return self

/* Install node-local design/application code on this member. */
::method installApplication
  expose node
  use arg application
  if application == .nil then raise syntax 93.900 array ("application must not be .nil")
  application~install(node)
  return self

/*
 * Read access on REPLAY must never leak references into replayable state.
 * ACTIVE callers receive the ordinary live service objects so the existing
 * edit -> stageSave workflow remains unchanged.  REPLAY callers receive
 * objects from a detached reconstruction of the current replay image.
 */
::method document
  use arg documentId
  readNode = self~readServiceNode
  return readNode~document(documentId)

::method documents
  use strict arg typeFilter = .nil
  readNode = self~readServiceNode
  return readNode~documents(typeFilter)

::method referralTray
  use arg target
  readNode = self~readServiceNode
  return readNode~referralTray(target)

/*
 * Construct a detached read service for non-ACTIVE roles.  The clone carries
 * the same replayable business image, but mutations to returned Directory
 * objects cannot modify the clustered member.  Local authority is rebound to
 * the clone so relationship resolution and read-side controller context stay
 * node-local rather than travelling in RTO state.
 */
::method readServiceNode
  expose node localUser localSecurityManager logicalNodeId
  if self~resolvedRole = "ACTIVE" then return node
  readNode = .AlchemyNotNotesNode~new(logicalNodeId)
  readNode~rtoImportState(self~detach(node~rtoExportState))
  readNode~setCurrentUser(localUser)
  readNode~setSecurityManager(localSecurityManager)
  return readNode

::method currentUser
  expose node
  return node~currentUser

::method externalDocument
  expose node
  use arg externalId
  return node~externalDocument(externalId)

/* Mutating application entrypoints are fenced to ACTIVE only. */
::method createDocument
  expose node
  use arg formName
  self~requireActive
  return node~createDocument(formName)

::method compose
  expose node
  use arg definitionIdentity
  self~requireActive
  return node~compose(definitionIdentity)

::method createExternalDocument
  expose node staged
  use strict arg displayName, mediaType, content, sourceKind = "EXTERNAL"
  self~requireActive
  staged = .true
  return node~createExternalDocument(displayName, mediaType, content, sourceKind)

::method pasteExternalDocument
  expose node staged
  use strict arg displayName, mediaType, content
  self~requireActive
  staged = .true
  return node~pasteExternalDocument(displayName, mediaType, content)

::method stageSave
  expose node staged
  use arg document
  self~requireActive
  savedDocument = node~save(document)
  staged = .true
  return savedDocument

::method stageReferralDecision
  expose node staged
  use strict arg document, outcome, note = ""
  self~requireActive
  decision = node~decideReferral(document, outcome, note)
  staged = .true
  return decision

/* Snapshot staged state for the transport handshake before local commit. */
::method stagedState
  expose node staged
  self~requireActive
  if \staged then raise syntax 93.900 array ("no staged NotNotes transaction")
  return self~detach(node~rtoExportState)

/* Commit either degraded-local or synchronously mirrored staged state. */
::method commitStaged
  expose staged
  use strict arg transactionId, sequence = .nil
  self~requireActive
  if \staged then raise syntax 93.900 array ("no staged NotNotes transaction")
  if sequence == .nil then committed = self~commitState(transactionId)
  else do
    if \self~commitMirroredState(transactionId, sequence) then
      raise syntax 93.900 array ("mirrored NotNotes commit sequence rejected")
    committed = sequence
  end
  staged = .false
  return committed

/* Abandon staged local changes and return to the last committed image. */
::method rollbackStaged
  expose staged
  self~requireActive
  self~rtoRollbackToCommitted
  staged = .false
  return self

::method requireActive
  if self~resolvedRole <> "ACTIVE" then
    raise syntax 93.900 array ("NotNotes mutation requires ACTIVE cluster role")
  return .true

/* AlchemyClusteredApp RTO hooks. */
::method rtoExportState public
  expose node
  return node~rtoExportState

::method rtoImportState public
  expose node
  use arg state
  node~rtoImportState(state)
  return self

::method rtoCommitLocalState public
  expose node committedState
  committedState = self~detach(node~rtoExportState)

::method rtoCommitReplayState public
  expose node committedState
  committedState = self~detach(node~rtoExportState)

::method rtoRollbackToCommitted public
  expose node committedState staged
  if committedState \== .nil then node~rtoImportState(self~detach(committedState))
  staged = .false

/* Re-assert local bindings after reconstruction/promotion. */
::method rtoBind public
  expose node localUser localSecurityManager
  use arg bindings
  node~setCurrentUser(localUser)
  node~setSecurityManager(localSecurityManager)
  return self

::method rtoActivate public
  use arg activationEpoch
  return self

::method rtoLifecycle public
  use arg lifecycle
  return self

::method detach
  use arg state
  return .json~fromJson(.json~toJson(state))

::requires "AlchemyNotNotes.cls"
::requires "AlchemyClusteredApp.cls"
::requires "json.cls"
