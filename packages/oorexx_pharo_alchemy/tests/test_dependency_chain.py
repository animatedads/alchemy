from pathlib import Path
import json
r=Path(__file__).resolve().parents[1]
d=json.loads((r/'metadata/dependency_chain.json').read_text())
assert d['Alchemy Objects'].startswith('v0.8')
assert d['Crypto'].startswith('v0.8.3')
assert d['Foreign Runtime'].startswith('v0.22.6')
print('PHARO ALCHEMY dependency contract PASS')
