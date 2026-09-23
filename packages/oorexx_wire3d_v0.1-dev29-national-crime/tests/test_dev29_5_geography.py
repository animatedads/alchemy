import json, pathlib, re
root=pathlib.Path(__file__).resolve().parents[1]
js=(root/'web/national-crime.js').read_text()
html=(root/'web/national-crime.html').read_text()
bua=json.load(open(root/'web/bua-2024.geojson'))
assert len(bua['features'])==7775
assert all(f['properties']['geographyType']=='BUA2024' for f in bua['features'])
assert 'view.panY=-(cy-fullCy)*base*view.zoom' in js
assert 'fetch("./stop-search.json")' in js
assert 'fetch("./bua-2024.geojson")' in js
assert 'id="geoClear"' in html and 'id="crimeClear"' in html and 'id="buaToggle"' in html
# algebraic regression: framing feature centre must land at viewport centre.
W,H=1280,720; b=(-6.5,49.8,2.0,55.9); z=10
base=min((W-76)/(b[2]-b[0]),(H-76)/(b[3]-b[1]))
for cx,cy in [(0.12,51.55),(-2.24,53.48),(-1.55,53.8)]:
    fullx=(b[0]+b[2])/2; fully=(b[1]+b[3])/2
    panx=-(cx-fullx)*base*z; pany=-(cy-fully)*base*z
    worldw=(b[2]-b[0])*base*z; worldh=(b[3]-b[1])*base*z
    ox=(W-worldw)/2+panx; oy=(H-worldh)/2+pany
    x=ox+(cx-b[0])*base*z
    y=H-(oy+(cy-b[1])*base*z)
    assert abs(x-W/2)<1e-8 and abs(y-H/2)<1e-8
print('PASS dev29.5 geography/search/frame regression')
