from pathlib import Path
r=Path(__file__).resolve().parents[1]
b=(r/'rexx/WireBinding.cls').read_text()
# Builder needs to persist exactly these names; target is the resolved runtime behaviour object.
for field in ('id','source','trigger','target','method','enabled','metadata'):
    assert f'::attribute {field} get' in b
assert 'execution' not in b  # execution policy is intentionally deferred, not silently invented.
print('PASS builder binding shape: source + trigger -> behaviour method, no renderer leakage')
