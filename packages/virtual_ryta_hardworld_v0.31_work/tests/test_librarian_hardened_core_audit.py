#!/usr/bin/env python3
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parents[1]
salvage = root / 'librarian/LibrarianSalvagedCore_v09.cls'
hardened = root / 'librarian/LibrarianCore.cls'
assert salvage.exists() and hardened.exists()
assert salvage.read_bytes() != hardened.read_bytes(), 'hardened core must differ from salvage checkpoint'
text = hardened.read_text()
required = [
    'LIBRARIAN-OOREXX-CACHE|2',
    '::method freezeModel',
    '::method isFrozen',
    'targetHitProvenance',
    'candidateWords',
    'jMinusOne = j - 1',
]
for needle in required:
    assert needle in text, f'missing v0.11 hardening marker: {needle}'
for forbidden in ['curr.(j-1)', 'prev.(j-1)', '~allItems(']:
    assert forbidden not in text, f'forbidden legacy construct remains: {forbidden}'
print('LIBRARIAN HARDENED CORE AUDIT: OK')
print('  salvage_sha256=' + hashlib.sha256(salvage.read_bytes()).hexdigest())
print('  hardened_sha256=' + hashlib.sha256(hardened.read_bytes()).hexdigest())
