/*
 * Evidence Revision Audit v0.1.
 * Architecture: Tom Dyer. Coding: ChatGPT GPT-6.
 * v0.3: proposition identity, binding policy and ground-note change detection.
 * Pure ooRexx, adjunct to EvidenceCombiner's policy-relative decisions.
 *
 * AUDIT BOUNDARY: A new result derived from newly declared grounds is NOT proof of
 * reality. Source authentication and warrant admission are external obligations.
 * beforeP and afterP are distinct immutable-in-use snapshots of the claim.
 * This class neither modifies the network nor infers history from model prose.
 */
::class EvidenceRevisionAudit public
::method compare
  use strict arg beforeP, afterP, claimedStance = ""
  beforeResult = .EvidenceCombiner~new~evaluate(beforeP)
  afterResult = .EvidenceCombiner~new~evaluate(afterP)
  beforeIds = .directory~new
  afterIds = .directory~new
  do g over beforeP~grounds; beforeIds[g~id] = g; end
  do g over afterP~grounds; afterIds[g~id] = g; end
  added = .array~new; removed = .array~new; modified = .array~new
  do id over afterIds~allIndexes
    if \beforeIds~hasIndex(id) then added~append(id)
    else if self~signature(beforeIds[id]) \== self~signature(afterIds[id]) then modified~append(id)
  end
  do id over beforeIds~allIndexes
    if \afterIds~hasIndex(id) then removed~append(id)
  end
  added~sort; removed~sort; modified~sort
  /* The same identifier cannot silently stand for a different proposition.
   * Where the source object lacks ~statement, expose unverified identity. */
  identityVerified = beforeP~hasMethod("STATEMENT") & afterP~hasMethod("STATEMENT")
  statementChanged = .false
  if identityVerified then -
    statementChanged = (beforeP~statement \== afterP~statement)

  /* Scope admission is policy, not new factual evidence. Only inspect binding
   * scopes appearing in the two ground inventories; the current Proposition
   * interface cannot enumerate its entire accepted-binding policy. */
  observedScopes = .directory~new
  do g over beforeP~grounds; observedScopes[g~binds] = 1; end
  do g over afterP~grounds; observedScopes[g~binds] = 1; end
  changedBindings = .array~new
  do b over observedScopes~allIndexes
    if beforeP~acceptsBinding(b) \= afterP~acceptsBinding(b) then -
      changedBindings~append(b)
  end
  changedBindings~sort
  changesPolicy = (beforeP~assertFloorRank \= afterP~assertFloorRank) | -
                  (beforeP~settleFloorRank \= afterP~settleFloorRank) | -
                  (changedBindings~items > 0)
  changed = (beforeResult["stance"] \= afterResult["stance"]) | -
            (beforeResult["status"] \= afterResult["status"]) | -
            (beforeResult["assertible"] \= afterResult["assertible"]) | -
            (beforeResult["settled"] \= afterResult["settled"])
  claimedMismatch = .false
  if claimedStance \= "" then claimedMismatch = (claimedStance \= afterResult["stance"])
  select
    when beforeP~id \= afterP~id | statementChanged then code = "INVALID_COMPARISON"
    when beforeResult["status"] = "INVALID" | afterResult["status"] = "INVALID" then code = "INVALID_EVIDENCE"
    when modified~items > 0 then code = "MUTATED_GROUND_ID"
    when removed~items > 0 then code = "UNVERIFIED_REMOVAL"
    when changesPolicy then code = "POLICY_CHANGE_REQUIRES_REVIEW"
    when claimedMismatch then code = "CLAIMED_FLIP_UNSUPPORTED"
    when \changed then code = "NO_REVISION"
    when added~items > 0 then code = "ADMITTED_DELTA_BACKED"
    otherwise code = "UNEXPLAINED_REVISION"
  end
  r = .directory~new
  r["classification"] = code
  r["changed"] = changed
  r["before"] = beforeResult; r["after"] = afterResult
  r["added"] = added; r["removed"] = removed; r["modified"] = modified
  r["claimedMatchesDerived"] = \claimedMismatch
  r["policyChanged"] = changesPolicy
  r["changedBindings"] = changedBindings
  r["bindingPolicyCoverage"] = "OBSERVED_GROUND_SCOPES_ONLY"
  r["identityVerified"] = identityVerified
  r["statementChanged"] = statementChanged
  r["validatedTruth"] = .false
  r["validationBoundary"] = "Evidence admission, actual measurement, speaker and warrant validation not performed"
  return r

::method signature private
  use strict arg g
  /* exact, length-prefixed field boundaries avoid delimiter ambiguity */
  notePresent = 0
  noteText = ""
  if g~hasMethod("NOTE") then do
    notePresent = 1
    noteText = g~note
  end
  a = .array~of(g~kind, g~tier, g~sourceUtterance, g~targetId, -
                g~undercutsGroundId, g~binds, notePresent, noteText)
  sig = ""
  do val over a
    v = val~string
    sig = sig || length(v) || ":" || v
  end
  return sig
::requires "EvidenceCombiner.cls"
