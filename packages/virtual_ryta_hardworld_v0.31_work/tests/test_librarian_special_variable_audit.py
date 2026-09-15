#!/usr/bin/env python3
"""Narrow salvage audit for Rexx special-variable and Relation-API hazards."""
from pathlib import Path
import re, sys
root=Path(__file__).resolve().parents[1]
core=(root/'librarian/LibrarianCore.cls').read_text()

fail=[]
# Persistent RESULT/result assignment is forbidden. msg~result is a method call, not a variable assignment.
for i,line in enumerate(core.splitlines(),1):
    if re.search(r'(?i)(^|\s)result\s*=', line):
        fail.append(f'{i}: ordinary RESULT/result assignment: {line.strip()}')
    if re.search(r'(?i)(^|\s)sigl\s*=', line):
        fail.append(f'{i}: ordinary SIGL assignment: {line.strip()}')
    # allItems with any argument is the native Relation API scar already repaired in v0.9.
    if re.search(r'~allItems\s*\([^)]', line):
        fail.append(f'{i}: keyed allItems call remains: {line.strip()}')

# RC is a real Rexx special. The salvaged core still has a small service/queue set of
# immediate status locals. Freeze that set: any new ordinary RC assignment is review-required.
rc_assignments=[]
for i,line in enumerate(core.splitlines(),1):
    if re.search(r'(?i)^\s*rc\s*=', line):
        rc_assignments.append(line.strip())
expected={
    'rc = self~handleMessage(message)',
    'rc = self~processMessageFile(filePath)',
    'rc = service~handleMessage(message)',
}
if set(rc_assignments) != expected:
    fail.append('RC assignment surface changed: ' + repr(rc_assignments))

if fail:
    print('LIBRARIAN SPECIAL VARIABLE AUDIT: FAILED')
    for item in fail: print('  '+item)
    sys.exit(1)
print('LIBRARIAN SPECIAL VARIABLE AUDIT: OK')
print('  reviewed RC service/queue assignment forms:', len(rc_assignments))
