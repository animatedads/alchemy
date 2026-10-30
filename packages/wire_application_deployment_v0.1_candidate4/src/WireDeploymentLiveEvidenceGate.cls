/* Wire -> General ooRexx Deployment dev4 live-evidence adapter.
 * A WAPP_ADMIT entry is not a successful installation. This gate accepts
 * only a matching hosted-module lifecycle + independently verified live
 * probe before appending PROBED_ACTIVE to the existing admission ledger.
 *
 * The external probe verifier is a required, trusted host dependency:
 * no browser-provided proof, no boolean 'installed' and no mock in production.
 */
::options numeric inherit

::class WireDeploymentLiveProbeReceipt public
::attribute requestId get
::attribute applicationId get
::attribute artifactDigest get
::attribute target get
::attribute generation get
::attribute mount get
::attribute hostedEvidence get
::attribute evidenceRef get
::method init
  expose requestId applicationId artifactDigest target generation mount hostedEvidence evidenceRef
  use strict arg requestId,applicationId,artifactDigest,target,generation,mount,hostedEvidence,evidenceRef

::class WireDeploymentEvidenceResult public
::attribute ok get
::attribute code get
::attribute detail get
::method init
  expose ok code detail
  use strict arg ok,code,detail=''

::class WireDeploymentLiveEvidenceGate public
::method init
  expose journal trustedProbeAuthority
  use strict arg journal,trustedProbeAuthority
  if journal==.nil | trustedProbeAuthority==.nil then raise syntax 93.900 array('Journal and independent live-probe authority required')
  if \trustedProbeAuthority~hasMethod('VERIFYLIVEPROBE') then raise syntax 93.900 array('Trusted probe verifier missing')

::method confirm
  expose journal trustedProbeAuthority
  use strict arg receipt
  if receipt==.nil then return .WireDeploymentEvidenceResult~new(.false,'RECEIPT_REQUIRED')
  if \receipt~isA(.WireDeploymentLiveProbeReceipt) then return .WireDeploymentEvidenceResult~new(.false,'INVALID_RECEIPT_TYPE')
  req=receipt~requestId
  if req=='' then return .WireDeploymentEvidenceResult~new(.false,'REQUEST_ID_REQUIRED')
  admission=journal~admission(req)
  if admission==.nil then return .WireDeploymentEvidenceResult~new(.false,'UNKNOWN_ADMISSION')
  if receipt~artifactDigest<>admission[2] | receipt~target<>admission[4] then return .WireDeploymentEvidenceResult~new(.false,'ADMISSION_MISMATCH')
  if receipt~applicationId=='' | receipt~generation=='' then return .WireDeploymentEvidenceResult~new(.false,'IDENTITY_REQUIRED')
  if receipt~mount=='' | receipt~mount~left(1)<>'/' then return .WireDeploymentEvidenceResult~new(.false,'MOUNT_REQUIRED')
  if receipt~evidenceRef~left(17)<>'storage-fabric://' | receipt~evidenceRef~length<=17 then return .WireDeploymentEvidenceResult~new(.false,'IMMUTABLE_EVIDENCE_REQUIRED')
  moduleEvidence=receipt~hostedEvidence
  if moduleEvidence==.nil then return .WireDeploymentEvidenceResult~new(.false,'HOSTED_LIFECYCLE_EVIDENCE_REQUIRED')
  if \moduleEvidence~isA(.HostedModuleEvidence) then return .WireDeploymentEvidenceResult~new(.false,'INVALID_HOSTED_LIFECYCLE')
  if moduleEvidence~moduleId<>receipt~applicationId then return .WireDeploymentEvidenceResult~new(.false,'APPLICATION_MISMATCH')
  if moduleEvidence~requestId<>req | moduleEvidence~hostGeneration<>receipt~generation then return .WireDeploymentEvidenceResult~new(.false,'GENERATION_OR_REQUEST_MISMATCH')
  if moduleEvidence~probePath<>receipt~mount | moduleEvidence~probeStatus<>'PASS' then return .WireDeploymentEvidenceResult~new(.false,'PROBE_PATH_OR_STATUS_INVALID')
  if \moduleEvidence~satisfied | moduleEvidence~state<>'PROBED_ACTIVE' then return .WireDeploymentEvidenceResult~new(.false,'LIFECYCLE_NOT_PROBED')
  /* The trust authority MUST verify a live HTTPS/TLS + Wire WSS semantic
   * observation under the host's LDAP policy and bind the evidence reference
   * to the admitted package digest, target and active generation. */
  if \trustedProbeAuthority~verifyLiveProbe(receipt,admission) then return .WireDeploymentEvidenceResult~new(.false,'EXTERNAL_PROBE_UNVERIFIED')
  committed=journal~complete(req,'PROBED_ACTIVE',receipt~evidenceRef)
  if \committed~ok then return .WireDeploymentEvidenceResult~new(.false,committed~code)
  return .WireDeploymentEvidenceResult~new(.true,committed~code,receipt~evidenceRef)

::requires 'WireDeploymentAdmissionJournal.cls'
::requires 'HostedModuleDeployment.cls'
