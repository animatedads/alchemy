#!/usr/bin/env python3
import os
from pathlib import Path

root = Path(__file__).resolve().parents[1]
legal_root = Path(os.environ.get('LEGAL_EFFECT_ROOT', ''))
if not legal_root:
    raise SystemExit('LEGAL_EFFECT_ROOT is required')
source = legal_root / 'src' / 'LegalEffect.cls'
if not source.is_file():
    raise SystemExit(f'missing {source}')
text = source.read_text(encoding='utf-8')
required = [
    '::class LegalSourceIdentity public',
    '::class NormativeSource public',
    '::class LegalProvisionReference public',
    '::class LegalProvision public',
    '::class LegalCompileProposal public',
    '::class LegalCompilationUnit public',
    '::class LegalRuleCompiler subclass LegalAlchemyObject public',
    '::class LegalVerificationMaterial public',
    '::class LegalSourceVerifier subclass LegalAlchemyObject public',
    '::class LegalPredicate public',
    '::class LegalNorm public',
    '::method verifyProvision',
    '::method provisionReference',
    'PROVISION_EXPRESSION_MISMATCH',
    'PROPOSAL_PREATTACHED_EVIDENCE_REJECTED',
    'SOURCE_VERIFICATION_EVIDENCE_MISSING',
    'LegalRuleCompiler may certify a generation',
]
missing = [item for item in required if item not in text]
if missing:
    raise SystemExit('Legal Effect v0.14 contract drift: missing ' + ', '.join(missing))
adapter = (root / 'src' / 'LegalInterrogationLegalEffectV014.cls').read_text(encoding='utf-8')
for required_adapter in [
    'sourceIdentity~cryptographicallyVerified',
    'expressionId = sourceIdentity~expressionId',
    'CONDITION_NOT_LEGAL_PREDICATE',
    'EXCEPTION_NOT_LEGAL_PREDICATE',
    '.LegalCompilationUnit~new',
    '.LegalCompileProposal~new',
    '.LegalRuleCompiler~new',
]:
    if required_adapter not in adapter:
        raise SystemExit('adapter contract missing: ' + required_adapter)
print('PASS Legal Interrogation dev6 static contract against Legal Effect v0.14')
