from pathlib import Path

root = Path(__file__).resolve().parents[1]
html = (root / "web" / "index.html").read_text(encoding="utf-8")

required_actions = [
    "CODE.COMPARE",
    "METHOD.REQUIREMENT.CREATE",
    "METHOD.NOTE.CREATE",
    "RESOURCE.UPLOAD",
    "CODE.PACKAGE.REQUEST",
    "CODE.TEST.REQUEST",
    "WORK.ACCEPT",
    "WORK.REFUSE",
    "MODULE.REQUIREMENT.CREATE",
    "DEPLOYMENT.PACKAGE.REQUEST",
    "BRANCH.CLASSIFY",
    "BRANCH.PROTECT",
    "BRANCH.CONFLICT.RESOLVE",
    "BRANCH.PACKAGE.REQUEST",
    "CODE.GOTO_DEFINITION",
    "CODE.FIND_USES",
    "CODE.CALLERS",
    "CODE.CALLEES",
    "CODE.REFERENCE.EXPLAIN",
    "CODE.CLASS.SURFACE",
    "CODE.CLASS.OVERRIDES",
    "INTENTION.SUBMIT",
]
required_slots = [
    "catalog", "source", "design", "requirements", "notes", "resources",
    "findings", "runtime_surfaces", "references", "dependencies", "exports",
    "test_evidence", "deployments", "branches", "work_entries",
    "intention_status", "intention_choices",
]

for action in required_actions:
    token = f'data-semantic-action="{action}"'
    assert token in html, f"missing rendered Examiner action: {action}"

for slot in required_slots:
    token = f'data-wire-slot="{slot}"'
    assert token in html, f"missing rendered Examiner semantic slot: {slot}"

# Inventory must still be authority-driven: no checked-in source filename menu.
for suffix in (".rex</option>", ".cls</option>", ".java</option>", ".cpp</option>", ".rs</option>", ".py</option>"):
    assert suffix not in html, f"manual source inventory leaked into Examiner HTML: {suffix}"

print("EXAMINER RENDERED UI TEST: PASS")
