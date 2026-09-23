/* FD Door Micro Motion v0.2-dev8 remote NEW-start binding.
 *
 * Migratable Job v0.2.5 verifies the exact Job-to-Node lease immediately
 * before entering migratable.job.start/1.  The generic remote-start service
 * deliberately does not mutate workload application state.  FD, however,
 * must carry the verified placement into its private worker spec and durable
 * start provenance.  This verifier decorator performs that one workload-
 * specific binding only AFTER the upstream verifier has accepted the lease.
 *
 * It is not a placement authority and does not allocate, renew or release.
 */

::class FDDoorMicroMotionRemoteStartBuild public
::constant API 'migratable.job.remote-start/1'

::class FDDoorMicroMotionRemoteStartLeaseVerifier subclass MigratableJobPlacedStartLeaseVerifier public
::method init
  expose application delegate
  use strict arg applicationArg, delegateArg
  application=applicationArg; delegate=delegateArg
  if application==.nil | delegate==.nil then raise syntax 88.900 array('FD remote-start application and lease verifier required')
  if \application~isA(.FDDoorMicroMotionStarterApplication) then raise syntax 88.900 array('FD remote-start requires FDDoorMicroMotionStarterApplication')
  if \delegate~isA(.MigratableJobPlacedStartLeaseVerifier) then raise syntax 88.900 array('FD remote-start delegate must be MigratableJobPlacedStartLeaseVerifier')

::method verify
  expose application delegate
  use strict arg lease, startRequest, nowEpochMs
  if lease==.nil | startRequest==.nil then return .false
  if \delegate~verify(lease,startRequest,nowEpochMs) then return .false
  /* bindInitialLease rechecks job/node/owner, requirement digest and exact
     placement/ownership identity before the FD starter is allowed to run. */
  return application~bindInitialLease(lease)

::requires 'FDDoorMicroMotionStarter.cls'
::requires 'MigratableJobRemoteStart.cls'
