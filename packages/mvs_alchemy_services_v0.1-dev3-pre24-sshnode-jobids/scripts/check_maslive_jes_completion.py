#!/usr/bin/env python3
from pathlib import Path
import sys
p=Path(__file__).with_name("qualify_ed209c_ed209z_services.sh")
s=p.read_text()
checks={
 "explicit JES end stage":"STAGE=MASLIVE_JES_END" in s,
 "HASP395 required after pass":"MASLIVE PASS ALL observed but JES2 did not reach HASP395" in s,
 "final spool capture":"capture_printers maslive-final" in s,
 "final spool required":"retained MASLIVE spool was not found" in s,
 "final live pass is pre23":"PASS ED209C_ED209Z_MAS_PRE24_LIVE" in s,
}
bad=[k for k,v in checks.items() if not v]
if bad:
 print("FAIL MASLIVE_JES_COMPLETION", ", ".join(bad)); sys.exit(1)
# Ordering is part of the contract: facility marker -> HASP395 gate -> evidence -> PASS.
pos=[s.index("if [[ $facility -ne 1 ]]") , s.index("STAGE=MASLIVE_JES_END"), s.index("STAGE=FACILITY_EVIDENCE"), s.index("PASS ED209C_ED209Z_MAS_PRE24_LIVE")]
if pos != sorted(pos):
 print("FAIL MASLIVE_JES_COMPLETION ordering"); sys.exit(1)
print("PASS MASLIVE_JES_COMPLETION PRE24")
