/* ooRexx Job-to-Node Allocator v0.5 durable placement state.
 * Append-only committed snapshots preserve ownership fencing and admission
 * recovery evidence across allocator restarts.  An incomplete/torn trailing
 * snapshot is ignored.  A corrupt or invalidly signed committed snapshot is
 * never restored.
 */

::class JobNodeDurableSnapshot public
::attribute snapshotId get
::attribute allocatorSequence get
::attribute leases get
::attribute epochs get
::attribute admissionSnapshots get
::attribute valid get
::attribute code get
::method init
  expose snapshotId allocatorSequence leases epochs admissionSnapshots valid code
  use strict arg idArg=0, sequenceArg=0, leasesArg=.nil, epochsArg=.nil, admissionsArg=.nil, validArg=.true, codeArg="OK"
  snapshotId=idArg+0; allocatorSequence=sequenceArg+0
  if leasesArg==.nil then leases=.array~new; else leases=leasesArg
  if epochsArg==.nil then epochs=.directory~new; else epochs=epochsArg
  if admissionsArg==.nil then admissionSnapshots=.directory~new; else admissionSnapshots=admissionsArg
  valid=validArg; code=codeArg~string

::class JobNodeDurableRecoveryResult public
::attribute ok get
::attribute code get
::attribute restored get
::attribute expired get
::attribute blocked get
::attribute snapshotId get
::method init
  expose ok code restored expired blocked snapshotId
  use strict arg okArg, codeArg, restoredArg=0, expiredArg=0, blockedArg=0, snapshotArg=0
  ok=okArg; code=codeArg~string; restored=restoredArg+0; expired=expiredArg+0; blocked=blockedArg+0; snapshotId=snapshotArg+0

::class JobNodeDurableJournal public
::method init
  expose path digestProvider proofAuthority lastSnapshotId
  use strict arg pathArg, digestArg=.nil, proofArg=.nil
  path=pathArg~string
  if digestArg==.nil then digestProvider=.JobNodeDigestProvider~new; else digestProvider=digestArg
  proofAuthority=proofArg; lastSnapshotId=0
::method path
  expose path
  return path
::method appendSnapshot guarded
  expose path digestProvider proofAuthority lastSnapshotId
  use strict arg allocatorSequence, ownershipRegistry, allocator, admissionAuthority=.nil
  lastSnapshotId+=1
  sid=lastSnapshotId
  lines=.array~new
  lines~append("BEGIN|"||sid||"|"||allocatorSequence)
  epochs=ownershipRegistry~epochEntries
  do e over epochs
    lines~append("EPOCH|"||c2x(e[1])||"|"||e[2])
  end
  leases=ownershipRegistry~activeLeases
  do lease over leases
    admissionSnapshot=""
    if lease~reservationRef<>"" then do
      reservation=allocator~admissionReservation(lease)
      if reservation==.nil then return .false
      if admissionAuthority==.nil | \admissionAuthority~hasMethod("SNAPSHOTRESERVATION") then return .false
      admissionSnapshot=admissionAuthority~snapshotReservation(reservation)
      if admissionSnapshot=="" then return .false
    end
    lines~append(self~leaseLine(lease,admissionSnapshot))
  end
  material=""
  do line over lines; material=material||line||"0a"x; end
  digest=digestProvider~digest(material)
  signature=""
  if proofAuthority<>.nil then signature=proofAuthority~sign("job.node.durable.snapshot/1|"||sid||"|"||digest)
  stream=.stream~new(path)
  opened=stream~open("write append")
  if opened<>"READY:" then return .false
  do line over lines; stream~lineout(line); end
  stream~lineout("COMMIT|"||sid||"|"||digest||"|"||c2x(signature))
  stream~close
  return .true
::method loadLatest guarded
  expose path digestProvider proofAuthority lastSnapshotId
  stream=.stream~new(path)
  opened=stream~open("read")
  if opened<>"READY:" then return .JobNodeDurableSnapshot~new
  candidate=.array~new; active=.false; candidateId=0; candidateSeq=0
  best=.JobNodeDurableSnapshot~new
  do while stream~lines>0
    line=stream~linein
    parts=self~split(line)
    if parts~items=0 then iterate
    kind=parts[1]
    if kind="BEGIN" & parts~items>=3 then do
      candidate=.array~new; candidate~append(line); active=.true
      candidateId=parts[2]+0; candidateSeq=parts[3]+0
      iterate
    end
    if \active then iterate
    if kind="COMMIT" then do
      if parts~items<4 | parts[2]+0<>candidateId then do; active=.false; iterate; end
      material=""; do x over candidate; material=material||x||"0a"x; end
      digest=digestProvider~digest(material)
      valid=(digest=parts[3])
      if valid & proofAuthority<>.nil then valid=proofAuthority~verify("job.node.durable.snapshot/1|"||candidateId||"|"||digest,x2c(parts[4]))
      if valid then do
        parsed=self~parseSnapshot(candidateId,candidateSeq,candidate)
        if parsed==.nil then do; stream~close; return .JobNodeDurableSnapshot~new(candidateId,0,.nil,.nil,.nil,.false,"DURABLE_JOURNAL_FORMAT_INVALID"); end
        if parsed~snapshotId>=best~snapshotId then best=parsed
      end
      else do
        stream~close
        return .JobNodeDurableSnapshot~new(candidateId,0,.nil,.nil,.nil,.false,"DURABLE_JOURNAL_INTEGRITY_FAILED")
      end
      active=.false
      iterate
    end
    candidate~append(line)
  end
  stream~close
  lastSnapshotId=best~snapshotId
  return best
::method parseSnapshot private
  use strict arg sid, allocatorSequence, lines
  leases=.array~new; epochs=.directory~new; admissions=.directory~new
  do i=2 to lines~items
    parts=self~split(lines[i]); if parts~items=0 then iterate
    if parts[1]="EPOCH" then do
      if parts~items<3 then return .nil
      epochs[x2c(parts[2])]=parts[3]+0
    end
    else if parts[1]="LEASE" then do
      if parts~items<>20 then return .nil
      lease=.JobNodePlacementLease~new(x2c(parts[2]),x2c(parts[3]),x2c(parts[4]),x2c(parts[5]),x2c(parts[6]),x2c(parts[7]),x2c(parts[8]),x2c(parts[9]),x2c(parts[10]),x2c(parts[11]),x2c(parts[12]),x2c(parts[13]),x2c(parts[14]),x2c(parts[15]),x2c(parts[16]),x2c(parts[17]),x2c(parts[18]),x2c(parts[19]))
      leases~append(lease); admissions[lease~placementId]=x2c(parts[20])
    end
  end
  return .JobNodeDurableSnapshot~new(sid,allocatorSequence,leases,epochs,admissions)
::method leaseLine private
  use strict arg lease, admissionSnapshot
  values=.array~of(lease~placementId,lease~jobId,lease~nodeId,lease~ownerNodeId,lease~capabilityGeneration,lease~capacityObservationGeneration,lease~issuedEpochMs,lease~expiresEpochMs,lease~requirementDigest,lease~capabilityDigest,lease~capacityDigest,lease~allocationPolicyGeneration,lease~proofRef,lease~reservationRef,lease~signature,lease~ownershipEpoch,lease~renewalSequence,lease~supersedesPlacementId,admissionSnapshot)
  out="LEASE"
  do v over values; out=out||"|"||c2x(v~string); end
  return out
::method split private
  use strict arg text
  a=.array~new; rest=text~string
  do forever
    p=rest~pos("|")
    if p=0 then do; a~append(rest); leave; end
    a~append(rest~left(p-1)); rest=rest~substr(p+1)
  end
  return a

::class JobNodeDurablePlacementManager public
::method init
  expose allocator ownership journal admissionAuthority
  use strict arg allocatorArg, ownershipArg, journalArg, admissionArg=.nil
  allocator=allocatorArg; ownership=ownershipArg; journal=journalArg; admissionAuthority=admissionArg
::method checkpoint guarded
  expose allocator ownership journal admissionAuthority
  return journal~appendSnapshot(allocator~sequenceValue,ownership,allocator,admissionAuthority)
::method allocate guarded
  expose allocator
  use strict arg placementRequest, nowEpochMs, leaseDurationMs=30000
  d=allocator~allocate(placementRequest,nowEpochMs,leaseDurationMs)
  if \d~placed then return d
  if self~checkpoint then return d
  ignore=allocator~releasePlacement(d~lease)
  return .JobNodePlacementDecision~new(.false,"DURABLE_STATE_WRITE_FAILED",.nil,d~assessments,0)
::method renewPlacement guarded
  expose allocator
  use strict arg lease, placementRequest, nowEpochMs, leaseDurationMs=30000
  d=allocator~renewPlacement(lease,placementRequest,nowEpochMs,leaseDurationMs)
  if \d~placed then return d
  if self~checkpoint then return d
  return .JobNodePlacementDecision~new(.false,"DURABLE_STATE_WRITE_FAILED",d~lease,d~assessments,0)
::method releasePlacement guarded
  expose allocator
  use strict arg lease
  if \allocator~releasePlacement(lease) then return .false
  return self~checkpoint
::method restore guarded
  expose allocator ownership journal admissionAuthority
  use strict arg nowEpochMs
  snap=journal~loadLatest
  if \snap~valid then return .JobNodeDurableRecoveryResult~new(.false,snap~code,0,0,0,snap~snapshotId)
  allocator~restoreSequence(snap~allocatorSequence)
  do jobId over snap~epochs; ownership~restoreEpoch(jobId,snap~epochs[jobId]); end
  restored=0; expired=0; blocked=0
  do lease over snap~leases
    if lease~isExpired(nowEpochMs) then do
      expired+=1
      self~releasePersistedAdmission(lease,snap~admissionSnapshots[lease~placementId])
      iterate
    end
    if \ownership~restoreCurrent(lease) then do; blocked+=1; iterate; end
    if lease~reservationRef<>"" then do
      admissionSnapshot=snap~admissionSnapshots[lease~placementId]
      if admissionSnapshot==.nil | admissionSnapshot="" | admissionAuthority==.nil | \admissionAuthority~hasMethod("RESTORERESERVATION") | \admissionAuthority~hasMethod("RESERVATIONACTIVE") then do; blocked+=1; iterate; end
      reservation=admissionAuthority~restoreReservation(admissionSnapshot)
      if reservation==.nil | \admissionAuthority~reservationActive(reservation) then do; blocked+=1; iterate; end
      allocator~restoreAdmission(lease,reservation)
    end
    restored+=1
  end
  if blocked>0 then return .JobNodeDurableRecoveryResult~new(.false,"RECOVERY_BLOCKED",restored,expired,blocked,snap~snapshotId)
  return .JobNodeDurableRecoveryResult~new(.true,"RESTORED",restored,expired,0,snap~snapshotId)
::method releasePersistedAdmission private
  expose admissionAuthority
  use strict arg lease, admissionSnapshot
  if lease~reservationRef="" then return .true
  if admissionSnapshot==.nil | admissionSnapshot="" then return .false
  if admissionAuthority==.nil | \admissionAuthority~hasMethod("RESTORERESERVATION") then return .false
  reservation=admissionAuthority~restoreReservation(admissionSnapshot)
  if reservation==.nil then return .false
  if admissionAuthority~hasMethod("RESERVATIONACTIVE") then if \admissionAuthority~reservationActive(reservation) then return .true
  return admissionAuthority~release(reservation)

::requires "JobNodeLiveness.cls"
