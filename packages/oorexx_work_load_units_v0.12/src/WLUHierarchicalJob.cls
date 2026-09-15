/*
 * WLUHierarchicalJob.cls
 *
 * Admission bridge between logical-job budgets and hierarchical enterprise
 * workload budgets.  A backend stage must fit BOTH its logical chat/job budget
 * and every hierarchy ancestor before WLUAuthority creates the execution
 * reservation.  No user-visible workload action occurs in this layer.
 */

::options digits 30

::class WLUHierarchicalJobBuild public
::constant VERSION "0.4"
::constant API_VERSION "work.load.units.hierarchical.job/0.4"

::class WLUHierarchicalStageAssessment public
::attribute jobAssessment get
::attribute hierarchyAssessment get

::method init
  expose jobAssessment hierarchyAssessment
  use strict arg jobAssessment, hierarchyAssessment = .nil

::method viable
  expose jobAssessment hierarchyAssessment
  if jobAssessment == .nil | \jobAssessment~viable then return .false
  if hierarchyAssessment == .nil then return .false
  return hierarchyAssessment~ready


::class WLUHierarchicalStandbyAssessment public
::attribute jobAssessment get
::attribute hierarchyAssessment get

::method init
  expose jobAssessment hierarchyAssessment
  use strict arg jobAssessment, hierarchyAssessment = .nil

::method ready
  expose jobAssessment hierarchyAssessment
  if jobAssessment == .nil | \jobAssessment~ready then return .false
  if hierarchyAssessment == .nil then return .false
  return hierarchyAssessment~ready


::class WLUHierarchicalJobManager subclass AlchemyObject public
::attribute jobManager get
::attribute hierarchy get

::method init
  expose jobManager hierarchy jobNodes reservationHolds
  use strict arg authority, hierarchy
  if authority == .nil | \authority~isA(.WLUAuthority) then raise syntax 88.900 array("WLUHierarchicalJobManager requires WLUAuthority")
  if hierarchy == .nil | \hierarchy~isA(.WLUHierarchyBudgetManager) then raise syntax 88.900 array("WLUHierarchicalJobManager requires WLUHierarchyBudgetManager")
  jobManager = .WLUJobBudgetManager~new(authority)
  jobNodes = .table~new
  reservationHolds = .table~new
  alchemyConstruction = .WLUAlchemySupport~construction(authority~keyRing, "WLUHierarchicalJobManager", "Bridge logical job budgets to hierarchical enterprise workload ceilings")
  self~init:super(alchemyConstruction[1], alchemyConstruction[2], alchemyConstruction[3])
  ignore = .WLUAlchemySupport~finishConstruction(self)
  self~recordRelationship("JOB_BUDGET_MANAGER", jobManager, "logical job and backend-stage budget authority", "INTERNAL")
  self~recordRelationship("HIERARCHY", hierarchy, "enterprise workload-budget hierarchy authority", "INTERNAL")
  self~recordRelationship("WLU_AUTHORITY", authority, "execution admission and settlement authority", "INTERNAL")
  self~registerMethodContract("OPENJOB", "Bind a logical job to an authenticated hierarchy node", .array~of("REQUEST", "BUDGETLEASE"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "DELEGATE")
  self~registerMethodContract("ASSESSSTAGE", "Assess stage viability across job, hierarchy and runtime WLU constraints", .array~of("JOBLEASE", "STAGEID"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("FORECAST", "Read the latest logical-job workload forecast through the hierarchy bridge", .array~of("JOBLEASE"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("REVISEFORECAST", "Record a non-entitling workload forecast revision through the hierarchy bridge", .array~of("JOBLEASE", "EXPECTEDREMAININGMICROWLU", "UPPERREMAININGMICROWLU", "CONFIDENCEBASISPOINTS"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "NONE")
  self~registerMethodContract("STANDBYSTAGE", "Register non-entitling rescue-stage standby intent through the hierarchy bridge", .array~of("JOBLEASE", "STAGEID", "TTLSECONDS", "PRIORITY", "REQUESTID"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "NONE")
  self~registerMethodContract("ASSESSSTANDBY", "Assess standby intent across logical job, hierarchy and runtime capacity", .array~of("JOBLEASE", "STANDBYLEASE"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("PROMOTESTANDBY", "Promote standby intent to a real hierarchy-backed execution reservation", .array~of("JOBLEASE", "STANDBYLEASE", "TTLSECONDS", "REQUESTID"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "GRANT")
  self~registerMethodContract("RELEASESTANDBY", "Release non-entitling standby intent", .array~of("JOBLEASE", "STANDBYLEASE"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "REVOKE")
  self~registerMethodContract("RESERVESTAGE", "Atomically bridge hierarchy hold and execution-stage reservation", .array~of("JOBLEASE", "STAGEID", "TTLSECONDS", "REQUESTID"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "GRANT")
  self~registerMethodContract("SETTLESTAGE", "Reconcile execution settlement into logical-job and hierarchy budgets", .array~of("JOBLEASE", "RESERVATION", "ACTUALMICROWLU"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "REVOKE")
  self~registerMethodContract("RECORDTRANSITION", "Record an application-declared fallback transition without changing hierarchy budget", .array~of("JOBLEASE", "FROMSTAGEID", "TOSTAGEID", "REASONCODE"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "NONE")
  self~registerMethodContract("ROUTEHISTORY", "Read authenticated logical-job route evidence", .array~of("JOBLEASE"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("SETTLESTAGEBREAKDOWN", "Settle execution and handoff WLU separately while reconciling the hierarchy", .array~of("JOBLEASE", "RESERVATION", "ACTUALWORKMICROWLU", "ACTUALHANDOFFMICROWLU"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "REVOKE")

::method openJob public protected
  expose jobManager hierarchy jobNodes
  use strict arg request, budgetLease
  guard on
  if request == .nil | \request~isA(.WLUJobRequest) then return .WLUResult~failure("WLU_JOB_REQUEST_REQUIRED", "openJob requires WLUJobRequest")
  pathResult = hierarchy~path(budgetLease)
  if \pathResult~ok then return pathResult
  if request~budgetMicroWlu > budgetLease~budgetMicroWlu then return .WLUResult~failure("WLU_JOB_BUDGET_EXCEEDS_DELEGATION", "logical job budget exceeds delegated hierarchy ceiling")
  opened = jobManager~openJob(request)
  if \opened~ok then return opened
  lease = opened~value
  if jobNodes~hasIndex(lease~jobId) then do
    if jobNodes[lease~jobId] \= budgetLease~nodeId then return .WLUResult~failure("WLU_JOB_HIERARCHY_IDEMPOTENCY_CONFLICT", "logical job was already bound to a different hierarchy node")
  end
  else jobNodes[lease~jobId] = budgetLease~nodeId
  return opened

::method budgetForJob
  expose hierarchy jobNodes
  use strict arg jobLease
  nodeId = jobNodes[jobLease~jobId]
  if nodeId == .nil then return .WLUResult~failure("WLU_JOB_HIERARCHY_NOT_BOUND", jobLease~jobId)
  return hierarchy~current(nodeId)

::method forecast
  expose jobManager
  use strict arg jobLease
  return jobManager~forecast(jobLease)

::method forecastHistory
  expose jobManager
  use strict arg jobLease
  return jobManager~forecastHistory(jobLease)

::method reviseForecast public protected
  expose jobManager
  use strict arg jobLease, expectedRemainingMicroWlu, upperRemainingMicroWlu = .nil, confidenceBasisPoints = 0, source = "APPLICATION", reason = ""
  return jobManager~reviseForecast(jobLease, expectedRemainingMicroWlu, upperRemainingMicroWlu, confidenceBasisPoints, source, reason)


::method standbyStage public protected
  expose jobManager
  use strict arg jobLease, stageId, ttlSeconds = 60, priority = 500, requestId = ""
  return jobManager~standbyStage(jobLease, stageId, ttlSeconds, priority, requestId)

::method standbyClaims
  expose jobManager
  use strict arg jobLease
  return jobManager~standbyClaims(jobLease)

::method assessStandby
  expose jobManager hierarchy jobNodes
  use strict arg jobLease, standbyLease
  guard on
  base = jobManager~assessStandby(jobLease, standbyLease)
  if \base~ok then return base
  jobAssessment = base~value
  nodeId = jobNodes[jobLease~jobId]
  if nodeId == .nil then return .WLUResult~failure("WLU_JOB_HIERARCHY_NOT_BOUND", jobLease~jobId)
  current = hierarchy~current(nodeId)
  if \current~ok then return current
  assessed = hierarchy~assess(current~value, standbyLease~ceilingMicroWlu)
  if \assessed~ok then return assessed
  return .WLUResult~success(.WLUHierarchicalStandbyAssessment~new(jobAssessment, assessed~value))

::method promoteStandby public protected
  expose jobManager
  use strict arg jobLease, standbyLease, ttlSeconds = 30, requestId = ""
  guard on
  assessed = self~assessStandby(jobLease, standbyLease)
  if \assessed~ok then return assessed
  if assessed~value~jobAssessment~effectiveState = .WLUJobStandbyState~EXPIRED then return .WLUResult~failure("WLU_STANDBY_EXPIRED", standbyLease~standbyId)
  if standbyLease~state \= .WLUJobStandbyState~ACTIVE then return .WLUResult~failure("WLU_STANDBY_NOT_ACTIVE", standbyLease~state)
  reserved = self~reserveStage(jobLease, standbyLease~stageId, ttlSeconds, requestId)
  if \reserved~ok then return reserved
  freshLease = reserved~value[1]
  child = reserved~value[2]
  hierarchyLease = reserved~value[3]
  marked = jobManager~markStandbyPromoted(freshLease, standbyLease, child~reservationId)
  if \marked~ok then do
    rollback = self~releaseStage(freshLease, child)
    if \rollback~ok then return .WLUResult~failure("WLU_STANDBY_PROMOTION_ROLLBACK_FAILED", "standby state update failed and execution reservation could not be rolled back")
    return marked
  end
  return .WLUResult~success(.array~of(freshLease, child, hierarchyLease, marked~value), "standby promoted across logical job, hierarchy and runtime authorities")

::method releaseStandby public protected
  expose jobManager
  use strict arg jobLease, standbyLease
  return jobManager~releaseStandby(jobLease, standbyLease)


::method routeHistory
  expose jobManager
  use strict arg jobLease
  return jobManager~routeHistory(jobLease)

::method routeSummary
  expose jobManager
  use strict arg jobLease
  return jobManager~routeSummary(jobLease)

::method recordTransition public protected
  expose jobManager
  use strict arg jobLease, fromStageId, toStageId, reasonCode, evidenceRef = "", standbyLease = .nil, requestId = ""
  return jobManager~recordTransition(jobLease, fromStageId, toStageId, reasonCode, evidenceRef, standbyLease, requestId)


::method assessStage
  expose jobManager hierarchy jobNodes
  use strict arg jobLease, stageId
  guard on
  base = jobManager~assessStage(jobLease, stageId)
  if \base~ok then return base
  jobAssessment = base~value
  nodeId = jobNodes[jobLease~jobId]
  if nodeId == .nil then return .WLUResult~failure("WLU_JOB_HIERARCHY_NOT_BOUND", jobLease~jobId)
  hierarchyAssessment = .nil
  if jobAssessment~budgetShortfallMicroWlu = 0 then do
    current = hierarchy~current(nodeId)
    if \current~ok then return current
    assessed = hierarchy~assess(current~value, jobAssessment~stageCeilingMicroWlu)
    if \assessed~ok then return assessed
    hierarchyAssessment = assessed~value
  end
  return .WLUResult~success(.WLUHierarchicalStageAssessment~new(jobAssessment, hierarchyAssessment))

::method reserveStage public protected
  expose jobManager hierarchy jobNodes reservationHolds
  use strict arg jobLease, stageId, ttlSeconds = 30, requestId = ""
  guard on
  baseAssessment = jobManager~assessStage(jobLease, stageId)
  if \baseAssessment~ok then return baseAssessment
  ja = baseAssessment~value
  if ja~budgetShortfallMicroWlu > 0 then return .WLUResult~failure("WLU_JOB_BUDGET_EXHAUSTED", "stage exceeds remaining logical-job budget by " || ja~budgetShortfallMicroWlu)
  nodeId = jobNodes[jobLease~jobId]
  if nodeId == .nil then return .WLUResult~failure("WLU_JOB_HIERARCHY_NOT_BOUND", jobLease~jobId)
  current = hierarchy~current(nodeId)
  if \current~ok then return current
  hierarchyRequestId = requestId~string~strip
  if hierarchyRequestId \= "" then hierarchyRequestId = jobLease~jobId || ":" || stageId~string || ":" || hierarchyRequestId
  h = hierarchy~hold(current~value, ja~stageCeilingMicroWlu, hierarchyRequestId)
  if \h~ok then return h
  budgetHold = h~value[2]
  reserved = jobManager~reserveStage(jobLease, stageId, ttlSeconds, requestId)
  if \reserved~ok then do
    rollback = hierarchy~rollbackHold(budgetHold)
    if \rollback~ok then return .WLUResult~failure("WLU_HIERARCHY_ROLLBACK_FAILED", "core admission failed and hierarchy hold could not be rolled back")
    return reserved
  end
  child = reserved~value[2]
  reservationHolds[child~reservationId] = budgetHold
  return .WLUResult~success(.array~of(reserved~value[1], child, h~value[1]), "job lease, child reservation and hierarchy lease")

::method consumeStage
  expose jobManager
  use strict arg jobLease, reservation, microWlu, operationId = ""
  return jobManager~consumeStage(jobLease, reservation, microWlu, operationId)

::method consumeStageFacts
  expose jobManager
  use strict arg jobLease, reservation, facts, operationId = ""
  return jobManager~consumeStageFacts(jobLease, reservation, facts, operationId)

::method topUpStage
  expose jobManager hierarchy reservationHolds
  use strict arg jobLease, reservation, extraMicroWlu
  guard on
  budgetHold = reservationHolds[reservation~reservationId]
  if budgetHold == .nil then return .WLUResult~failure("WLU_JOB_HIERARCHY_HOLD_NOT_FOUND", reservation~reservationId)
  ht = hierarchy~topUp(budgetHold, extraMicroWlu)
  if \ht~ok then return ht
  topped = jobManager~topUpStage(jobLease, reservation, extraMicroWlu)
  if \topped~ok then do
    rollback = hierarchy~reduceHold(budgetHold, extraMicroWlu)
    if \rollback~ok then return .WLUResult~failure("WLU_HIERARCHY_ROLLBACK_FAILED", "core top-up failed and hierarchy top-up could not be rolled back")
    return topped
  end
  return .WLUResult~success(.array~of(topped~value[1], topped~value[2], ht~value[1]))

::method settleStage public protected
  expose jobManager hierarchy reservationHolds
  use strict arg jobLease, reservation, actualMicroWlu = .nil
  guard on
  budgetHold = reservationHolds[reservation~reservationId]
  if budgetHold == .nil then return .WLUResult~failure("WLU_JOB_HIERARCHY_HOLD_NOT_FOUND", reservation~reservationId)
  if actualMicroWlu == .nil then return .WLUResult~failure("WLU_JOB_ACTUAL_REQUIRED", "hierarchical job settlement requires actual WLU")
  settled = jobManager~settleStage(jobLease, reservation, actualMicroWlu)
  if \settled~ok then return settled
  hs = hierarchy~settle(budgetHold, actualMicroWlu)
  if \hs~ok then return .WLUResult~failure("WLU_HIERARCHY_RECONCILIATION_FAILED", "execution settled but hierarchy settlement failed: " || hs~code)
  reservationHolds~remove(reservation~reservationId)
  return .WLUResult~success(.array~of(settled~value, hs~value))


::method settleStageBreakdown public protected
  expose jobManager hierarchy reservationHolds
  use strict arg jobLease, reservation, actualWorkMicroWlu, actualHandoffMicroWlu = 0, outcomeCode = "SETTLED", evidenceRef = ""
  guard on
  budgetHold = reservationHolds[reservation~reservationId]
  if budgetHold == .nil then return .WLUResult~failure("WLU_JOB_HIERARCHY_HOLD_NOT_FOUND", reservation~reservationId)
  ignore = .WLUUnits~assertMicro(actualWorkMicroWlu)
  ignore = .WLUUnits~assertMicro(actualHandoffMicroWlu)
  actualMicroWlu = actualWorkMicroWlu + actualHandoffMicroWlu
  settled = jobManager~settleStageBreakdown(jobLease, reservation, actualWorkMicroWlu, actualHandoffMicroWlu, outcomeCode, evidenceRef)
  if \settled~ok then return settled
  hs = hierarchy~settle(budgetHold, actualMicroWlu)
  if \hs~ok then return .WLUResult~failure("WLU_HIERARCHY_RECONCILIATION_FAILED", "execution settled but hierarchy settlement failed: " || hs~code)
  reservationHolds~remove(reservation~reservationId)
  return .WLUResult~success(.array~of(settled~value[1], settled~value[2], hs~value))

::method releaseStage
  expose jobManager hierarchy reservationHolds
  use strict arg jobLease, reservation
  guard on
  budgetHold = reservationHolds[reservation~reservationId]
  if budgetHold == .nil then return .WLUResult~failure("WLU_JOB_HIERARCHY_HOLD_NOT_FOUND", reservation~reservationId)
  usage = jobManager~authority~reservationConsumed(reservation)
  if \usage~ok then return usage
  released = jobManager~releaseStage(jobLease, reservation)
  if \released~ok then return released
  hs = hierarchy~settle(budgetHold, usage~value)
  if \hs~ok then return .WLUResult~failure("WLU_HIERARCHY_RECONCILIATION_FAILED", "execution released but hierarchy settlement failed: " || hs~code)
  reservationHolds~remove(reservation~reservationId)
  return .WLUResult~success(.array~of(released~value, hs~value))

::requires "WLUJobBudget.cls"
::requires "WLUHierarchy.cls"
