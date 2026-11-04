import json, pathlib
r=pathlib.Path(__file__).resolve().parents[1]
meta=json.loads((r/'packs/wire-ui-runtime/00-sphere.json').read_text())
assert meta['id']=='wire-ui-runtime' and meta['version']=='0.4'
for n in ['ref.wire-ui-runtime.renderer-conformance.json','ref.wire-ui-runtime.web-readiness.json','ref.wire-ui-runtime.rasenfalcon-runtime-readiness.json','ops.wire-ui-runtime.missing-work.json']:
 p=r/'packs/wire-ui-runtime/articles'/n; assert p.is_file(), n
base=json.loads((r/'packs/wire-ui-runtime/articles/ref.wire-ui-runtime.current-baseline.json').read_text())
assert base['current_integration_evidence']['swing']['artifact']=='wire_ui_swing_v0.2-dev12.zip'
assert base['current_integration_evidence']['gtk_direct_linux']['artifact']=='wire_direct_linux_v0.1-dev41.zip'
assert base['current_integration_evidence']['gtk_direct_linux']['git_source_sync']['file_count']==134
rf=json.loads((r/'packs/wire-ui-runtime/articles/ref.wire-ui-runtime.rasenfalcon-runtime-readiness.json').read_text())
assert rf['public_apex']['source_on_main'] is True
assert rf['public_apex']['ldap_required'] is False
assert rf['private_noc_office']['ldap_merged'] is False
assert rf['private_noc_office']['fallback_identity_store_forbidden'] is True
assert rf['public_apex']['production_ready'] is False and rf['private_noc_office']['production_ready'] is False
print('PASS wire-ui-runtime sphere v0.4 static')
