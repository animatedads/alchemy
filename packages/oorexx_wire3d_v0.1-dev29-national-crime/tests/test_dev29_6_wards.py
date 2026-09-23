import json, pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
d=json.loads((ROOT/'web/wards-historic.geojson').read_text())
assert len(d['features'])==9348
assert d['metadata']['qualificationOnly'] is True
assert d['metadata']['currentAuthority'] is False
c={f['properties']['country'] for f in d['features']}
assert c=={'ENGLAND','WALES','SCOTLAND','NORTHERN IRELAND'}
assert any(f['properties'].get('alternateNameCy') for f in d['features'] if f['properties']['country']=='WALES')
js=(ROOT/'web/national-crime.js').read_text(); html=(ROOT/'web/national-crime.html').read_text(); srv=(ROOT/'server/wire3d_http_server.rex').read_text()
for x in ['wardFc','drawWards','selectWard','wards-historic.geojson','wardToggle']: assert x in js
assert 'WARDS' in html and 'historic qualification geography' in html
assert '/wards-historic.geojson' in srv and '::method wardGeojson' in srv
print('DEV29_6_WARD_GEOGRAPHY_PASS',len(d['features']))
