#!/usr/bin/env python3
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
s=(root/'mvs/asm/MASLIVE.asm').read_text()
errors=[]
if "HEADTPL  DC    X'414C4348',X'0100'" not in s:
    errors.append("request header eye is not explicit ASCII 414C4348")
if "CLC   RESPBUF(4),=X'414C4348'" not in s:
    errors.append("response header eye comparison is not explicit ASCII 414C4348")
if "C'ALCH'" in s or "=C'ALCH'" in s:
    errors.append("EBCDIC-dependent ALCH character constant remains")
for token in ["HELLOP", "PINGP", "QOPENP", "DBOPENP", "MLISTP", "SFROMP", "POPNWP"]:
    if token not in s:
        errors.append(f"missing expected wire payload {token}")
if errors:
    print("FAIL MVS_WIRE_BYTES")
    for e in errors: print(" -",e)
    sys.exit(1)
print("PASS MVS_WIRE_BYTES")
