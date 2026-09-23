/* Durable migration transaction journal for Migratable Job v0.2.
 * Append-only BEGIN/.../COMMIT snapshots. A torn trailing snapshot is ignored;
 * a corrupt committed snapshot fails closed.
 */

::class MigratableJobDurableSnapshot public
::attribute valid get
::attribute code get
::attribute snapshotId get
::attribute migration get
::method init
  expose valid code snapshotId migration
  use arg validArg=.false, codeArg="NO_SNAPSHOT", snapshotArg=0, migrationArg=.nil
  valid=(validArg==.true); code=codeArg~string; snapshotId=snapshotArg+0; migration=migrationArg

::class MigratableJobDurableJournal public
::method init
  expose path digestProvider proofAuthority lastSnapshotId
  use strict arg pathArg, digestArg=.nil, proofArg=.nil
  path=pathArg~string
  if path="" then raise syntax 88.900 array("durable migration journal path required")
  if digestArg==.nil then digestProvider=.JobNodeDigestProvider~new; else digestProvider=digestArg
  proofAuthority=proofArg; lastSnapshotId=0
::method append guarded
  expose path digestProvider proofAuthority lastSnapshotId
  use strict arg migration
  if migration==.nil then return .false
  lastSnapshotId+=1; sid=lastSnapshotId
  lines=.array~new
  lines~append("BEGIN|"||sid||"|"||c2x(migration~migrationId)||"|"||c2x(migration~definition~jobId)||"|"||c2x(migration~definition~definitionRef))
  lines~append(self~stateLine(migration))
  lines~append(self~leaseLine("SOURCE",migration~sourceLease))
  if migration~destinationLease<>.nil then lines~append(self~leaseLine("DEST",migration~destinationLease))
  if migration~checkpointManifest<>.nil then lines~append(self~checkpointLine(migration~checkpointManifest))
  material=""; do line over lines; material=material||line||"0a"x; end
  digest=digestProvider~digest(material)
  signature=""
  if proofAuthority<>.nil then signature=proofAuthority~sign("migratable.job.snapshot/1|"||sid||"|"||digest)
  s=.stream~new(path); opened=s~open("write append")
  if opened<>"READY:" then return .false
  do line over lines; s~lineout(line); end
  s~lineout("COMMIT|"||sid||"|"||digest||"|"||c2x(signature)); s~close
  return .true
::method loadLatest guarded
  expose path digestProvider proofAuthority lastSnapshotId
  use strict arg definition
  s=.stream~new(path); opened=s~open("read")
  if opened<>"READY:" then return .MigratableJobDurableSnapshot~new(.false,"NO_SNAPSHOT",0,.nil)
  active=.false; candidate=.array~new; candidateId=0; best=.MigratableJobDurableSnapshot~new(.false,"NO_SNAPSHOT",0,.nil)
  do while s~lines>0
    line=s~linein
    parts=self~split(line)
    if parts~items=0 then iterate
    kind=parts[1]
    if kind="BEGIN" then do
      if parts~items<>5 then do; active=.false; iterate; end
      candidate=.array~new; candidate~append(line); candidateId=parts[2]+0; active=.true
      iterate
    end
    if \active then iterate
    if kind="COMMIT" then do
      if parts~items<>4 | parts[2]+0<>candidateId then do; active=.false; iterate; end
      material=""; do x over candidate; material=material||x||"0a"x; end
      digest=digestProvider~digest(material)
      if digest<>parts[3] then do; s~close; return .MigratableJobDurableSnapshot~new(.false,"DURABLE_JOURNAL_INTEGRITY_FAILED",candidateId,.nil); end
      if proofAuthority<>.nil then do
        if \proofAuthority~verify("migratable.job.snapshot/1|"||candidateId||"|"||digest,x2c(parts[4])) then do; s~close; return .MigratableJobDurableSnapshot~new(.false,"DURABLE_JOURNAL_PROOF_INVALID",candidateId,.nil); end
      end
      parsed=self~parseSnapshot(candidateId,candidate,definition)
      if \parsed~valid then do; s~close; return parsed; end
      if parsed~snapshotId>=best~snapshotId then best=parsed
      active=.false
      iterate
    end
    candidate~append(line)
  end
  s~close
  lastSnapshotId=best~snapshotId
  return best
::method stateLine private
  use strict arg m
  return "STATE2|"||c2x(m~state)||"|"||c2x(m~resumeState)||"|"||c2x(m~checkpointTransferRef)||"|"||c2x(m~transferVerificationRef)||"|"||c2x(m~destinationCheckpointRef)||"|"||c2x(m~failureCode)||"|"||c2x(m~failureDetail)||"|"||m~startedEpochMs||"|"||m~updatedEpochMs||"|"||c2x(m~commitEvidenceRef)||"|"||m~sourceFenced||"|"||m~sourceAdmissionReleased||"|"||m~destinationResumed||"|"||c2x(m~executionRef)||"|"||m~sequence||"|"||c2x(m~handoffMode)||"|"||c2x(m~handoffId)||"|"||c2x(m~handoffRef)
::method leaseLine private
  use strict arg kind, lease
  values=.array~of(lease~placementId,lease~jobId,lease~nodeId,lease~ownerNodeId,lease~capabilityGeneration,lease~capacityObservationGeneration,lease~issuedEpochMs,lease~expiresEpochMs,lease~requirementDigest,lease~capabilityDigest,lease~capacityDigest,lease~allocationPolicyGeneration,lease~proofRef,lease~reservationRef,lease~signature,lease~ownershipEpoch,lease~renewalSequence,lease~supersedesPlacementId)
  out=kind
  do v over values; out=out||"|"||c2x(v~string); end
  return out
::method checkpointLine private
  use strict arg c
  values=.array~of(c~checkpointId,c~jobId,c~migrationId,c~partitionId,c~sourceNodeId,c~sourcePlacementId,c~sourceOwnershipEpoch,c~runtimeId,c~runtimeGeneration,c~executableRevision,c~stateRef,c~stateDigest,c~inputEvidenceRef,c~outputEvidenceRef,c~createdEpochMs,c~sourceExecutionStartedEpochMs,c~sourceExecutionPausedEpochMs,c~resumeSequence)
  out="CHECKPOINT"
  do v over values; out=out||"|"||c2x(v~string); end
  return out
::method parseSnapshot private
  use strict arg sid, lines, definition
  begin=self~split(lines[1])
  if begin~items<>5 then return .MigratableJobDurableSnapshot~new(.false,"DURABLE_JOURNAL_FORMAT_INVALID",sid,.nil)
  migrationId=x2c(begin[3]); jobId=x2c(begin[4]); definitionRef=x2c(begin[5])
  if definition==.nil then return .MigratableJobDurableSnapshot~new(.false,"DEFINITION_BINDING_MISMATCH",sid,.nil)
  if definition~jobId<>jobId | definition~definitionRef<>definitionRef then return .MigratableJobDurableSnapshot~new(.false,"DEFINITION_BINDING_MISMATCH",sid,.nil)
  stateFields=.nil; source=.nil; dest=.nil; checkpoint=.nil
  do i=2 to lines~items
    p=self~split(lines[i]); if p~items=0 then iterate
    select
      when p[1]="STATE" | p[1]="STATE2" then stateFields=p
      when p[1]="SOURCE" then source=self~parseLease(p)
      when p[1]="DEST" then dest=self~parseLease(p)
      when p[1]="CHECKPOINT" then checkpoint=self~parseCheckpoint(p)
      otherwise nop
    end
  end
  if stateFields==.nil | source==.nil then return .MigratableJobDurableSnapshot~new(.false,"DURABLE_JOURNAL_FORMAT_INVALID",sid,.nil)
  if stateFields~items<>16 & stateFields~items<>19 then return .MigratableJobDurableSnapshot~new(.false,"DURABLE_JOURNAL_STATE_INVALID",sid,.nil)
  if source~jobId<>definition~jobId then return .MigratableJobDurableSnapshot~new(.false,"SOURCE_LEASE_BINDING_MISMATCH",sid,.nil)
  m=.MigratableJobMigration~new(migrationId,definition,source,.MigratableJobTime~number(stateFields[9]))
  sf=self~bool(stateFields[12]); sr=self~bool(stateFields[13]); dr=self~bool(stateFields[14])
  if stateFields~items=19 then m~restoreDurable(dest,x2c(stateFields[2]),x2c(stateFields[3]),checkpoint,x2c(stateFields[4]),x2c(stateFields[5]),x2c(stateFields[6]),x2c(stateFields[7]),x2c(stateFields[8]),.MigratableJobTime~number(stateFields[9]),.MigratableJobTime~number(stateFields[10]),x2c(stateFields[11]),sf,sr,dr,x2c(stateFields[15]),stateFields[16]+0,x2c(stateFields[17]),x2c(stateFields[18]),x2c(stateFields[19]))
  else m~restoreDurable(dest,x2c(stateFields[2]),x2c(stateFields[3]),checkpoint,x2c(stateFields[4]),x2c(stateFields[5]),x2c(stateFields[6]),x2c(stateFields[7]),x2c(stateFields[8]),.MigratableJobTime~number(stateFields[9]),.MigratableJobTime~number(stateFields[10]),x2c(stateFields[11]),sf,sr,dr,x2c(stateFields[15]),stateFields[16]+0)
  return .MigratableJobDurableSnapshot~new(.true,"RESTORED",sid,m)
::method parseLease private
  use strict arg p
  if p~items<>19 then return .nil
  v=.array~new; do i=2 to 19; v~append(x2c(p[i])); end
  return .JobNodePlacementLease~new(v[1],v[2],v[3],v[4],v[5],v[6],v[7],v[8],v[9],v[10],v[11],v[12],v[13],v[14],v[15],v[16],v[17],v[18])
::method parseCheckpoint private
  use strict arg p
  if p~items<>19 then return .nil
  v=.array~new; do i=2 to 19; v~append(x2c(p[i])); end
  return .MigratableJobCheckpointManifest~new(v[1],v[2],v[3],v[4],v[5],v[6],v[7],v[8],v[9],v[10],v[11],v[12],v[13],v[14],v[15],v[16],v[17],v[18])
::method bool private
  use strict arg v
  s=v~string~upper
  return s="1" | s="TRUE"
::method split private
  use strict arg text
  a=.array~new; rest=text~string
  do forever
    p=rest~pos("|")
    if p=0 then do; a~append(rest); leave; end
    a~append(rest~left(p-1)); rest=rest~substr(p+1)
  end
  return a

::requires "MigratableJob.cls"
