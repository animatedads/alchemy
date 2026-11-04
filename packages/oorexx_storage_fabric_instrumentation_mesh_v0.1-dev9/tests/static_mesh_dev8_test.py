import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
pkg=json.loads((root/'OOREXX_PACKAGE.json').read_text())
deps={d['name']:d for d in pkg['dependencies']}
mesh=deps['oorexx-instrumentation-mesh']
assert mesh['version']=='0.1-dev8', mesh
assert mesh['sha256']=='47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624', mesh
text=(root/'README.md').read_text()+(root/'INTEGRATION.md').read_text()
for needle in ['producer-supplied correlation','must not infer correlation','timestamps, hosts, or payload content']:
    assert needle in text, needle
print('PASS Instrumentation Mesh dev8 pin and explicit-correlation boundary')
