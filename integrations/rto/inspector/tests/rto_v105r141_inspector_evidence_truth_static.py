#!/usr/bin/env python3
"""Prove that Inspector coverage requires structured evidence, not prose."""
from __future__ import annotations
import importlib.util
import json
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('rto_inspector_import', ROOT/'tools/rto_inspector_import.py')
assert SPEC and SPEC.loader
mod = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mod)


def fixture(base: Path, name: str, payload: object) -> None:
    (base/name).parent.mkdir(parents=True, exist_ok=True)
    (base/name).write_text(json.dumps(payload), encoding='utf-8')


def check() -> None:
    live = ROOT/'tests/fixtures/inspector-live'
    accepted = mod.summarize_live(ROOT, live)
    assert accepted['ok']
    assert 'RTOCOMMAND' in accepted['observed_classes']
    assert 'rto-authority-corridor' in accepted['receipt_stems']
    assert mod.compare_reports(ROOT, accepted)['ok']

    with tempfile.TemporaryDirectory() as d:
        p = Path(d)
        # A false claim in a textual explanation must never imply a live class.
        fixture(p, 'rto-inspector-CORE-fake.json', {
            'schema': mod.SNAPSHOT_SCHEMA,
            'warning': 'RTOCOMMAND RTOOPERATIONSECURITYCONTEXT',
            'objects': [{'name': 'noise', 'description': 'RTOREX86LOWFRUITOPERATIONS'}],
        })
        report = mod.summarize_live(ROOT, p)
        assert not report['observed_classes'], report
        assert mod.REQUIRED_CORRIDOR_CLASSES <= set(mod.compare_reports(ROOT, report)['authority_classes_missing_live'])

        # Reject contradictory/failed receipts even when they mention classes.
        fixture(p, '.rto-authority-corridor.receipt.json', {
            'schema': mod.RECEIPT_SCHEMA,
            'trace_request': 'rto-authority-corridor.json',
            'status': 'rejected', 'loaded_rules': 5, 'classes': ['RTOCOMMAND'],
        })
        report = mod.summarize_live(ROOT, p)
        assert not report['ok']
        assert 'rto-authority-corridor' not in report['receipt_stems']
        assert not mod.compare_reports(ROOT, report)['ok']

        # Correct the status but make the receipt lie about the filename.
        fixture(p, '.rto-authority-corridor.receipt.json', {
            'schema': mod.RECEIPT_SCHEMA,
            'trace_request': '../different-request.json',
            'status': 'loaded', 'loaded_rules': 9, 'classes': ['RTOCOMMAND'],
        })
        assert not mod.summarize_live(ROOT, p)['ok']

        # Explicitly reject filesystem links as evidence sources.
        (p/'.rto-authority-corridor.receipt.json').unlink()
        (p/'rto-inspector-CORE-fake.json').unlink()
        (p/'suspicious.json').symlink_to(live/'rto-inspector-CORE-20260619T180000000000.json')
        assert not mod.summarize_live(ROOT, p)['ok']

        # A receipt with zero installed rules is not proof of hook installation.
        (p/'suspicious.json').unlink()
        fixture(p, '.rto-authority-corridor.receipt.json', {
            'schema': mod.RECEIPT_SCHEMA,
            'trace_request': 'rto-authority-corridor.json',
            'status': 'loaded', 'loaded_rules': 0, 'classes': ['RTOCOMMAND'],
        })
        assert not mod.summarize_live(ROOT, p)['ok']

    # No-live remains warning-only rather than fabricated success.
    absent = mod.summarize_live(ROOT, ROOT/'reports/inspector/absent-do-not-create')
    assert absent['ok'] and absent['live_required_to_clear_warnings']
    assert not absent['observed_classes']


if __name__ == '__main__':
    check()
    print('PASS RTO Inspector evidence truth: genuine structured / forged / rejected / symlink / zero-rule')