/*
 * LegalEffectV010PromotionAdapter.cls
 *
 * Native Legal Effect v0.10 authority projection for RYTA.
 *
 * Legal Effect v0.10 adds host-owned source-authority trust policy to live
 * acquisition.  The older v0.7 pinned evaluator is deliberately reused for
 * the certified legal semantic/execution/reducer closure because the known
 * REVIEW/REQUIRES_OBLIGATION reducer ambiguity still exists in v0.10.1 and
 * RYTA must continue to fail closed on it.
 *
 * A v0.10 promotion is emitted only when the live Legal Effect execution
 * envelope carries successful host source-authority verification evidence.
 * Runtime Registry identities remain provenance only.  The host verification
 * closure is bound separately into the v0.10 authority identity and basis.
 */

::class LegalEffectV010PromotionAdapter public

::method promotionsFrom class
  use arg sourceObject, prefix = 'LEGAL_', runtimeEnvelope = .nil
  if runtimeEnvelope == .nil then raise syntax 93.900 additional('LEGAL_EFFECT_V010_RUNTIME_ENVELOPE_REQUIRED')
  if \runtimeEnvelope~hasMethod('BINDINGEVIDENCE') then raise syntax 93.900 additional('LEGAL_EFFECT_V010_RUNTIME_BINDING_REQUIRED')
  binding = runtimeEnvelope~bindingEvidence
  if binding == .nil then raise syntax 93.900 additional('LEGAL_EFFECT_V010_RUNTIME_BINDING_REQUIRED')
  if \binding~hasMethod('SOURCEAUTHORITYEVIDENCE') then raise syntax 93.900 additional('LEGAL_EFFECT_V010_SOURCE_AUTHORITY_EVIDENCE_REQUIRED')

  authorityEvidence = binding~sourceAuthorityEvidence
  if authorityEvidence == .nil then raise syntax 93.900 additional('LEGAL_EFFECT_V010_SOURCE_AUTHORITY_EVIDENCE_REQUIRED')
  if authorityEvidence~items = 0 then raise syntax 93.900 additional('LEGAL_EFFECT_V010_SOURCE_AUTHORITY_EVIDENCE_REQUIRED')

  authorityTexts = .array~new
  authorityBasis = .array~new
  do item over authorityEvidence
    text = self~sourceAuthorityText(item)
    itemId = .AlgorithmDigest~sha256Text(text)
    authorityTexts~append(text)
    detail = 'source=' || item~sourceId || ';claim=' || item~claimId || ';policy=' || item~policyId || ';profile=' || item~trustProfileId || ';signers=' || self~signerList(item)
    authorityBasis~append(.EvidencePromotionBasis~new('LEGAL_SOURCE_AUTHORITY_VERIFICATION', itemId, detail, item))
  end
  authorityTexts~sort
  closureText = 'LEGAL_EFFECT_V010_HOST_SOURCE_AUTHORITY_V1' || '0a'x
  do text over authorityTexts
    closureText = closureText || self~field('VERIFICATION', text)
  end
  authorityClosureId = .AlgorithmDigest~sha256Text(closureText)
  authorityBasis~append(.EvidencePromotionBasis~new('LEGAL_SOURCE_AUTHORITY_V010', authorityClosureId, 'host source-authority verification closure', binding))

  /* This call preserves all v0.7+ compiler/verifier/runtime/reducer guards. */
  compatibilitySet = .LegalEffectV07PromotionAdapter~promotionsFrom(sourceObject, prefix, runtimeEnvelope)
  out = .EvidencePromotionSet~new
  do oldPromotion over compatibilitySet~promotions
    oldAuthority = oldPromotion~authority
    marker = 'LEGAL_EFFECT/0.7/'
    if oldAuthority~pos(marker) \= 1 then raise syntax 93.900 additional('LEGAL_EFFECT_V010_COMPATIBILITY_AUTHORITY_INVALID')
    authority = 'LEGAL_EFFECT/0.10/' || oldAuthority~substr(marker~length + 1) || '+sourceauth:' || authorityClosureId

    basis = oldPromotion~basis
    do authorityItem over authorityBasis
      basis~append(authorityItem)
    end
    reason = 'Legal Effect v0.10 compiler/verifier closure plus live host source-authority trust verification; reducer ambiguity guard retained'
    p = .EvidencePromotion~new(oldPromotion~promotionId, 'LEGAL_EFFECT_V010', oldPromotion~sourceIdentity, oldPromotion~targetFactName, oldPromotion~proposedKnowledgeState, oldPromotion~proposedValue, authority, 'LEGAL_EFFECT_V010_STATUS_PROJECTION_V1', oldPromotion~ruleId, oldPromotion~disposition, oldPromotion~promotionStatus, reason, oldPromotion~evidence, oldPromotion~sourceObject, oldPromotion~minimumConsistency, oldPromotion~actualConsistency, basis)
    ignored = out~add(p)
  end
  ignored = out~seal
  return out

::method sourceAuthorityText private class
  use arg item
  required = .array~of('SOURCEID', 'CLAIMID', 'POLICYID', 'TRUSTPROFILEID', 'VERIFIED', 'STATUSCODE', 'VERIFIEDSIGNERIDS')
  do name over required
    if \item~hasMethod(name) then raise syntax 93.900 additional('LEGAL_EFFECT_V010_SOURCE_AUTHORITY_SURFACE_INVALID:' || name)
  end
  if \item~verified then raise syntax 93.900 additional('LEGAL_EFFECT_V010_SOURCE_AUTHORITY_NOT_VERIFIED:' || item~sourceId)
  if item~statusCode \= 'VERIFIED' then raise syntax 93.900 additional('LEGAL_EFFECT_V010_SOURCE_AUTHORITY_STATUS_INVALID:' || item~statusCode)
  signers = item~verifiedSignerIds
  if signers~items = 0 then raise syntax 93.900 additional('LEGAL_EFFECT_V010_SOURCE_AUTHORITY_SIGNERS_REQUIRED:' || item~sourceId)
  signerTexts = .array~new
  do signerId over signers
    signerTexts~append(signerId~string)
  end
  signerTexts~sort
  text = 'LEGAL_SOURCE_AUTHORITY_VERIFICATION_V1' || '0a'x
  text = text || self~field('SOURCE_ID', item~sourceId)
  text = text || self~field('CLAIM_ID', item~claimId)
  text = text || self~field('POLICY_ID', item~policyId)
  text = text || self~field('TRUST_PROFILE_ID', item~trustProfileId)
  text = text || self~field('STATUS', item~statusCode)
  do signerId over signerTexts
    text = text || self~field('VERIFIED_SIGNER', signerId)
  end
  return text

::method signerList private class
  use arg item
  values = item~verifiedSignerIds
  values~sort
  out = ''
  do signerId over values
    if out \= '' then out = out || ','
    out = out || signerId
  end
  return out

::method field private class
  use arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x

::requires 'LegalEffectV07PromotionAdapter.cls'
