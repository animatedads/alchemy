/*
 * WLUHierarchy.cls
 *
 * Hierarchical workload-budget constraints for Work Load Units.
 *
 * One unit of work is NEVER multiplied by the number of hierarchy levels.
 * A reservation made under ENTERPRISE -> TENANT -> SERVICE -> JOB is the same
 * work checked against four independent envelopes.  Each ancestor reflects
 * that same commitment/spend for constraint and audit purposes; roll-up values
 * must therefore not be summed as though they were independent work.
 *
 * Child budgets are ceilings, not allocations.  Sibling ceilings may
 * overcommit their parent nominally; live reservations still have to fit the
 * child and every ancestor atomically.
 */

::options digits 30

::class WLUHierarchyBuild public
::constant VERSION "0.2"
::constant API_VERSION "work.load.units.hierarchy/0.2"

::class WLUBudgetNodeLease public
::attribute nodeId get
::attribute nodeKey get
::attribute kind get
::attribute parentId get
::attribute budgetMicroWlu get
::attribute spentMicroWlu get
::attribute committedMicroWlu get
::attribute revision get
::attribute proof get

::method init
  expose nodeId nodeKey kind parentId budgetMicroWlu spentMicroWlu committedMicroWlu revision proof
  use strict arg nodeId, nodeKey, kind, parentId, budgetMicroWlu, spentMicroWlu, committedMicroWlu, revision, proof

::method remainingMicroWlu
  expose budgetMicroWlu spentMicroWlu committedMicroWlu
  return budgetMicroWlu - spentMicroWlu - committedMicroWlu

::method canonicalText
  expose nodeId nodeKey kind parentId budgetMicroWlu spentMicroWlu committedMicroWlu revision
  text = "wlu-budget-node-v1" || "0a"x
  text ||= self~field("node-id", nodeId)
  text ||= self~field("node-key", nodeKey)
  text ||= self~field("kind", kind)
  text ||= self~field("parent-id", parentId)
  text ||= self~field("budget-micro-wlu", budgetMicroWlu)
  text ||= self~field("spent-micro-wlu", spentMicroWlu)
  text ||= self~field("committed-micro-wlu", committedMicroWlu)
  text ||= self~field("revision", revision)
  return text

::method field private
  use strict arg name, value
  value = value~string
  return name || ":" || value~length || ":" || value || "0a"x

::class WLUBudgetNodeRecord public
::attribute nodeId get
::attribute nodeKey get
::attribute kind get
::attribute parentId get
::attribute budgetMicroWlu get
::attribute spentMicroWlu get
::attribute committedMicroWlu get
::attribute revision get

::method init
  expose nodeId nodeKey kind parentId budgetMicroWlu spentMicroWlu committedMicroWlu revision proof
  use strict arg nodeId, nodeKey, kind, parentId, budgetMicroWlu
  spentMicroWlu = 0
  committedMicroWlu = 0
  revision = 1
  proof = ""

::method remainingMicroWlu
  expose budgetMicroWlu spentMicroWlu committedMicroWlu
  return budgetMicroWlu - spentMicroWlu - committedMicroWlu

::method snapshot
  expose nodeId nodeKey kind parentId budgetMicroWlu spentMicroWlu committedMicroWlu revision proof
  return .WLUBudgetNodeLease~new(nodeId, nodeKey, kind, parentId, budgetMicroWlu, spentMicroWlu, committedMicroWlu, revision, proof)

::method refreshProof
  expose proof
  use strict arg keyRing
  snap = self~snapshot
  proof = keyRing~sign(snap~canonicalText)
  return self~snapshot

::method addCommitted
  expose committedMicroWlu revision
  use strict arg microWlu
  committedMicroWlu += microWlu
  revision += 1

::method settleCommitted
  expose committedMicroWlu spentMicroWlu revision
  use strict arg reservedMicroWlu, actualMicroWlu
  committedMicroWlu -= reservedMicroWlu
  spentMicroWlu += actualMicroWlu
  revision += 1

::method removeCommitted
  expose committedMicroWlu revision
  use strict arg microWlu
  if microWlu > committedMicroWlu then raise syntax 88.900 array("cannot remove more committed WLU than the node holds")
  committedMicroWlu -= microWlu
  revision += 1

::class WLUBudgetAssessment public
::attribute requestedMicroWlu get
::attribute ready get
::attribute limitingNodeId get
::attribute limitingNodeKey get
::attribute availableMicroWlu get
::attribute shortfallMicroWlu get
::attribute path get

::method init
  expose requestedMicroWlu ready limitingNodeId limitingNodeKey availableMicroWlu shortfallMicroWlu path
  use strict arg requestedMicroWlu, ready, limitingNodeId, limitingNodeKey, availableMicroWlu, shortfallMicroWlu, path

::class WLUBudgetHold public
::attribute holdId get
::attribute requestId get
::attribute nodeId get
::attribute reservedMicroWlu get
::attribute active get
::attribute actualMicroWlu get
::attribute revision get
::attribute proof get

::method init
  expose holdId requestId nodeId reservedMicroWlu active actualMicroWlu revision proof
  use strict arg holdId, requestId, nodeId, reservedMicroWlu
  active = .true
  actualMicroWlu = 0
  revision = 1
  proof = ""

::method canonicalText
  expose holdId requestId nodeId reservedMicroWlu active actualMicroWlu revision
  text = "wlu-budget-hold-v1" || "0a"x
  text ||= self~field("hold-id", holdId)
  text ||= self~field("request-id", requestId)
  text ||= self~field("node-id", nodeId)
  text ||= self~field("reserved-micro-wlu", reservedMicroWlu)
  text ||= self~field("active", active)
  text ||= self~field("actual-micro-wlu", actualMicroWlu)
  text ||= self~field("revision", revision)
  return text

::method refreshProof
  expose proof
  use strict arg keyRing
  proof = keyRing~sign(self~canonicalText)
  return self

::method close
  expose active actualMicroWlu revision
  use strict arg actual
  active = .false
  actualMicroWlu = actual
  revision += 1

::method increase
  expose reservedMicroWlu revision
  use strict arg extraMicroWlu
  reservedMicroWlu += extraMicroWlu
  revision += 1

::method decrease
  expose reservedMicroWlu revision
  use strict arg microWlu
  if microWlu > reservedMicroWlu then raise syntax 88.900 array("cannot reduce a budget hold below zero")
  reservedMicroWlu -= microWlu
  revision += 1

::method field private
  use strict arg name, value
  value = value~string
  return name || ":" || value~length || ":" || value || "0a"x

::class WLUHierarchyBudgetManager subclass AlchemyObject public
::attribute keyRing get

::method init
  expose keyRing nodes nodeKeys holds requestIds nodeIds holdIds
  use strict arg keyRing
  if keyRing == .nil | \keyRing~isA(.WLUFastMacKeyRing) then raise syntax 88.900 array("WLUHierarchyBudgetManager requires WLUFastMacKeyRing")
  nodes = .table~new
  nodeKeys = .table~new
  holds = .table~new
  requestIds = .table~new
  nodeIds = .WLUIdGenerator~new("wlu-budget")
  holdIds = .WLUIdGenerator~new("wlu-budget-hold")
  alchemyConstruction = .WLUAlchemySupport~construction(keyRing, "WLUHierarchyBudgetManager", "Hierarchical enterprise, tenant, service and job WLU budget authority")
  self~init:super(alchemyConstruction[1], alchemyConstruction[2], alchemyConstruction[3])
  ignore = .WLUAlchemySupport~finishConstruction(self)
  self~registerMethodContract("CREATEROOT", "Create a root workload-budget ceiling", .array~of("NODEKEY", "KIND", "BUDGETMICROWLU"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "GRANT")
  self~registerMethodContract("DELEGATE", "Create a child workload-budget ceiling beneath an authenticated parent", .array~of("PARENTLEASE", "NODEKEY", "KIND", "BUDGETMICROWLU"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "DELEGATE")
  self~registerMethodContract("ASSESS", "Assess a WLU request against a node and every ancestor", .array~of("NODELEASE", "MICROWLU"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("HOLD", "Atomically commit WLU against a node and every ancestor", .array~of("NODELEASE", "MICROWLU", "REQUESTID"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "GRANT")
  self~registerMethodContract("SETTLE", "Settle a hierarchy hold without double-counting work across levels", .array~of("HOLD", "ACTUALMICROWLU"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "REVOKE")
  self~registerMethodContract("RELEASE", "Release unused hierarchy commitment", .array~of("HOLD"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "REVOKE")
  self~registerMethodContract("ROLLBACKHOLD", "Abort an unpublished hierarchy subtransaction and forget its idempotency marker", .array~of("HOLD"), "WLURESULT", .true, "AUTO", "INTERNAL", "AUTHORITY", "MUTATE", "REVOKE")
  self~registerInstrumentationPoint("WLU.HIERARCHY", "hierarchical workload-budget authority boundary", .true, "COLLAPSE", "INTERNAL")

::method createRoot public protected
  expose keyRing nodes nodeKeys nodeIds
  use strict arg nodeKey, kind, budgetMicroWlu
  guard on
  nodeKey = nodeKey~string~strip
  kind = kind~string~strip~upper
  ignore = .WLUUnits~assertMicro(budgetMicroWlu)
  if nodeKey = "" | kind = "" then return .WLUResult~failure("WLU_BUDGET_NODE_INVALID", "node key and kind are required")
  if budgetMicroWlu <= 0 then return .WLUResult~failure("WLU_BUDGET_INVALID_AMOUNT", "budget must be positive")
  if nodeKeys~hasIndex(nodeKey) then return .WLUResult~failure("WLU_BUDGET_NODE_EXISTS", nodeKey)
  nodeId = nodeIds~next
  record = .WLUBudgetNodeRecord~new(nodeId, nodeKey, kind, "", budgetMicroWlu)
  lease = record~refreshProof(keyRing)
  nodes[nodeId] = record
  nodeKeys[nodeKey] = nodeId
  return .WLUResult~success(lease)

::method delegate public protected
  expose keyRing nodes nodeKeys nodeIds
  use strict arg parentLease, nodeKey, kind, budgetMicroWlu
  guard on
  validated = self~validateLease(parentLease)
  if \validated~ok then return validated
  parent = validated~value
  nodeKey = nodeKey~string~strip
  kind = kind~string~strip~upper
  ignore = .WLUUnits~assertMicro(budgetMicroWlu)
  if nodeKey = "" | kind = "" then return .WLUResult~failure("WLU_BUDGET_NODE_INVALID", "node key and kind are required")
  if budgetMicroWlu <= 0 then return .WLUResult~failure("WLU_BUDGET_INVALID_AMOUNT", "budget must be positive")
  if budgetMicroWlu > parent~budgetMicroWlu then return .WLUResult~failure("WLU_BUDGET_CHILD_EXCEEDS_PARENT", "child ceiling cannot exceed parent ceiling")
  if nodeKeys~hasIndex(nodeKey) then return .WLUResult~failure("WLU_BUDGET_NODE_EXISTS", nodeKey)
  nodeId = nodeIds~next
  record = .WLUBudgetNodeRecord~new(nodeId, nodeKey, kind, parent~nodeId, budgetMicroWlu)
  lease = record~refreshProof(keyRing)
  nodes[nodeId] = record
  nodeKeys[nodeKey] = nodeId
  return .WLUResult~success(lease)

::method current
  expose nodes keyRing
  use strict arg nodeId
  guard on
  record = nodes[nodeId~string]
  if record == .nil then return .WLUResult~failure("WLU_BUDGET_NODE_NOT_FOUND", nodeId~string)
  return .WLUResult~success(record~refreshProof(keyRing))

::method assess
  expose nodes
  use strict arg lease, microWlu
  guard on
  ignore = .WLUUnits~assertMicro(microWlu)
  if microWlu <= 0 then return .WLUResult~failure("WLU_BUDGET_INVALID_AMOUNT", "assessment amount must be positive")
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  leaf = validated~value
  pathResult = self~pathRecords(leaf~nodeId)
  path = pathResult~value
  limiting = .nil
  minAvailable = microWlu
  do record over path
    available = record~remainingMicroWlu
    if limiting == .nil | available < minAvailable then do
      limiting = record
      minAvailable = available
    end
  end
  shortfall = 0
  ready = .true
  if minAvailable < microWlu then do
    ready = .false
    shortfall = microWlu - minAvailable
  end
  snapshots = .array~new
  do record over path
    snapshots~append(record~snapshot)
  end
  return .WLUResult~success(.WLUBudgetAssessment~new(microWlu, ready, limiting~nodeId, limiting~nodeKey, minAvailable, shortfall, snapshots))

::method hold public protected
  expose keyRing holds requestIds holdIds
  use strict arg lease, microWlu, requestId = ""
  guard on
  ignore = .WLUUnits~assertMicro(microWlu)
  if microWlu <= 0 then return .WLUResult~failure("WLU_BUDGET_INVALID_AMOUNT", "hold amount must be positive")
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  leaf = validated~value
  requestId = requestId~string~strip
  if requestId \= "" & requestIds~hasIndex(requestId) then do
    oldHold = holds[requestIds[requestId]]
    if oldHold~nodeId \= leaf~nodeId | oldHold~reservedMicroWlu \= microWlu then return .WLUResult~failure("WLU_BUDGET_IDEMPOTENCY_CONFLICT", "request id reused with different budget hold")
    currentLeaf = self~current(leaf~nodeId)
    return .WLUResult~success(.array~of(currentLeaf~value, oldHold), "idempotent budget hold replay")
  end
  assessmentResult = self~assess(lease, microWlu)
  if \assessmentResult~ok then return assessmentResult
  assessment = assessmentResult~value
  if \assessment~ready then return .WLUResult~failure("WLU_BUDGET_EXHAUSTED", "limiting budget " || assessment~limitingNodeKey || " short by " || assessment~shortfallMicroWlu)
  path = self~pathRecords(leaf~nodeId)~value
  do record over path
    record~addCommitted(microWlu)
    ignore = record~refreshProof(keyRing)
  end
  holdId = holdIds~next
  budgetHold = .WLUBudgetHold~new(holdId, requestId, leaf~nodeId, microWlu)
  ignore = budgetHold~refreshProof(keyRing)
  holds[holdId] = budgetHold
  if requestId \= "" then requestIds[requestId] = holdId
  return .WLUResult~success(.array~of(leaf~snapshot, budgetHold))

::method topUp
  expose keyRing holds
  use strict arg budgetHold, extraMicroWlu
  guard on
  ignore = .WLUUnits~assertMicro(extraMicroWlu)
  if extraMicroWlu <= 0 then return .WLUResult~failure("WLU_BUDGET_INVALID_AMOUNT", "top-up must be positive")
  validated = self~validateHold(budgetHold)
  if \validated~ok then return validated
  authoritative = validated~value
  currentLeaf = self~current(authoritative~nodeId)~value
  assessmentResult = self~assess(currentLeaf, extraMicroWlu)
  if \assessmentResult~ok then return assessmentResult
  assessment = assessmentResult~value
  if \assessment~ready then return .WLUResult~failure("WLU_BUDGET_EXHAUSTED", "limiting budget " || assessment~limitingNodeKey || " short by " || assessment~shortfallMicroWlu)
  path = self~pathRecords(authoritative~nodeId)~value
  do record over path
    record~addCommitted(extraMicroWlu)
    ignore = record~refreshProof(keyRing)
  end
  authoritative~increase(extraMicroWlu)
  ignore = authoritative~refreshProof(keyRing)
  return .WLUResult~success(.array~of(self~current(authoritative~nodeId)~value, authoritative))

::method reduceHold
  expose keyRing
  use strict arg budgetHold, microWlu
  guard on
  ignore = .WLUUnits~assertMicro(microWlu)
  if microWlu <= 0 then return .WLUResult~failure("WLU_BUDGET_INVALID_AMOUNT", "hold reduction must be positive")
  validated = self~validateHold(budgetHold)
  if \validated~ok then return validated
  authoritative = validated~value
  if microWlu > authoritative~reservedMicroWlu then return .WLUResult~failure("WLU_BUDGET_HOLD_REDUCTION_INVALID", "hold reduction exceeds reserved WLU")
  path = self~pathRecords(authoritative~nodeId)~value
  do record over path
    record~removeCommitted(microWlu)
    ignore = record~refreshProof(keyRing)
  end
  authoritative~decrease(microWlu)
  ignore = authoritative~refreshProof(keyRing)
  return .WLUResult~success(.array~of(self~current(authoritative~nodeId)~value, authoritative))


::method rollbackHold public protected
  expose keyRing holds requestIds
  use strict arg budgetHold
  guard on
  validated = self~validateHold(budgetHold)
  if \validated~ok then return validated
  authoritative = validated~value
  path = self~pathRecords(authoritative~nodeId)~value
  do record over path
    record~removeCommitted(authoritative~reservedMicroWlu)
    ignore = record~refreshProof(keyRing)
  end
  requestId = authoritative~requestId
  if requestId \= "" then do
    mapped = requestIds[requestId]
    if mapped \== .nil then if mapped = authoritative~holdId then requestIds~remove(requestId)
  end
  holds~remove(authoritative~holdId)
  return .WLUResult~success(self~current(authoritative~nodeId)~value, "hierarchy hold rolled back before publication")

::method settle public protected
  expose keyRing
  use strict arg budgetHold, actualMicroWlu
  guard on
  ignore = .WLUUnits~assertMicro(actualMicroWlu)
  validated = self~validateHold(budgetHold)
  if \validated~ok then return validated
  authoritative = validated~value
  if actualMicroWlu < 0 | actualMicroWlu > authoritative~reservedMicroWlu then return .WLUResult~failure("WLU_BUDGET_SETTLEMENT_INVALID", "actual WLU must be between zero and reserved WLU")
  path = self~pathRecords(authoritative~nodeId)~value
  do record over path
    record~settleCommitted(authoritative~reservedMicroWlu, actualMicroWlu)
    ignore = record~refreshProof(keyRing)
  end
  authoritative~close(actualMicroWlu)
  ignore = authoritative~refreshProof(keyRing)
  return .WLUResult~success(self~current(authoritative~nodeId)~value)

::method release public protected
  use strict arg budgetHold
  return self~settle(budgetHold, 0)

::method path
  use strict arg lease
  guard on
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  records = self~pathRecords(validated~value~nodeId)~value
  snapshots = .array~new
  do record over records
    snapshots~append(record~snapshot)
  end
  return .WLUResult~success(snapshots)

::method validateLease private
  expose nodes keyRing
  use strict arg lease
  if lease == .nil | \lease~isA(.WLUBudgetNodeLease) then return .WLUResult~failure("WLU_BUDGET_LEASE_REQUIRED", "authenticated budget lease required")
  record = nodes[lease~nodeId]
  if record == .nil then return .WLUResult~failure("WLU_BUDGET_NODE_NOT_FOUND", lease~nodeId)
  if \keyRing~verify(lease~canonicalText, lease~proof) then return .WLUResult~failure("WLU_BUDGET_LEASE_PROOF_INVALID", "budget lease authentication failed")
  if lease~revision \= record~revision | lease~spentMicroWlu \= record~spentMicroWlu | lease~committedMicroWlu \= record~committedMicroWlu then return .WLUResult~failure("WLU_BUDGET_LEASE_STALE", "budget lease is no longer current")
  return .WLUResult~success(record)

::method validateHold private
  expose holds keyRing
  use strict arg budgetHold
  if budgetHold == .nil | \budgetHold~isA(.WLUBudgetHold) then return .WLUResult~failure("WLU_BUDGET_HOLD_REQUIRED", "authenticated budget hold required")
  authoritative = holds[budgetHold~holdId]
  if authoritative == .nil then return .WLUResult~failure("WLU_BUDGET_HOLD_NOT_FOUND", budgetHold~holdId)
  if \keyRing~verify(budgetHold~canonicalText, budgetHold~proof) then return .WLUResult~failure("WLU_BUDGET_HOLD_PROOF_INVALID", "budget hold authentication failed")
  if budgetHold~revision \= authoritative~revision | budgetHold~reservedMicroWlu \= authoritative~reservedMicroWlu | budgetHold~active \= authoritative~active then return .WLUResult~failure("WLU_BUDGET_HOLD_STALE", "budget hold is no longer current")
  if \authoritative~active then return .WLUResult~failure("WLU_BUDGET_HOLD_CLOSED", "budget hold is already closed")
  return .WLUResult~success(authoritative)

::method pathRecords private
  expose nodes
  use strict arg nodeId
  path = .array~new
  cursor = nodes[nodeId~string]
  if cursor == .nil then return .WLUResult~failure("WLU_BUDGET_NODE_NOT_FOUND", nodeId~string)
  do while cursor \== .nil
    path~append(cursor)
    parentId = cursor~parentId
    if parentId = "" then leave
    cursor = nodes[parentId]
    if cursor == .nil then return .WLUResult~failure("WLU_BUDGET_PARENT_NOT_FOUND", parentId)
  end
  return .WLUResult~success(path)

::requires "WorkLoadUnits.cls"
