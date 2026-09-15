/*
 * DatabaseTransactionPromotionBasisAdapter.cls
 *
 * Allows detached DatabaseTransactionEvidence to be cited as auditable basis
 * of a separately-authorized EvidencePromotion without allowing database
 * provenance itself to mint authority.
 */
::class DatabaseTransactionPromotionBasisAdapter subclass RYTAObject public

::method init
  self~init:super('DatabaseTransactionPromotionBasisAdapter', 'DATABASE_PROMOTION_BASIS_ONLY')
  self~registerMethodContract('BASISFROM', 'Cite database transaction evidence as non-authority promotion basis', .array~new, 'EvidencePromotionBasis', .false, 'AUTO', 'CUSTOMER', 'SENSITIVE', 'NONE', 'NONE')
  self~registerMethodContract('PROMOTIONSFROM', 'Explicitly refuse direct promotion from database transaction evidence', .array~new, 'NONE', .false, 'AUTO', 'CUSTOMER', 'SENSITIVE', 'NONE', 'NONE')
  return self

::method basisFrom
  use strict arg evidence, extraDetail = ''
  if evidence == .nil then raise syntax 93.900 additional('DATABASE_TRANSACTION_EVIDENCE_REQUIRED')
  if \evidence~isA(.DatabaseTransactionEvidence) then raise syntax 93.900 additional('DATABASE_TRANSACTION_EVIDENCE_TYPE_REQUIRED')
  if evidence~promotionEligible \== .false then raise syntax 93.900 additional('DATABASE_TRANSACTION_EVIDENCE_MUST_BE_NON_AUTHORITY')
  detail = 'transaction=' || evidence~transactionId || ';attempts=' || evidence~attemptCount
  if extraDetail~string \= '' then detail = detail || ';detail=' || extraDetail~string
  return .EvidencePromotionBasis~new('DATABASE_TRANSACTION_EVIDENCE', evidence~evidenceIdentity, detail, evidence)

::method promotionsFrom
  use arg ignored
  raise syntax 93.900 additional('DATABASE_TRANSACTION_EVIDENCE_NOT_AUTHORITY')

::requires 'DatabaseTransactionEvidenceAdapter.cls'
::requires '../algorithm/EvidencePromotion.cls'
