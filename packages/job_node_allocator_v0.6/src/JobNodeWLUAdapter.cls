/* WLU v0.12 adapter for Job-to-Node Allocator v0.5. */
::class JobNodeWLUAdmission subclass JobNodeAdmissionAuthority public
::method init
  expose authority identity scopePrefix
  use strict arg authority, identity, scopePrefix="job-node"
  if authority==.nil | \authority~hasMethod("RESERVEDEMAND") | \authority~hasMethod("RELEASE") then raise syntax 88.900 array("JobNodeWLUAdmission requires WLUAuthority-compatible object")
::method reserve
  expose authority identity scopePrefix
  use strict arg placementRequest, capability, capacity, leaseDurationMs
  expected=placementRequest~expectedMicroWlu
  if expected<=0 then return .JobNodeAdmissionResult~allow
  rate=placementRequest~requestedRateMicroWluPerSecond
  demand=.WLUWorkDemand~new(expected,expected,0,rate)
  ttl=(leaseDurationMs+999)%1000
  if ttl<1 then ttl=1
  scope=scopePrefix || "/" || capability~nodeId
  requestId=placementRequest~jobId || ":" || capability~nodeId || ":" || capacity~observationGeneration
  r=authority~reserveDemand(identity,scope,demand,ttl,requestId)
  if \r~ok then return .JobNodeAdmissionResult~deny(r~code,r~detail)
  return .JobNodeAdmissionResult~allow(r~value,r~value~reservationId)
::method release
  expose authority
  use strict arg reservation
  r=authority~release(reservation)
  return r~ok
/* Durable reservation proof snapshot/recovery for allocator restart.
 * The WLU authority remains authoritative for live state; the reconstructed
 * proof is accepted only if reservationState still reports ACTIVE and the
 * authority later verifies the proof on mutation/release. */
::method snapshotReservation
  use strict arg reservation
  if reservation==.nil | \reservation~isA(.WLUReservation) then return ""
  proof=reservation~proof
  if proof==.nil then return ""
  fields=.array~of(reservation~reservationId,reservation~identity,reservation~accountId,reservation~scope,reservation~rateCardId,reservation~rateCardVersion,reservation~reservedMicroWlu,reservation~issuedTick,reservation~expiresTick,self~encodeList(reservation~bucketIds),reservation~proofRevision,proof~algorithm,proof~keyId,proof~tag,reservation~expectedMicroWlu,reservation~reservedRateMicroWluPerSecond,self~encodeList(reservation~throughputPoolIds))
  out="WLU1"
  do f over fields; out=out||"|"||c2x(f~string); end
  return out
::method restoreReservation
  use strict arg snapshot
  parts=self~split(snapshot)
  if parts~items<>18 | parts[1]<>"WLU1" then return .nil
  proof=.WLUProof~new(x2c(parts[13]),x2c(parts[14]),x2c(parts[15]))
  return .WLUReservation~new(x2c(parts[2]),x2c(parts[3]),x2c(parts[4]),x2c(parts[5]),x2c(parts[6]),x2c(parts[7]),x2c(parts[8]),x2c(parts[9]),x2c(parts[10]),self~decodeList(x2c(parts[11])),x2c(parts[12]),proof,x2c(parts[16]),x2c(parts[17]),self~decodeList(x2c(parts[18])))
::method reservationActive
  expose authority
  use strict arg reservation
  if reservation==.nil then return .false
  r=authority~reservationState(reservation~reservationId)
  return r~ok & r~value=.WLUReservationState~ACTIVE
::method encodeList private
  use strict arg values
  out=""; first=.true
  do v over values
    if \first then out=out||","; first=.false
    out=out||c2x(v~string)
  end
  return out
::method decodeList private
  use strict arg text
  a=.array~new; rest=text~string
  if rest="" then return a
  do forever
    p=rest~pos(",")
    if p=0 then do; a~append(x2c(rest)); leave; end
    a~append(x2c(rest~left(p-1))); rest=rest~substr(p+1)
  end
  return a
::method split private
  use strict arg text
  a=.array~new; rest=text~string
  do forever
    p=rest~pos("|")
    if p=0 then do; a~append(rest); leave; end
    a~append(rest~left(p-1)); rest=rest~substr(p+1)
  end
  return a

::requires "JobNodeAllocator.cls"
::requires "WorkLoadUnits.cls"
