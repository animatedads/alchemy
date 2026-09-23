from pathlib import Path
r=Path(__file__).resolve().parents[1]
server=(r/'server/wire3d_http_server.rex').read_text()
scene=(r/'examples/crime_enterprise_space.rex').read_text()
js=(r/'web/wire3d.js').read_text()
pres=(r/'src/Wire3DPresentation.cls').read_text()
assert "/resource/person/CE-" in server and "OPEN READ" in server
assert "p~photographReference='/resource/person/CE-'" in scene
assert "embedUrl" in scene and "OpenStreetMap contributors" in scene
assert "Wire3DMapElement" in pres
assert "mapElement" in js and "ENTER MAP" in js
print('DEV26_STATIC_PASS')
