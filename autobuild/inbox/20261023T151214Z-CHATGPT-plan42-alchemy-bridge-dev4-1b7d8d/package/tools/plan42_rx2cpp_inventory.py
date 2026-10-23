#!/usr/bin/env python3
"""Read-only import of RX2CPP_OBJECT_MODEL/0.1 into Plan42's code-unit boundary.

The ooRexx interpreter (RX2CPP's RxSourceInspector), NOT this Python module,
recognises declarations. This module validates and carries its export; it does
not parse Rexx, run the inspector, prove that an export was authentic, or compile.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

import plan42_rx2cpp_plan as native

API = 'plan42.rx2cpp.inventory/0.1'
WIRE = 'RX2CPP_OBJECT_MODEL/0.1'
MAX_MAP_BYTES = 8 * 1024 * 1024
MAX_UNITS = 20000
KINDS = {'PROLOGUE', 'CLASS', 'METHOD', 'CLASS_METHOD', 'ROUTINE'}
VISIBILITIES = {'PUBLIC', 'PRIVATE', 'PACKAGE'}
FLAGS = {'PROTECTED', 'GUARDED', 'ABSTRACT', 'ATTRIBUTE', 'CONSTANT', 'INSPECTION_ALIAS'}
HEX = re.compile(rb'(?:[0-9A-Fa-f]{2})*\Z')


def reject(message: str) -> dict:
    return {'schema': API, 'ok': False, 'status': 'input-refused', 'reason': message,
            'executed': False, 'published': False, 'replaced': False}


def _text(field: bytes, label: str) -> str:
    if len(field) % 2 or HEX.fullmatch(field) is None:
        raise ValueError(f'{label} is not valid hex bytes')
    try:
        value = bytes.fromhex(field.decode('ascii')).decode('utf-8')
    except UnicodeError as exc:
        raise ValueError(f'{label} is not UTF-8') from exc
    if any(ord(c) < 32 for c in value):
        raise ValueError(f'{label} contains control characters')
    return value


def _ascii(field: bytes, label: str) -> str:
    try:
        return field.decode('ascii')
    except UnicodeDecodeError as exc:
        raise ValueError(f'{label} is not ASCII') from exc


def _parse(raw: bytes) -> tuple[dict, list[dict]]:
    if not raw or len(raw) > MAX_MAP_BYTES or b'\x00' in raw:
        raise ValueError('object-model stream is empty, oversized, or contains NUL')
    lines = raw.splitlines()
    if len(lines) < 2 or lines[0] != WIRE.encode():
        raise ValueError('missing exact RX2CPP_OBJECT_MODEL/0.1 header')
    header = lines[1].split(b'\t')
    if len(header) != 7 or header[0] != b'PACKAGE':
        raise ValueError('invalid PACKAGE model header')
    original = _text(header[1], 'PACKAGE source')
    if not original:
        raise ValueError('PACKAGE source must be non-empty')
    digits, fuzz, form, prolog, line_count = map(lambda b: _ascii(b, 'package property'), header[2:])
    if (not digits.isdigit() or not fuzz.isdigit() or not line_count.isdigit()
            or int(digits) < 1 or int(fuzz) >= int(digits) or form not in {'SCIENTIFIC', 'ENGINEERING'}
            or prolog not in {'PROLOG', 'NOPROLOG'}):
        raise ValueError('invalid package numeric or prologue settings')
    package = {'original_source': original, 'digits': int(digits), 'fuzz': int(fuzz),
               'form': form, 'prolog': prolog, 'prologue_line_count': int(line_count)}
    if len(lines) - 2 > MAX_UNITS:
        raise ValueError('too many object-model units')
    units = []
    seen = set()
    for line_number, line in enumerate(lines[2:], 3):
        fields = line.split(b'\t')
        if len(fields) != 6:
            raise ValueError(f'row {line_number}: expected six tab fields')
        kind = _ascii(fields[0], 'row kind')
        if kind not in KINDS:
            raise ValueError(f'row {line_number}: unsupported record kind {kind!r}')
        owner = _text(fields[1], 'owner')
        selector = _text(fields[2], 'selector')
        visibility = _text(fields[3], 'visibility')
        flags_raw = _text(fields[4], 'flags')
        hex_body = fields[5]
        if len(hex_body) % 2 or HEX.fullmatch(hex_body) is None:
            raise ValueError(f'row {line_number}: invalid source hex')
        source_bytes = bytes.fromhex(hex_body.decode('ascii'))
        flags = [f for f in flags_raw.split(',') if f]
        if len(set(flags)) != len(flags) or set(flags) - FLAGS:
            raise ValueError(f'row {line_number}: invalid method flags')
        if visibility not in VISIBILITIES:
            raise ValueError(f'row {line_number}: invalid visibility')
        if not selector:
            raise ValueError(f'row {line_number}: empty selector')
        if kind in {'METHOD', 'CLASS_METHOD'} and not owner:
            raise ValueError(f'row {line_number}: method has no owning class')
        if kind not in {'METHOD', 'CLASS_METHOD'} and owner:
            raise ValueError(f'row {line_number}: unexpected owner')
        if kind == 'CLASS' and source_bytes:
            raise ValueError(f'row {line_number}: class declaration must not carry method source')
        if kind == 'PROLOGUE' and (selector != 'MAIN' or visibility != 'PACKAGE'):
            raise ValueError(f'row {line_number}: incorrect prologue descriptor')
        if flags and kind not in {'METHOD', 'CLASS_METHOD'}:
            raise ValueError(f'row {line_number}: flags outside method')
        if 'INSPECTION_ALIAS' in flags and (kind != 'CLASS_METHOD' or selector != 'INIT'):
            raise ValueError(f'row {line_number}: inappropriate inspection alias')
        key = (kind, owner, selector)
        if key in seen:
            raise ValueError(f'row {line_number}: duplicate code unit')
        seen.add(key)
        units.append({'kind': kind, 'owner': owner, 'selector': selector,
                      'visibility': visibility, 'flags': flags,
                      'source_hex': hex_body.decode('ascii').upper(),
                      'source_sha256': hashlib.sha256(source_bytes).hexdigest(),
                      'source_bytes': len(source_bytes), 'scope':
                      'METHOD' if kind in {'METHOD', 'CLASS_METHOD'} else kind})
    classes = {u['selector'] for u in units if u['kind'] == 'CLASS'}
    if any(u['kind'] in {'METHOD', 'CLASS_METHOD'} and u['owner'] not in classes for u in units):
        raise ValueError('object-model method references an undeclared class')
    return package, units


def load_inventory(source: str, model: str, mode: str = 'standalone') -> dict:
    """Import evidence; consistency checks are NOT interpreter attestation."""
    try:
        src = native.source_file(source, mode)
        name = Path(model)
        name = name if name.is_absolute() else native.ROOT / name
        if name.is_symlink() or not name.resolve().is_relative_to(native.ROOT.resolve()):
            raise ValueError('inspector evidence is outside the Alchemy workspace or a symlink')
        name = name.resolve()
        if not name.is_file() or name.stat().st_size > MAX_MAP_BYTES:
            raise ValueError('inspector evidence missing or exceeds size limit')
        raw = name.read_bytes()
        package, units = _parse(raw)
        declared = Path(package['original_source'])
        declared = declared if declared.is_absolute() else native.ROOT / declared
        if declared.resolve() != src:
            raise ValueError('inspector-declared source differs from generated Plan42 source')
        source_digest = native.digest(src)
        return {'schema': API, 'ok': True, 'operation': 'native-inventory',
                'status': 'IMPORTED_UNATTESTED', 'source': str(src.relative_to(native.ROOT)),
                'source_sha256': source_digest, 'model_sha256': hashlib.sha256(raw).hexdigest(),
                'model': str(name.relative_to(native.ROOT)), 'model_format': WIRE,
                'mode': mode, 'package': package, 'units': units,
                'unit_count': len(units),
                'counts': {kind: sum(u['kind'] == kind for u in units) for kind in sorted(KINDS)},
                'declaration_authority_claimed': 'RX2CPP ooRexx interpreter objects',
                'export_authenticity_verified': False,
                'source_to_model_semantic_equivalence': 'UNVERIFIED',
                'executed': False, 'published': False, 'replaced': False}
    except (OSError, ValueError) as exc:
        return reject(str(exc))


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', required=True)
    p.add_argument('--model', required=True)
    p.add_argument('--mode', choices=sorted(native.MODES), required=True)
    ns = p.parse_args(argv)
    result = load_inventory(ns.source, ns.model, ns.mode)
    print(json.dumps(result, ensure_ascii=True, sort_keys=True))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
