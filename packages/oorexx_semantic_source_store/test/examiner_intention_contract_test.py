from pathlib import Path
root=Path(__file__).resolve().parents[1]
exam=(root/'src/SemanticSourceCodeExaminer.cls').read_text()
intent=(root/'src/SemanticSourceIntentionService.cls').read_text()
wire=(root/'src/SemanticSourceWireActionAdapter.cls').read_text()
html=(root/'web/index.html').read_text()
actions=[]
for line in exam.splitlines():
    line=line.strip()
    if line.startswith('::constant ACTION_'):
        actions.append(line.split()[-1].strip('"'))
assert len(actions)==28, len(actions)
for action in actions:
    assert action in exam
assert 'registerDiscoveryProvider' in intent
assert 'discoverExaminerActions' in intent
assert 'IntentionDiscoverySnapshot' in intent
assert 'IntentionSurfaceAdvertisement' in intent
assert 'INTENTION.SUBMIT' in wire
assert 'data-semantic-action="INTENTION.SUBMIT"' in html
assert 'dynamic Intention Service discovery' in html
print('EXAMINER INTENTION CONTRACT TEST: PASS')
