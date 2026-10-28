/* IdentityPeerAuthorityJournal.cls
 * Restart-safe authority/failover recovery boundary for LDAP Identity peers.
 *
 * The journal deliberately stores authority facts, not transport facts.  A
 * recovered XTP delivery/ACK can never become an LDAP application commit.
 */

::class IdentityPeerAuthoritySnapshot public

::method init
  expose logicalPeer authorityEpoch authorityHolder directoryRevision committedUpdateId capturedAt
  use strict arg logicalPeer, authorityEpoch, authorityHolder, directoryRevision = '', committedUpdateId = '', capturedAt = ''

  if logicalPeer == '' then raise syntax 93.900 array('logicalPeer must not be empty')
  if authorityHolder == '' then raise syntax 93.900 array('authorityHolder must not be empty')
  if \authorityEpoch~datatype('W') then raise syntax 93.900 array('authorityEpoch must be a whole number')
  if authorityEpoch < 0 then raise syntax 93.900 array('authorityEpoch must not be negative')

::method logicalPeer
  expose logicalPeer
  return logicalPeer

::method authorityEpoch
  expose authorityEpoch
  return authorityEpoch

::method authorityHolder
  expose authorityHolder
  return authorityHolder

::method directoryRevision
  expose directoryRevision
  return directoryRevision

::method committedUpdateId
  expose committedUpdateId
  return committedUpdateId

::method capturedAt
  expose capturedAt
  return capturedAt


::class IdentityPeerAuthorityJournal public

::method init
  expose store
  use strict arg store
  if store == .nil then raise syntax 93.900 array('authority journal store is required')

::method recover
  expose store
  return store~load

::method persist
  expose store
  use strict arg nextSnapshot

  if nextSnapshot == .nil then raise syntax 93.900 array('authority snapshot is required')

  current = store~load
  if current \== .nil then self~validateSuccessor(current, nextSnapshot)
  return store~save(nextSnapshot)

::method validateSuccessor private
  use strict arg current, nextSnapshot

  if current~logicalPeer \== nextSnapshot~logicalPeer then -
    raise syntax 93.900 array('logical peer identity cannot change within one authority journal')

  if nextSnapshot~authorityEpoch < current~authorityEpoch then -
    raise syntax 93.900 array('authority epoch regression rejected')

  if nextSnapshot~authorityEpoch == current~authorityEpoch then do
    if nextSnapshot~authorityHolder \== current~authorityHolder then -
      raise syntax 93.900 array('same authority epoch cannot change holder')
  end

  return .true


::class MemoryIdentityPeerAuthorityJournalStore public

::method init
  expose snapshot
  snapshot = .nil

::method load
  expose snapshot
  return snapshot

::method save
  expose snapshot
  use strict arg nextSnapshot
  snapshot = nextSnapshot
  return .true
