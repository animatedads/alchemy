from pathlib import Path

root = Path(__file__).resolve().parents[1]
auth = (root / 'src/SemanticSourceAuthenticator.cls').read_text()
secure = (root / 'src/SemanticSourceSecureExaminer.cls').read_text()
store = (root / 'src/SemanticSourceStore.cls').read_text()
desc = (root / 'web/service-descriptor.example.json').read_text()

for token in [
    'access_token_hash VARCHAR',
    '::method createSession',
    '::method resolveSession',
    '::method revokeSession',
    '::method authorizeBearerAction',
    'hashOpaqueToken(accessToken)',
]:
    assert token in (store + auth), token

for action in [
    'WORK.ACCEPT', 'WORK.REFUSE', 'BRANCH.CLASSIFY',
    'BRANCH.PROTECT', 'BRANCH.CONFLICT.RESOLVE'
]:
    assert action in secure, action

assert 'examiner~handleAction(actionName, payload, principalId)' in secure
assert 'authenticationRequired' in desc
assert 'verified-session' in desc
print('EXAMINER SECURITY CONTRACT TEST: PASS')
