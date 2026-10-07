import subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
cp = subprocess.run(["rexx", str(ROOT/"rexx/argument_semantics.rex")],
                    text=True, capture_output=True, check=False)
print(cp.stdout, end="")
if cp.stderr: print(cp.stderr, end="")
if cp.returncode: raise SystemExit(cp.returncode)
lines = cp.stdout.splitlines()
for wanted in ("arg-case:OMITTED", "arg-case:NIL", "arg-case:EMPTY", "arg-case:VALUE:value"):
    assert wanted in lines, (wanted, lines)
print("OMITTED != NIL != EMPTY BASELINE PASS")
