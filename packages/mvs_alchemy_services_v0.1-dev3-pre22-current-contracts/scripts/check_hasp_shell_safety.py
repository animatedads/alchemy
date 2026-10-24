#!/usr/bin/env python3
from pathlib import Path
import re
import sys

path = Path(__file__).with_name('qualify_ed209c_ed209z_services.sh')
text = path.read_text()
errors = []
for n, line in enumerate(text.splitlines(), 1):
    stripped = line.lstrip()
    if stripped.startswith('#'):
        continue
    for m in re.finditer(r'"(?:[^"\\]|\\.)*\$HASP\d+(?:[^"\\]|\\.)*"', line):
        errors.append((n, line))
    if 'HASP' in line and 'wait_remote_log' in line:
        if not re.search(r"'\\\$HASP\d+", line):
            errors.append((n, line))

if errors:
    for n, line in errors:
        print(f'FAIL line {n}: {line}')
    sys.exit(1)
print('PASS HASP_SHELL_SAFETY')
