from pathlib import Path
p=Path(__file__).resolve().parents[1]
s=(p/'rexx/ServiceDescriptors.cls').read_text()
t=(p/'bin/servicectl.rex').read_text()
assert 'IP addresses belong in the transport route table' in s
assert 'operationalClass' in s and 'routePeer' in s and 'servicePoint' in s
assert 'OOREXX_SERVICE_REGISTRY' in s
assert 'IP addresses are deliberately rejected' in t
print('PASS service descriptor static contract')
