import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=json.loads((root/'web/scene.json').read_text())
assert s['title']=='SANDFORD / INVESTIGATION SPACE'
assert s['trackingField']['enabled'] is True
assert s['mapContext']['provider']=='OPENSTREETMAP'
p=[n for n in s['nodes'] if n.get('representation',{}).get('kind')=='person']
assert len(p)==7
assert len(s['edges'])==7
for n in p:
 c=n['metadata']['card']; assert c['kind']=='person'; assert c['headshot'].startswith('assets/people/'); assert c['details']['Identity']=='UNASSIGNED'; assert c['media']
print('PASS CrimeEnterprise spatial fixture: 7 people, cards, media, relationships, map context, tracking field')
