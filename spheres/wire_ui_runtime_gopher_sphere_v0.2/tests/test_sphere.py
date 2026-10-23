import json, pathlib
r=pathlib.Path(__file__).resolve().parents[1]
meta=json.loads((r/'packs/wire-ui-runtime/00-sphere.json').read_text())
assert meta['id']=='wire-ui-runtime' and meta['version']=='0.2'
for n in ['ref.wire-ui-runtime.renderer-conformance.json','ref.wire-ui-runtime.web-readiness.json','ops.wire-ui-runtime.missing-work.json']:
 p=r/'packs/wire-ui-runtime/articles'/n; assert p.is_file(), n
con=json.loads((r/'packs/wire-ui-runtime/articles/ref.wire-ui-runtime.renderer-conformance.json').read_text())
assert all(x in con['summary'] for x in ['Web','Swing','GTK','Android'])
base=json.loads((r/'packs/wire-ui-runtime/articles/ref.wire-ui-runtime.current-baseline.json').read_text())
assert base['current_integration_evidence']['swing']['artifact']=='wire_ui_swing_v0.2-dev11.zip'
assert base['current_integration_evidence']['gtk_direct_linux']['artifact']=='wire_direct_linux_v0.1-dev38.zip'
print('PASS wire-ui-runtime sphere v0.2 static')
deploy=json.loads((r/'packs/wire-ui-runtime/articles/ref.wire-ui-runtime.hosted-application-deployment.json').read_text())
assert deploy['sphere']=='wire-ui-runtime'
assert any('Queue Fabric' in s for s in deploy['invariants'])
print('PASS wire-ui-runtime hosted application deployment article')
