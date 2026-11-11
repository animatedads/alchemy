#!/usr/bin/env python3
import json, pathlib, sys, hashlib, tempfile, subprocess
root=pathlib.Path(__file__).resolve().parents[1]
plan=json.loads((root/"edits.json").read_text())
assert plan["schema"]=="alchemy.source-edit-plan/0.1"
assert len(plan["edits"])==15
assert plan["base_git_blob_sha"]=="29a3ed15ea49ae062a3ae51052f7f3f1eb1fa2c0"
for n,e in enumerate(plan["edits"]):
    assert e["before"] and e["after"] and e["before"] != e["after"], n
assert any("semanticCollectionRange(\"documents\"" in e["after"] for e in plan["edits"])
assert any("listSource = \"query\"" in e["after"] for e in plan["edits"])
assert any("listSource = \"view\"" in e["after"] for e in plan["edits"])
assert any("PAGE NEXT" in e["after"] for e in plan["edits"])
# Negative control: the patcher must refuse an invalid source hash and never edit in place.
with tempfile.TemporaryDirectory() as d:
    inputFile=pathlib.Path(d)/"old.cls"
    outputFile=pathlib.Path(d)/"candidate.cls"
    inputFile.write_text("::class Placeholder\n")
    cp=subprocess.run([sys.executable,str(root/"scripts/apply.py"),"--source",str(inputFile),"--output",str(outputFile)],capture_output=True,text=True)
    assert cp.returncode!=0 and "SOURCE_BLOB_MISMATCH" in cp.stderr+cp.stdout
    assert not outputFile.exists()
print("EDIT_PLAN_CONTRACT_PASS edits=15 fail_closed=yes")
