import json, pathlib
r=pathlib.Path(__file__).resolve().parents[1]
meta=json.loads((r/'packs/wire-ui-runtime/00-sphere.json').read_text())
assert meta['id']=='wire-ui-runtime' and meta['version']=='0.3'
for n in ['ref.wire-ui-runtime.renderer-conformance.json','ref.wire-ui-runtime.web-readiness.json','ref.wire-ui-runtime.rasenfalcon-runtime-readiness.json','ops.wire-ui-runtime.missing-work.json']:
 p=r/'packs/wire-ui-runtime/articles'/n; assert p.is_file(), n
con=json.loads((r/'packs/wire-ui-runtime/articles/ref.wire-ui-runtime.renderer-conformance.json').read_text())
assert all(x in con['summary'] for x in ['Swing','Direct Linux'])
base=json.loads((r/'packs/wire-ui-runtime/articles/ref.wire-ui-runtime.current-baseline.json').read_text())
assert base['current_integration_evidence']['swing']['artifact']=='wire_ui_swing_v0.2-dev12.zip'
assert base['current_integration_evidence']['gtk_direct_linux']['artifact']=='wire_direct_linux_v0.1-dev41.zip'
rf=json.loads((r/'packs/wire-ui-runtime/articles/ref.wire-ui-runtime.rasenfalcon-runtime-readiness.json').read_text())
assert rf['state']=={'source_candidate':True,'review_stage':True,'installed':False,'running':False,'production_ready':False}
print('PASS wire-ui-runtime sphere v0.3 static')
