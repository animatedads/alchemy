from pathlib import Path
r=Path(__file__).resolve().parents[1]
s=(r/'server/wire3d_http_server.rex').read_text()
run=(r/'run-phone-demo.sh').read_text()
js=(r/'web/wire3d.js').read_text()
scene=(r/'web/scene.json').read_text()
assert "config~transportMode='HTTP'" in s
assert 'python -m http.server' not in run
assert "wire3d_http_server.rex" in run
assert '"trackingField"' in scene and '"enabled":true' in scene
assert '_trackingLines' in js and 'gl.drawArrays(gl.LINES' in js and 'gl.drawArrays(gl.POINTS' in js
assert 'FIELD ${this.scene?.trackingField?.enabled' in js
print('PASS Rexx HTTP mode + visible tracking field static contract')
