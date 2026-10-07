import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
cp = subprocess.run(["rexx", str(ROOT/"rexx/numeric_context.rex")],
                    text=True, capture_output=True, check=False)
print(cp.stdout, end="")
if cp.stderr:
    print(cp.stderr, end="")
if cp.returncode:
    raise SystemExit(f"numeric context Rexx probe failed rc={cp.returncode}")

fields = {}
for line in cp.stdout.splitlines():
    if ":" in line:
        key, value = line.split(":", 1)
        fields[key.strip()] = value.strip()

assert fields["worker-A-context"] == "9:0:SCIENTIFIC"
assert fields["worker-A-one-third"] == "0.333333333"
assert fields["worker-B-context"] == "30:3:ENGINEERING"
assert fields["worker-B-one-third"] == "0.333333333333333333333333333333"
assert fields["main-context"] == "18:2:SCIENTIFIC"
assert fields["main-one-third"] == "0.333333333333333333"
assert "NUMERIC ACTIVITY CONTEXT POC PASS" in cp.stdout
print("PYTHON OBSERVED REXX NUMERIC CONTEXT POC PASS")
