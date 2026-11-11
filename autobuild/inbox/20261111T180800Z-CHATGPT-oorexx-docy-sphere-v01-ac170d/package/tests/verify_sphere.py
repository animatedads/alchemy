"""Static Gopher sphere contract verification; does not claim runtime admission."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
pack = root / 'packs' / 'oorexx-docy'
count = 0

def verify(ok, message):
    global count
    if not ok:
        raise AssertionError(message)
    count += 1

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

sphere = read(pack / '00-sphere.json')
policy = read(pack / '01-access-policy.json')
manifest = read(root / 'integration.json')
articles = {p.stem: read(p) for p in (pack / 'articles').glob('*.json')}
verify(sphere['kind'] == 'sphere', 'sphere kind')
verify(sphere['id'] == 'oorexx-docy', 'sphere identifier')
verify(sphere['version'] == '0.1', 'sphere version')
verify(policy['kind'] == 'access-policy', 'access-policy kind')
verify(policy['id'] == sphere['access_policy'], 'policy reference')
verify(bool(policy.get('rules')), 'access policy rules')
verify(manifest['package']['kind'] == 'documentation', 'publication kind')
verify(manifest['publish']['tree']['path'] == 'spheres/oorexx_docy_gopher_sphere_v0.1', 'publication path')
verify(len(articles) >= 6, 'article coverage')
verify(set(sphere['start_here']) <= set(articles), 'start_here references')
for name,article in sorted(articles.items()):
    verify(article['kind'] == 'article', name + ' kind')
    verify(article['id'] == name, name + ' file/id parity')
    verify(article['sphere'] == sphere['id'], name + ' sphere identity')
    verify(article['version'] == sphere['version'], name + ' version identity')
    verify(bool(article.get('semantics')), name + ' semantic content')
    verify(set(article.get('related',[])) <= set(articles), name + ' related refs')
    verify(bool(article.get('provenance')), name + ' provenance')
    for ref in article['provenance']:
        p=ref.get('path','')
        verify(p.startswith(('packages/oorexx_docy/','spheres/oorexx_string_template_')) and '..' not in p, name + ' safe provenance')
print(f'DOCY sphere structure: {count} PASS, 0 FAIL')
