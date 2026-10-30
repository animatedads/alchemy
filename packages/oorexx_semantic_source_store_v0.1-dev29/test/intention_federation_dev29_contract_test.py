from pathlib import Path
r=Path(__file__).resolve().parents[1]
f=(r/'src'/'SemanticSourceIntentionFederation.cls').read_text()
c=(r/'src'/'SemanticSourceIntentionController.cls').read_text()
h=(r/'web'/'index.html').read_text()
assert 'ManagementIntentionDirectory' in f
assert 'resolveSpecialists' in f
assert 'response["specialists"]' in c
assert 'SPECIALIST_AVAILABLE' in c
assert 'intention_specialists' in h
print('SSC DEV29 INTENTION FEDERATION CONTRACT: PASS')
