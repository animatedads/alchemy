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

out = cp.stdout
assert "worker-A-context: 9:0:SCIENTIFIC" in out
assert "worker-A-one-third:0.333333333" in out
assert "worker-B-context: 30:3:ENGINEERING" in out
assert "main-context: 18:2:SCIENTIFIC" in out
assert "main-one-third:0.333333333333333333" in out
assert "NUMERIC ACTIVITY CONTEXT POC PASS" in out
print("PYTHON OBSERVED REXX NUMERIC CONTEXT POC PASS")
