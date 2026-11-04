from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
html = (ROOT / "web" / "index.html").read_text()
boot = (ROOT / "web" / "bootstrap.mjs").read_text()
desc = json.loads((ROOT / "web" / "service-descriptor.example.json").read_text())
adapter = (ROOT / "src" / "SemanticSourceWireActionAdapter.cls").read_text()

assert 'data-role="class-inspection-view"' in html
assert 'data-default-view="true"' in html
assert 'data-wire-slot="class_tree"' in html
assert 'data-wire-slot="class_method_summary"' in html
assert '<summary>Exact source / method bodies</summary>' in html
assert "mount.innerHTML = ''" not in boot
assert "principalSource !== 'verified-session'" in boot
assert "auth.session !== 'opaque-bearer'" in boot
assert desc["authenticationRequired"] is True
assert desc["authentication"]["principalSource"] == "verified-session"
assert desc["authentication"]["session"] == "opaque-bearer"
for action in ["WORK.ACCEPT", "WORK.REFUSE", "BRANCH.CLASSIFY", "BRANCH.PROTECT", "BRANCH.CONFLICT.RESOLVE"]:
    assert action in desc["authentication"]["privilegedStepUp"]
assert 'requiredField(securityContext, "access_token")' in adapter
assert 'requiredField(actionEnvelope, "action")' in adapter
assert 'self~secureExaminer~handleAction(token, actionName, detail, nowValue, stepUp)' in adapter
assert 'browser-selected identity' in adapter
for f in ["stage_code_examiner.sh", "generate_service_descriptor.sh", "smoke_code_examiner.sh"]:
    assert (ROOT / "deploy" / f).exists()
print("EXAMINER DEPLOYMENT CONTRACT TEST: PASS")
