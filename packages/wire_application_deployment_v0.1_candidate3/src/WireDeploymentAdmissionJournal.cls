/* Queue Fabric deployment admission journal (STRICT replay, single writer).
 * Dedicated journal root; no second ObjectQueueManager. Terminal status
 * evidence and deployment request identity survive application process restart.
 * The queue durable store does not independently prove fsync/power-loss safety.
 */
::class WireDeploymentJournalResult public
::attribute ok get
::attribute code get
::attribute value get
::method init
  expose ok code value
  use strict arg ok,code,value=''

::class WireDeploymentAdmissionJournal public
::method init
  expose store requests completed deliveries
  use strict arg root
  if root=='' then raise syntax 93.900 array('Dedicated journal directory required')
  store=.QueueDurableStore~new(root,.nil,.QueueRecoveryMode~STRICT)
  requests=.table~new
  completed=.table~new
  deliveries=.table~new
  self~replay

::method replay private
  expose store requests completed deliveries
  rows=store~readJournal
  do row over rows
    tag=row[1]
    select
      when tag=='WAPP_ADMIT' then do
        if row~items<>8 then raise syntax 93.900 array('Invalid WAPP admission record')
        delivery=row[2]; requestId=row[3]; fingerprint=row[4]; disposition=row[5]
        if delivery=='' | deliveries~hasIndex(delivery) then raise syntax 93.900 array('Duplicate or absent delivery identity in journal')
        deliveries[delivery]=disposition
        if requestId<>'' & disposition=='ACCEPTED' then do
          if requests~hasIndex(requestId) then raise syntax 93.900 array('Duplicate accepted request in journal')
          requests[requestId]=.array~of(fingerprint,row[6],row[7],row[8])
        end
      end
      when tag=='WAPP_COMPLETE' then do
        if row~items<>4 then raise syntax 93.900 array('Invalid completion record')
        if \requests~hasIndex(row[2]) then raise syntax 93.900 array('Completion without admission')
        if completed~hasIndex(row[2]) then raise syntax 93.900 array('Duplicate completion in journal')
        if row[3]=='' | row[4]=='' then raise syntax 93.900 array('Completion without evidence')
        completed[row[2]]=.array~of(row[3],row[4])
      end
      otherwise raise syntax 93.900 array('Unknown deployment journal tag: '||tag)
    end
  end

/* Append admission before Queue Fabric ACK. Same requestId/same tuple is
 * duplicate; same requestId/changed tuple is a recorded conflict. */
::method recordDisposition guarded
  expose store requests completed deliveries
  use strict arg deliveryId,outcome,body
  if deliveryId=='' then return .WireDeploymentJournalResult~new(.false,'INVALID_DELIVERY')
  if deliveries~hasIndex(deliveryId) then return .WireDeploymentJournalResult~new(.true,'RECORDED',deliveries[deliveryId])
  requestId=''; artifactDigest=''; artifactRef=''; target=''; fingerprint=''
  if body<>.nil then do
    if body~hasMethod('HASINDEX') then do
      if body~hasIndex('requestId') then requestId=body['requestId']~string
      if body~hasIndex('artifactDigest') then artifactDigest=body['artifactDigest']~string
      if body~hasIndex('artifactRef') then artifactRef=body['artifactRef']~string
      if body~hasIndex('target') then target=body['target']~string
    end
  end
  if outcome=='ACCEPTED' then do
    if requestId=='' | artifactDigest=='' | artifactRef=='' | target=='' then return .WireDeploymentJournalResult~new(.false,'INVALID_ADMISSION')
    fingerprint=self~fingerprint(artifactDigest,artifactRef,target)
    if requests~hasIndex(requestId) then do
      if requests[requestId][1]==fingerprint then outcome='DUPLICATE_REQUEST'
      else outcome='REJECTED_REQUEST_ID_CONFLICT'
    end
  end
  signal on syntax name journalFailure
  written=store~appendJournal('WAPP_ADMIT',.array~of(deliveryId,requestId,fingerprint,outcome,artifactDigest,artifactRef,target))
  signal off syntax
  if \written then return .WireDeploymentJournalResult~new(.false,'JOURNAL_WRITE_FAILED')
  deliveries[deliveryId]=outcome
  if outcome=='ACCEPTED' then requests[requestId]=.array~of(fingerprint,artifactDigest,artifactRef,target)
  return .WireDeploymentJournalResult~new(.true,'RECORDED',outcome)
journalFailure:
  signal off syntax
  return .WireDeploymentJournalResult~new(.false,'JOURNAL_WRITE_FAILED')

::method fingerprint private
  use strict arg artifactDigest,artifactRef,target
  return artifactDigest~length||':'||artifactDigest||artifactRef~length||':'||artifactRef||target~length||':'||target

::method pending unguarded
  expose requests completed
  answer=.array~new
  do requestId over requests
    if \completed~hasIndex(requestId) then answer~append(requestId)
  end
  return answer

::method admission unguarded
  expose requests
  use strict arg requestId
  return requests[requestId]

::method completion unguarded
  expose completed
  use strict arg requestId
  return completed[requestId]

::method complete guarded
  expose store requests completed
  use strict arg requestId,status,evidenceRef
  if \requests~hasIndex(requestId) then return .WireDeploymentJournalResult~new(.false,'UNKNOWN_REQUEST')
  if status<>'PROBED_ACTIVE' & status<>'FAILED' & status<>'ROLLED_BACK' & status<>'DEACTIVATED' then return .WireDeploymentJournalResult~new(.false,'INVALID_TERMINAL_STATUS')
  if evidenceRef=='' then return .WireDeploymentJournalResult~new(.false,'EVIDENCE_REQUIRED')
  if completed~hasIndex(requestId) then do
    old=completed[requestId]
    if old[1]==status & old[2]==evidenceRef then return .WireDeploymentJournalResult~new(.true,'ALREADY_COMPLETED',status)
    return .WireDeploymentJournalResult~new(.false,'COMPLETION_CONFLICT')
  end
  signal on syntax name completionFailure
  written=store~appendJournal('WAPP_COMPLETE',.array~of(requestId,status,evidenceRef))
  signal off syntax
  if \written then return .WireDeploymentJournalResult~new(.false,'JOURNAL_WRITE_FAILED')
  completed[requestId]=.array~of(status,evidenceRef)
  return .WireDeploymentJournalResult~new(.true,'COMPLETED',status)
completionFailure:
  signal off syntax
  return .WireDeploymentJournalResult~new(.false,'JOURNAL_WRITE_FAILED')

::requires 'ObjectQueueFabric.cls'
