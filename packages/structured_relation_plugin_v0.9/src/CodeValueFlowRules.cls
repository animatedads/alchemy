/*
 * CodeValueFlowRules v0.7
 *
 * HardWorld-oriented rules over revision-bound value/alias flow.  These rules
 * intentionally distinguish textual proximity from demonstrated value flow.
 */

::class MemoryValueFlowHistoryRule public

::method assess class
  use arg semanticChange, beforeFlowArg = .nil, afterFlowArg = .nil
  beforeOp = semanticChange~beforeOperation
  afterOp = semanticChange~afterOperation
  if beforeOp == .nil then return self~incomplete(semanticChange, "Predecessor memory operation unavailable")
  if afterOp == .nil then return self~incomplete(semanticChange, "Successor memory operation unavailable")

  if beforeFlowArg == .nil then beforeFlow = .CxxValueFlowAnalyzer~analyze(semanticChange~beforeSymbol)
  else beforeFlow = beforeFlowArg
  if afterFlowArg == .nil then afterFlow = .CxxValueFlowAnalyzer~analyze(semanticChange~afterSymbol)
  else afterFlow = afterFlowArg

  beforeConstraint = beforeFlow~protectingConstraint(beforeOp)
  afterConstraint = afterFlow~protectingConstraint(afterOp)

  if beforeConstraint \== .nil then do
    if afterConstraint == .nil then do
      f = .CodeAnalysisFinding~new("MEMORY.VALUE_FLOW_HISTORY", "HIGH", "BOUNDS_VALUE_FLOW_PROTECTION_REMOVED", -
          "The predecessor memory length is constrained by a dominating guard that fits the modelled destination extent, but equivalent value-flow protection cannot be established for the successor operation.", -
          semanticChange, "HIGH")
      f~addEvidence(beforeOp)
      f~addEvidence(beforeConstraint)
      do edge over beforeFlow~lineageEdges(beforeFlow~memoryLengthSubject(beforeOp))
        f~addEvidence(edge)
      end
      f~addEvidence(afterOp)
      if afterOp~parentGuard \== .nil then f~addCounterEvidence(afterOp~parentGuard)
      do edge over afterFlow~lineageEdges(afterFlow~memoryLengthSubject(afterOp))
        f~addCounterEvidence(edge)
      end
      return f
    end
  end

  if beforeConstraint \== .nil then do
    if afterConstraint \== .nil then do
      f = .CodeAnalysisFinding~new("MEMORY.VALUE_FLOW_HISTORY", "INFO", "BOUNDS_VALUE_FLOW_PROTECTION_PRESERVED", -
          "Both revisions retain a dominating guard that constrains the value used as the memory-operation length within the modelled destination extent.", -
          semanticChange, "HIGH")
      f~addEvidence(beforeOp)
      f~addEvidence(beforeConstraint)
      f~addEvidence(afterOp)
      f~addEvidence(afterConstraint)
      return f
    end
  end

  if afterFlow~hasDominatingConstraint(afterOp) then do
    f = .CodeAnalysisFinding~new("MEMORY.VALUE_FLOW_HISTORY", "MEDIUM", "DOMINATING_GUARD_NOT_LINKED_TO_WRITE_LENGTH", -
        "A guard dominates the successor memory operation, but the bounded value-flow graph cannot show that the guard constrains the value actually used as the write length.", -
        semanticChange, "MEDIUM")
    f~addEvidence(afterOp)
    if afterOp~parentGuard \== .nil then f~addEvidence(afterOp~parentGuard)
    return f
  end

  return self~incomplete(semanticChange, "No source-level value-flow proof connects a dominating bounds guard to the modelled memory length")

::method incomplete class private
  use arg semanticChange, message
  f = .CodeAnalysisFinding~new("MEMORY.VALUE_FLOW_HISTORY", "INFO", "VALUE_FLOW_CONTEXT_INCOMPLETE", message, semanticChange, "LOW")
  if semanticChange~beforeOperation \== .nil then f~addEvidence(semanticChange~beforeOperation)
  if semanticChange~afterOperation \== .nil then f~addEvidence(semanticChange~afterOperation)
  return f


::class MemoryOwnershipFlowRule public

::method assess class
  use arg symbol, flowArg = .nil
  if flowArg == .nil then flow = .CxxValueFlowAnalyzer~analyze(symbol)
  else flow = flowArg
  allocations = symbol~operations("ALLOCATE")
  if allocations~items = 0 then return .CodeAnalysisFinding~new("MEMORY.OWNERSHIP_FLOW", "INFO", "NO_LOCAL_ALLOCATION_MODELLED", -
      "No supported local allocation operation is present in this symbol revision.", symbol, "HIGH")

  allocation = allocations[1]
  objectName = allocation~destination~strip
  if objectName = "" then do
    f = .CodeAnalysisFinding~new("MEMORY.OWNERSHIP_FLOW", "INFO", "ALLOCATION_OWNERSHIP_UNKNOWN", -
        "An allocation is present but its receiving local object is not identified by the bounded model.", symbol, "LOW")
    f~addEvidence(allocation)
    return f
  end

  releases = symbol~operations("RELEASE")
  do release over releases
    released = release~destination~strip
    if released = "" then iterate
    if flow~exactEquivalent(released, objectName) then do
      f = .CodeAnalysisFinding~new("MEMORY.OWNERSHIP_FLOW", "INFO", "ALLOCATION_RELEASE_VIA_ALIAS_OBSERVED", -
          "The allocation is released through the same local object or an exact alias retained in the value-flow graph.", symbol, "HIGH")
      f~addEvidence(allocation)
      if \released~caselessEquals(objectName) then do
        do edge over flow~lineageEdges(released)
          f~addEvidence(edge)
        end
      end
      f~addEvidence(release)
      return f
    end
  end

  do returnNode over symbol~returns
    returned = returnNode~expression~strip
    if returned = "" then iterate
    if flow~exactEquivalent(returned, objectName) then do
      f = .CodeAnalysisFinding~new("MEMORY.OWNERSHIP_FLOW", "INFO", "OWNERSHIP_TRANSFER_VIA_ALIAS_OBSERVED", -
          "The allocation leaves the function through a return of the same object or an exact alias; local leakage is not established.", symbol, "HIGH")
      f~addEvidence(allocation)
      do edge over flow~lineageEdges(returned)
        f~addEvidence(edge)
      end
      f~addEvidence(returnNode)
      return f
    end
  end

  do callFact over flow~calls
    if callFact~sourceSpan~startLine <= allocation~sourceSpan~startLine then iterate
    if flow~callReceivesAlias(callFact, objectName) then do
      f = .CodeAnalysisFinding~new("MEMORY.OWNERSHIP_FLOW", "INFO", "OWNERSHIP_ESCAPES_TO_CALL_UNRESOLVED", -
          "The allocated object or an exact alias is passed to another call. The bounded model cannot infer whether that call borrows, stores, releases, or takes ownership, so a leak verdict is withheld.", -
          symbol, "MEDIUM")
      f~addEvidence(allocation)
      f~addCounterEvidence(callFact)
      return f
    end
  end

  f = .CodeAnalysisFinding~new("MEMORY.OWNERSHIP_FLOW", "MEDIUM", "POSSIBLE_UNRELEASED_LOCAL_ALLOCATION", -
      "The bounded ownership-flow model sees a local allocation with no release, return transfer, or observed escape to another call. This remains a review finding rather than proof of a leak because macros, exceptional flow, globals, fields, and interprocedural ownership contracts are not yet fully modelled.", -
      symbol, "MEDIUM")
  f~addEvidence(allocation)
  return f

::requires "CodeEvidenceRules.cls"
::requires "CodeValueFlow.cls"
