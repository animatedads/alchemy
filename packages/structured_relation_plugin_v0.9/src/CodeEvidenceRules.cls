/*
 * CodeEvidenceRules v0.6
 *
 * Small HardWorld-oriented rule examples.  These rules intentionally evaluate
 * evidence-bearing objects; they do not treat API names such as memcpy as a
 * verdict by themselves.
 */

::class ContextualMemoryRule public

::method assess class
  use arg change
  before = change~beforeOperation
  after = change~afterOperation
  if before == .nil then return self~contextFinding(change, "No predecessor operation is available")
  if after == .nil then return self~contextFinding(change, "No successor operation is available")

  beforeGuard = before~property("guard", "")
  afterGuard = after~property("guard", "")
  beforeExtent = before~property("destinationExtent", .nil)
  afterExtent = after~property("destinationExtent", .nil)
  domain = before~property("sensitiveDomain", "")

  /* A removed bounds invariant is materially different from merely using memcpy. */
  if beforeGuard \= "" then do
    if afterGuard = "" then do
      finding = .CodeAnalysisFinding~new("MEMORY.BOUNDS_HISTORY", "HIGH", "BOUNDS_INVARIANT_REMOVED", -
          "A predecessor bounds invariant is absent from the successor operation; review reachability and length provenance before accepting the change.", -
          change, "HIGH")
      finding~addEvidence(before)
      finding~addEvidence(after)
      finding~addEvidence(change~pullRequest)
      if domain \= "" then finding~addEvidence(.GitHubClaimEvidence~new("SENSITIVE_DOMAIN", domain, "DERIVED_FROM_CODE_MODEL", before~sourceEvidence, "MODELLED"))
      return finding
    end
  end

  if before~api~caselessEquals("memcpy") then do
    if after~api~caselessEquals("std::copy") then do
      if beforeGuard \= "" & afterGuard = beforeGuard then do
        finding = .CodeAnalysisFinding~new("MEMORY.API_SEMANTICS", "INFO", "SEMANTIC_SAFETY_REFINEMENT", -
            "The memory operation changes API semantics while preserving the modelled bounds invariant; assess the stated empty-range problem, tests, and review evidence rather than flagging memcpy by name.", -
            change, "HIGH")
        finding~addEvidence(before)
        finding~addEvidence(after)
        do claim over change~claims
          finding~addEvidence(claim)
        end
        do testEvidence over change~tests
          finding~addEvidence(testEvidence)
        end
        do reviewEvidence over change~reviews
          finding~addEvidence(reviewEvidence)
        end
        return finding
      end
    end
  end

  return self~contextFinding(change, "A memory operation is present but the available evidence is insufficient for a safety verdict")

::method contextFinding class private
  use arg change, message
  finding = .CodeAnalysisFinding~new("MEMORY.CONTEXT_REQUIRED", "INFO", "MEMORY_OPERATION_NEEDS_CONTEXT", message, change, "LOW")
  if change~beforeOperation \== .nil then finding~addEvidence(change~beforeOperation)
  if change~afterOperation \== .nil then finding~addEvidence(change~afterOperation)
  return finding


::class PerformanceEvidenceRule public

::method assess class
  use arg pr
  uncertainty = pr~claimsByCategory("UNCERTAINTY")
  measurements = pr~claimsByCategory("MEASUREMENT")
  if pr~draft | uncertainty~items > 0 then do
    finding = .CodeAnalysisFinding~new("PERFORMANCE.EVIDENCE_STATE", "INFO", "PERFORMANCE_CHANGE_UNSETTLED", -
        "Performance intent is supported by source-reported evidence but the change itself records unresolved validation or remeasurement state.", -
        pr, "MEDIUM")
    do claim over measurements
      finding~addEvidence(claim)
    end
    do claim over uncertainty
      finding~addCounterEvidence(claim)
    end
    do check over pr~checks
      finding~addCounterEvidence(check)
    end
    return finding
  end
  finding = .CodeAnalysisFinding~new("PERFORMANCE.EVIDENCE_STATE", "INFO", "PERFORMANCE_EVIDENCE_PRESENT", -
      "Performance evidence is present without an explicit unresolved-state marker in this snapshot.", pr, "MEDIUM")
  do claim over measurements
    finding~addEvidence(claim)
  end
  return finding

::requires "GitHubEvidence.cls"

/*
 * v0.6 semantic rules operate on revision-bound syntax / CFG objects rather
 * than API-name observations.  Their findings deliberately state the limits
 * of the bounded analyser instead of promoting absence-of-evidence to proof.
 */
::class SemanticMemoryHistoryRule public

::method assess class
  use arg semanticChange
  before = semanticChange~beforeOperation
  after = semanticChange~afterOperation
  if before == .nil | after == .nil then do
    f = .CodeAnalysisFinding~new("MEMORY.SEMANTIC_HISTORY", "INFO", "SEMANTIC_CONTEXT_INCOMPLETE", -
        "A predecessor or successor memory operation is unavailable in the bounded semantic model.", semanticChange, "LOW")
    if before \== .nil then f~addEvidence(before)
    if after \== .nil then f~addEvidence(after)
    return f
  end

  if semanticChange~guardRemoved then do
    f = .CodeAnalysisFinding~new("MEMORY.SEMANTIC_HISTORY", "HIGH", "BOUNDS_INVARIANT_REMOVED", -
        "A memory operation that was dominated by a source-level guard is no longer dominated by that guard in the successor symbol revision.", -
        semanticChange, "HIGH")
    f~addEvidence(before)
    f~addEvidence(before~parentGuard)
    f~addEvidence(after)
    if semanticChange~changeEvidence \== .nil then f~addEvidence(semanticChange~changeEvidence)
    return f
  end

  if semanticChange~guardPreserved then do
    f = .CodeAnalysisFinding~new("MEMORY.SEMANTIC_HISTORY", "INFO", "BOUNDS_INVARIANT_PRESERVED", -
        "The bounded semantic model observes the same dominating guard around the predecessor and successor memory operations.", -
        semanticChange, "HIGH")
    f~addEvidence(before)
    f~addEvidence(before~parentGuard)
    f~addEvidence(after)
    f~addEvidence(after~parentGuard)
    if semanticChange~changeEvidence \== .nil then f~addEvidence(semanticChange~changeEvidence)
    return f
  end

  f = .CodeAnalysisFinding~new("MEMORY.SEMANTIC_HISTORY", "INFO", "MEMORY_OPERATION_NEEDS_CONTEXT", -
      "The bounded semantic model cannot establish a preserved or removed guard relation for this memory-operation change.", -
      semanticChange, "LOW")
  f~addEvidence(before)
  f~addEvidence(after)
  return f


::class MemoryLifetimeRule public

::method assess class
  use arg symbol
  allocations = symbol~operations("ALLOCATE")
  releases = symbol~operations("RELEASE")
  if allocations~items = 0 then return .CodeAnalysisFinding~new("MEMORY.LIFETIME", "INFO", "NO_LOCAL_ALLOCATION_MODELLED", -
      "No supported local allocation operation is present in this symbol revision.", symbol, "HIGH")

  allocation = allocations[1]
  name = allocation~destination
  if name = "" then do
    f = .CodeAnalysisFinding~new("MEMORY.LIFETIME", "INFO", "ALLOCATION_OWNERSHIP_UNKNOWN", -
        "An allocation is present but the bounded model cannot identify the receiving local object.", symbol, "LOW")
    f~addEvidence(allocation)
    return f
  end

  do release over releases
    if release~destination~strip~caselessEquals(name) then do
      f = .CodeAnalysisFinding~new("MEMORY.LIFETIME", "INFO", "ALLOCATION_RELEASE_OBSERVED", -
          "The bounded model observes a release of the local allocation in this symbol revision.", symbol, "MEDIUM")
      f~addEvidence(allocation)
      f~addEvidence(release)
      return f
    end
  end

  do returnNode over symbol~returns
    if returnNode~expression~strip~caselessEquals(name) then do
      f = .CodeAnalysisFinding~new("MEMORY.LIFETIME", "INFO", "OWNERSHIP_TRANSFER_OBSERVED", -
          "The allocated local object is returned from the function; ownership appears to leave the local scope rather than being proved leaked.", -
          symbol, "MEDIUM")
      f~addEvidence(allocation)
      f~addEvidence(returnNode)
      return f
    end
  end

  f = .CodeAnalysisFinding~new("MEMORY.LIFETIME", "MEDIUM", "POSSIBLE_UNRELEASED_LOCAL_ALLOCATION", -
      "The bounded model observes a local allocation but no matching release or direct return of that object. This is a review finding, not proof of a leak: aliases, ownership transfer through calls, exceptional flow, and macro expansion are not yet fully modelled.", -
      symbol, "MEDIUM")
  f~addEvidence(allocation)
  do returnNode over symbol~returns
    f~addCounterEvidence(returnNode)
  end
  return f

::requires "CodeSemanticSource.cls"
