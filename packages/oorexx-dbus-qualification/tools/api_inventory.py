#!/usr/bin/env python3
"""Conservative static inventory of ooRexx class directives.

Not a parser or proof of runtime API compatibility: dynamic exports, aliases,
C++-registered methods, method inheritance and runtime registration need
runtime qualification. Non-UTF-8 files fail closed rather than guessed.
"""
import argparse
import json
import re
from pathlib import Path

DIRECTIVE = re.compile(r'^\s*::(class|method|attribute|routine|requires)\s+(.+)$', re.I)
IDENT = re.compile(r'^\s*(?:"([^"]+)"|\'([^\']+)\'|([^\s]+))(.*)$')
SUPPORTED_SUFFIXES = {'.cls', '.rex', '.rexx'}


def first_atom(rest):
    match = IDENT.match(rest)
    if not match:
        return None, ''
    return next((s for s in match.groups()[:3] if s is not None), ''), match.group(4)


def code_lines(text):
    # Do not interpret in-line ooRexx code or directives inside comments.
    block = False
    for number, line in enumerate(text.splitlines(), 1):
        stripped = line.lstrip()
        if block:
            if '*/' in stripped:
                block = False
            continue
        if stripped.startswith('/*'):
            if '*/' not in stripped:
                block = True
            continue
        if not stripped or stripped.startswith('--') or stripped.startswith('/*'):
            continue
        yield number, line


def scan(root):
    root = Path(root)
    if not root.is_dir():
        raise ValueError('Expected a source directory: ' + str(root))
    members = []
    references = []
    diagnostics = []
    source_files = sorted(p for p in root.rglob('*') if p.is_file() and p.suffix.lower() in SUPPORTED_SUFFIXES)
    for source in source_files:
        rel = source.relative_to(root).as_posix()
        try:
            txt = source.read_text(encoding='utf-8')
        except UnicodeError as exc:
            raise ValueError(f'Non-UTF-8 ooRexx source: {rel}') from exc
        current_class = None
        for line_no, line in code_lines(txt):
            match = DIRECTIVE.match(line)
            if not match:
                continue
            kind, tail = match.group(1).lower(), match.group(2)
            name, opts = first_atom(tail)
            if not name:
                diagnostics.append({'file': rel, 'line': line_no, 'detail': f'Unparsed {kind} name'})
                continue
            tokens = {s.casefold() for s in re.findall(r'[A-Za-z][A-Za-z-]*', opts)}
            if kind == 'class':
                current_class = name
                members.append({'kind': 'class', 'owner': '', 'name': name, 'side': '', 'source': rel, 'line': line_no})
            elif kind == 'requires':
                references.append({'name': name, 'source': rel, 'line': line_no})
            elif kind == 'routine':
                current_class = None
                if 'private' not in tokens:
                    members.append({'kind': 'routine', 'owner': '', 'name': name, 'side': '', 'source': rel, 'line': line_no})
            else:
                if current_class is None:
                    diagnostics.append({'file': rel, 'line': line_no, 'detail': f'{kind} without active class'})
                    continue
                if 'private' in tokens or 'protected' in tokens:
                    continue
                members.append({'kind': kind, 'owner': current_class, 'name': name,
                                'side': 'class' if 'class' in tokens else 'instance', 'source': rel, 'line': line_no})
    # Use case-insensitive signatures for ooRexx names, not source-path identity.
    entries = {}
    for m in members:
        key = '|'.join([m['kind'], m['owner'].casefold(), m['name'].casefold(), m['side']])
        entries.setdefault(key, []).append(m)
    duplicates = sorted(k for k, values in entries.items() if len(values) > 1)
    return {'schema': 'org.alchemy.dbus.api-inventory/0.1', 'basis': 'STATIC_DIRECTIVES_ONLY',
            'source_files': len(source_files), 'public_signatures': sorted(entries),
            'requires': sorted({v['name'] for v in references}, key=str.casefold),
            'duplicates': duplicates, 'diagnostics': diagnostics,
            'evidence': {k: v for k, v in sorted(entries.items())}}


def compare(old, new):
    old_keys, new_keys = set(old['public_signatures']), set(new['public_signatures'])
    return {'schema': 'org.alchemy.dbus.api-compatibility/0.1',
            'basis': 'STATIC_DIRECTIVES_ONLY', 'removed': sorted(old_keys - new_keys),
            'added': sorted(new_keys - old_keys), 'retained': len(old_keys & new_keys),
            'legacy_static_surface_preserved': not (old_keys - new_keys),
            'native_binary_abi': 'NOT_ASSESSED', 'runtime_compatibility': 'NOT_ASSESSED',
            'unresolved_diagnostics': len(old['diagnostics']) + len(new['diagnostics']) +
                                      len(old['duplicates']) + len(new['duplicates'])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source_dir', type=Path)
    parser.add_argument('--compare-to', type=Path, help='old source directory; source_dir is the new candidate')
    parser.add_argument('--strict', action='store_true', help='fail on removed static public signatures, duplicates or diagnostics')
    args = parser.parse_args()
    try:
        new = scan(args.source_dir)
        if args.compare_to:
            old = scan(args.compare_to)
            report = {'candidate': new, 'historical': old, 'comparison': compare(old, new)}
            passed = not (args.strict and (
                report['comparison']['removed'] or report['comparison']['unresolved_diagnostics']))
        else:
            report = new
            passed = not (args.strict and (new['duplicates'] or new['diagnostics']))
    except (OSError, ValueError) as exc:
        print(json.dumps({'status': 'FAIL', 'reason': str(exc)}, indent=2))
        return 1
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
