import json, pathlib
root=pathlib.Path(__file__).resolve().parents[1]
for rel in ('scene.json','web/scene.json','examples/scene.json'):
    d=json.loads((root/rel).read_text())
    f=d.get('trackingField')
    assert f and f.get('enabled') is True, rel
    assert f.get('version')=='wire3d-tracking/1', rel
    assert f.get('seed')=='4A91C37D', rel
    assert f.get('applicationState') is False, rel
print('PASS shipped static scenes contain deterministic tracking field')
