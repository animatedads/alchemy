/*
 * LegalEffectV014CounterfactualEvidenceAdapter.cls
 *
 * Evidence-only RYTA projection for Legal Effect v0.14 counterfactual analysis.
 *
 * Legal Effect deliberately labels counterfactual comparisons hypothetical and
 * non-authoritative.  This adapter preserves that analysis as deterministic,
 * inspectable evidence without creating EvidencePromotion objects, HardWorld
 * facts, or any authority namespace.  The native Legal object remains reachable
 * as provenance; deterministic identity is derived only from Legal Effect's
 * explicit canonical counterfactual contract and stable scalar fields.
 */

::class LegalEffectV014CounterfactualEvidence public
::attribute evidenceIdentity get
::attribute sourceCanonicalIdentity get
::attribute baseStatus get
::attribute counterfactualStatus get
::attribute hypothetical get
::attribute authoritative get
::attribute statusChanged get
::attribute legallyMaterial get
::attribute assumptionFactName get
::attribute assumptionState get
::attribute assumptionScope get
::attribute assumptionAuthority get
::attribute nativeObject get

::method init
  expose evidenceIdentity sourceCanonicalIdentity baseStatus counterfactualStatus hypothetical authoritative statusChanged legallyMaterial assumptionFactName assumptionState assumptionScope assumptionAuthority nativeObject canonical
  use strict arg sourceCanonicalIdentityArg, baseStatusArg, counterfactualStatusArg, statusChangedArg, legallyMaterialArg, assumptionFactNameArg, assumptionStateArg, assumptionScopeArg, assumptionAuthorityArg, nativeObjectArg
  sourceCanonicalIdentity = sourceCanonicalIdentityArg~string
  baseStatus = baseStatusArg~string~upper
  counterfactualStatus = counterfactualStatusArg~string~upper
  hypothetical = .true
  authoritative = .false
  statusChanged = statusChangedArg
  legallyMaterial = legallyMaterialArg
  assumptionFactName = assumptionFactNameArg~string~upper
  assumptionState = assumptionStateArg~string~upper
  assumptionScope = assumptionScopeArg~string~upper
  assumptionAuthority = assumptionAuthorityArg~string~upper
  nativeObject = nativeObjectArg

  canonical = 'RYTA_LEGAL_EFFECT_V014_COUNTERFACTUAL_EVIDENCE_V1' || '0a'x
  canonical = canonical || self~field('SOURCE_CANONICAL_ID', sourceCanonicalIdentity)
  canonical = canonical || self~field('BASE_STATUS', baseStatus)
  canonical = canonical || self~field('COUNTERFACTUAL_STATUS', counterfactualStatus)
  canonical = canonical || self~field('HYPOTHETICAL', 'TRUE')
  canonical = canonical || self~field('AUTHORITATIVE', 'FALSE')
  canonical = canonical || self~field('STATUS_CHANGED', self~booleanText(statusChanged))
  canonical = canonical || self~field('LEGALLY_MATERIAL', self~booleanText(legallyMaterial))
  canonical = canonical || self~field('ASSUMPTION_FACT', assumptionFactName)
  canonical = canonical || self~field('ASSUMPTION_STATE', assumptionState)
  canonical = canonical || self~field('ASSUMPTION_SCOPE', assumptionScope)
  canonical = canonical || self~field('ASSUMPTION_AUTHORITY', assumptionAuthority)
  evidenceIdentity = .AlgorithmDigest~sha256Text(canonical)

::method algorithmCanonicalText
  expose canonical
  return canonical

::method promotionEligible
  return .false

::method field private
  use strict arg name, value
  rendered = value~string
  return name || '=' || rendered~length || ':' || rendered || '0a'x

::method booleanText private
  use strict arg value
  if value == .true then return 'TRUE'
  if value == .false then return 'FALSE'
  raise syntax 93.900 additional('LEGAL_COUNTERFACTUAL_BOOLEAN_INVALID')


::class LegalEffectV014CounterfactualEvidenceAdapter subclass RYTAObject public

::method init
  self~init:super('LegalEffectV014CounterfactualEvidenceAdapter', 'COUNTERFACTUAL_EVIDENCE_ONLY')
  self~registerMethodContract('PROJECT', 'Project Legal Effect v0.14 hypothetical counterfactual analysis into deterministic non-authority evidence', .array~new, 'LegalEffectV014CounterfactualEvidence', .false, 'AUTO', 'CUSTOMER', 'SENSITIVE', 'NONE', 'NONE')
  self~registerMethodContract('PROMOTIONSFROM', 'Explicitly refuse promotion of Legal Effect counterfactual analysis', .array~new, 'NONE', .false, 'AUTO', 'CUSTOMER', 'SENSITIVE', 'NONE', 'NONE')
  return self

::method project
  use strict arg comparison
  if comparison == .nil then raise syntax 93.900 additional('LEGAL_COUNTERFACTUAL_REQUIRED')
  required = .array~of('HYPOTHETICAL', 'AUTHORITATIVE', 'CANONICALTEXT', 'BASESTATUS', 'COUNTERFACTUALSTATUS', 'STATUSCHANGED', 'LEGALLYMATERIAL', 'ASSUMPTION')
  do methodName over required
    if \comparison~hasMethod(methodName) then raise syntax 93.900 additional('LEGAL_COUNTERFACTUAL_SURFACE_INVALID:' || methodName)
  end
  if comparison~hypothetical \== .true then raise syntax 93.900 additional('LEGAL_COUNTERFACTUAL_HYPOTHETICAL_REQUIRED')
  if comparison~authoritative \== .false then raise syntax 93.900 additional('LEGAL_COUNTERFACTUAL_MUST_BE_NON_AUTHORITATIVE')

  assumption = comparison~assumption
  if assumption == .nil then raise syntax 93.900 additional('LEGAL_COUNTERFACTUAL_ASSUMPTION_REQUIRED')
  assumptionMethods = .array~of('FACTNAME', 'STATE', 'SCOPE', 'AUTHORITY', 'CANONICALTEXT')
  do methodName over assumptionMethods
    if \assumption~hasMethod(methodName) then raise syntax 93.900 additional('LEGAL_COUNTERFACTUAL_ASSUMPTION_SURFACE_INVALID:' || methodName)
  end
  if assumption~authority~string~upper \== 'COUNTERFACTUAL_ASSUMPTION' then raise syntax 93.900 additional('LEGAL_COUNTERFACTUAL_ASSUMPTION_AUTHORITY_INVALID')

  sourceCanonical = comparison~canonicalText
  sourceCanonicalIdentity = .AlgorithmDigest~sha256Text(sourceCanonical)
  return .LegalEffectV014CounterfactualEvidence~new(sourceCanonicalIdentity, comparison~baseStatus, comparison~counterfactualStatus, comparison~statusChanged, comparison~legallyMaterial, assumption~factName, assumption~state, assumption~scope, assumption~authority, comparison)

/* Counterfactuals are analysis artifacts by contract.  Keep a named refusal
 * surface so callers cannot mistake this adapter for the live Legal promotion
 * adapters merely because their names share a LegalEffect prefix. */
::method promotionsFrom
  use arg ignored
  raise syntax 93.900 additional('LEGAL_COUNTERFACTUAL_NOT_AUTHORITY')

::requires '../RYTAObject.cls'
::requires '../algorithm/AlgorithmIntegrity.cls'
