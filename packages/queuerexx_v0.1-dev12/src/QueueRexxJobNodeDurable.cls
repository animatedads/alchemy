/* QueueRexxJobNodeDurable.cls - optional Job-to-Node v0.6 durable placement
 * frontage for QueueRexx v0.1-dev11.
 *
 * This package is deliberately separate from QueueRexxScheduling.cls so the
 * read-only/core QueueRexx packages do not acquire a mandatory Job-to-Node
 * dependency. Load it only when durable Job-to-Node placement is configured.
 */

/* Placement semantics remain entirely in Job-to-Node. This object only makes
 * its supplied JobNodeDurablePlacementManager the allocator surface used by
 * QueueRexx / Migratable Job. A restore pass is mandatory before mutation,
 * including on an empty journal, so corrupt durable authority cannot be
 * silently bypassed by allocating a fresh ownership epoch. */
::class QueueDurableJobNodeAllocator public
::constant DIRECTORY_NAME "queuerexx-job-node"
::constant JOURNAL_NAME "placements.journal"
::attribute allocator get
::attribute manager get
::attribute journal get
::attribute ready get
::attribute recovery get
::attribute journalPath get
::method init
  expose allocator manager journal ready recovery journalPath root filesystem
  use strict arg allocatorArg, ownershipArg, queueRootArg, admissionAuthorityArg = .nil, digestProviderArg = .nil, proofAuthorityArg = .nil, filesystemArg = .nil
  if allocatorArg == .nil | ownershipArg == .nil then raise syntax 88.900 array("Job-to-Node allocator and ownership registry required")
  allocator = allocatorArg
  root = queueRootArg~string
  if root == "" then raise syntax 88.900 array("queue root required for durable Job-to-Node state")
  if filesystemArg == .nil then filesystem = .QueuePosixAtomicFileSystem~new
  else filesystem = filesystemArg
  directory = root || "/logs/" || self~DIRECTORY_NAME
  if \filesystem~ensureDirectory(directory) then raise syntax 88.900 array("could not create durable Job-to-Node directory", directory)
  ignore = filesystem~ensureOwnerLike(directory, root)
  journalPath = directory || "/" || self~JOURNAL_NAME
  journal = .JobNodeDurableJournal~new(journalPath, digestProviderArg, proofAuthorityArg)
  manager = .JobNodeDurablePlacementManager~new(allocator, ownershipArg, journal, admissionAuthorityArg)
  ready = .false
  recovery = .nil

::method restore
  expose manager ready recovery
  use strict arg nowEpochMs
  signal on syntax name durableRestoreFailure
  recovery = manager~restore(nowEpochMs)
  ready = .false
  if recovery \= .nil then if recovery~ok then ready = .true
  self~repairOwnership
  signal off syntax
  return recovery
durableRestoreFailure:
  signal off syntax
  ready = .false
  raise propagate

::method allocate
  expose manager ready
  use strict arg placementRequest, nowEpochMs, leaseDurationMs = 30000
  if \ready then return .JobNodePlacementDecision~new(.false, "DURABLE_RESTORE_REQUIRED")
  signal on syntax name durableAllocateFailure
  decision = manager~allocate(placementRequest, nowEpochMs, leaseDurationMs)
  self~repairOwnership
  signal off syntax
  return decision
durableAllocateFailure:
  signal off syntax
  self~repairOwnership
  raise propagate

::method renewPlacement
  expose manager ready
  use strict arg lease, placementRequest, nowEpochMs, leaseDurationMs = 30000
  if \ready then return .JobNodePlacementDecision~new(.false, "DURABLE_RESTORE_REQUIRED", lease)
  signal on syntax name durableRenewFailure
  decision = manager~renewPlacement(lease, placementRequest, nowEpochMs, leaseDurationMs)
  self~repairOwnership
  signal off syntax
  return decision
durableRenewFailure:
  signal off syntax
  self~repairOwnership
  raise propagate

::method releasePlacement
  expose manager ready
  use strict arg lease
  if \ready then return .false
  signal on syntax name durableReleaseFailure
  ok = manager~releasePlacement(lease)
  self~repairOwnership
  signal off syntax
  return ok
durableReleaseFailure:
  signal off syntax
  self~repairOwnership
  raise propagate

::method checkpoint
  expose manager ready
  if \ready then return .false
  ok = manager~checkpoint
  self~repairOwnership
  return ok

::method verifyLease
  expose allocator ready
  use strict arg lease, placementRequest, nowEpochMs
  if \ready then return .false
  return allocator~verifyLease(lease, placementRequest, nowEpochMs)

/* Observation/introspection delegates do not bypass durable mutation. */
::method admissionReservation
  expose allocator
  use strict arg lease
  return allocator~admissionReservation(lease)
::method hasAdmission
  expose allocator
  use strict arg lease
  return allocator~hasAdmission(lease)
::method sequenceValue
  expose allocator
  return allocator~sequenceValue

::method repairOwnership private
  expose filesystem journalPath root
  if SysFileExists(journalPath) then ignore = filesystem~ensureOwnerLikeShallow(journalPath, root)
  return .true

::requires "QueueRexxScheduling.cls"
::requires "JobNodeDurableState.cls"
