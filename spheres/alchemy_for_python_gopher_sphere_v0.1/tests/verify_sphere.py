from pathlib import Path
import json
root=Path(__file__).resolve().parent.parent
j=json.loads((root/'integration.json').read_text())
assert j['schema']=='alchemy.autobuild.integration/0.2'
assert j['package']['name']=='alchemy_for_python_gopher_sphere'
s=(root/'ALCHEMY_FOR_PYTHON_SPHERE.md').read_text()
for phrase in ('ConnectSelector','Serialization Selector','LDAP Identity','private-CA','NOT_RUN','Macrospace','Autobuilder'):
    assert phrase.lower() in s.lower(), phrase
print('PASS PYTHON SPHERE STRUCTURE')
