/* POI Spatial Evidence Workbench — ooRexx dev1, source candidate.
 * Renderer-neutral, no external library dependency. Not runtime-qualified.
 * An overlap is a CANDIDATE, never proof of contact or identity.
 */
::class PoiEvidenceLedger public
::attribute records get
::method init
  expose records
  records = .array
::method append
  expose records
  use strict arg record
  if \record~isA(.PoiEvidenceRecord) then
    raise syntax 93.914 array ('PoiEvidenceRecord required')
  records~append(record)
  return records~items
::method forSubject
  expose records
  use strict arg subjectId
  result = .array
  do i = 1 to records~items
    r = records[i]
    if r~subjectId == subjectId then result~append(r)
  end
  return result

::class PoiEvidenceRecord public
::attribute recordId get
::attribute subjectId get
::attribute placeId get
::attribute timeExpression get
::attribute timeResolution get
::attribute evidenceRef get
::attribute assertionStatus get
::attribute methodRunRef get
::method init
  use strict arg recordId, subjectId, placeId, timeExpression, timeResolution, evidenceRef, assertionStatus, methodRunRef
  self~recordId = recordId
  self~subjectId = subjectId
  self~placeId = placeId
  self~timeExpression = timeExpression
  self~timeResolution = timeResolution
  self~evidenceRef = evidenceRef
  self~assertionStatus = assertionStatus
  self~methodRunRef = methodRunRef
::method candidateWith
  use strict arg other
  if \other~isA(.PoiEvidenceRecord) then return .false
  /* No date/time or geometry guessing. Only explicit matching resolved
     interval and place references can establish a candidate. */
  if self~placeId \== other~placeId then return .false
  if self~timeResolution \== 'RESOLVED_INTERVAL' then return .false
  if other~timeResolution \== 'RESOLVED_INTERVAL' then return .false
  if self~timeExpression \== other~timeExpression then return .false
  return .true

::class PoiMethodRun public
::attribute runId get
::attribute mode get
::attribute toolName get
::attribute toolVersion get
::attribute configDigest get
::attribute inputDigest get
::attribute outputDigest get
::attribute calibrationRef get
::method init
  use strict arg runId, mode, toolName, toolVersion, configDigest, inputDigest, outputDigest, calibrationRef
  if mode \== 'HUMAN' & mode \== 'AUTOMATED' then
    raise syntax 93.914 array ('Method mode must be HUMAN or AUTOMATED')
  self~runId = runId
  self~mode = mode
  self~toolName = toolName
  self~toolVersion = toolVersion
  self~configDigest = configDigest
  self~inputDigest = inputDigest
  self~outputDigest = outputDigest
  self~calibrationRef = calibrationRef
::method provenanceComplete
  return self~runId \== '' & self~toolName \== '' & self~toolVersion \== '' & self~inputDigest \== '' & self~outputDigest \== ''
