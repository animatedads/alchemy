#!/usr/bin/env python3
"""RexxOS research Virtual UPS /1: deterministic, evidence-only power simulator.

No physical host power actions, no network listener, no guest device integration.
The JSON-RPC 2.0 binding is newline-delimited JSON on stdin/stdout only.
"""
import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import re
import math
import os
from pathlib import Path
import stat
import sys

STATE_SCHEMA = 'virtual.ups.state/1'
EVENT_SCHEMA = 'virtual.ups.event/1'
JOURNAL_SCHEMA = 'virtual.ups.journal/1'
SNAPSHOT_SCHEMA = 'virtual.ups.snapshot/1'
SIGNAL_SCHEMA = 'virtual.ups.signals/1'
ZERO_SHA = '0' * 64
OBS_SCHEMA = 'virtual.ups.guest-observation/1'
MAX_CONSOLE_BYTES = 2 * 1024 * 1024


def strict_json_loads(raw):
    """Reject nonstandard constants and duplicate object keys, also for journals."""
    def unique_keys(pairs):
        obj = {}
        for k, v in pairs:
            if k in obj:
                raise ValueError('duplicate JSON object key')
            obj[k] = v
        return obj
    def invalid_constant(name):
        raise ValueError('nonfinite JSON number not permitted')
    return json.loads(raw, object_pairs_hook=unique_keys, parse_constant=invalid_constant)


def inspect_tops20_console(data):
    """Read-only observational classification: never assert electrical power truth."""
    if not isinstance(data, bytes) or len(data) > MAX_CONSOLE_BYTES:
        raise ValueError('console evidence must be bytes <=2MiB')
    text = data.decode('utf-8', errors='replace').replace('\x00', '')
    lines = text.splitlines()
    ups = [n + 1 for n, line in enumerate(lines)
           if re.search(r'\[SCHEDULER\]:\s*Waiting for UPS:', line)]
    mail = [n + 1 for n, line in enumerate(lines) if re.search(r'\bMAILS\(\d+\)', line)]
    mx = [n + 1 for n, line in enumerate(lines)
          if re.search(r'\bMX\s+OPERATOR\b|\bMX>\s*', line)]
    return {'schema': OBS_SCHEMA, 'source': 'unverified_guest_console_capture',
            'synthetic': False, 'guest_power_state': 'unknown',
            'electrical_ups_absence_proven': False, 'mail_delivery_failure_proven': False,
            'mx_attribution': 'documented_in_KLH10_klt20_guide_not_verified_from_this_capture',
            'matches': {'scheduler_waiting_for_ups_lines': ups,
                        'mails_notification_lines': mail, 'mx_program_lines': mx},
            'interpretation': ('TOPS20_MX_MAIL_SUBSYSTEM_CONTEXT_POWER_MEANING_UNRESOLVED'
                               if ups else 'NO_MATCHING_SCHEDULER_MESSAGE')}



def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True)


def digest(value):
    return hashlib.sha256(canonical(value).encode('utf-8')).hexdigest()


def int_in_range(value, minimum, maximum, name):
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValueError(f'{name} must be integer in [{minimum}, {maximum}]')
    return value


def init_state(p):
    required = {'name', 'capacity_wh', 'initial_wh', 'load_w', 'charge_w', 'low_pct', 'critical_pct'}
    if set(p) != required:
        raise ValueError('genesis parameters do not match expected shape')
    if not isinstance(p['name'], str) or not (1 <= len(p['name']) <= 128):
        raise ValueError('name must be a nonempty string <=128 characters')
    cap = int_in_range(p['capacity_wh'], 1, 1000000, 'capacity_wh')
    initial = int_in_range(p['initial_wh'], 0, cap, 'initial_wh')
    load = int_in_range(p['load_w'], 1, 1000000, 'load_w')
    charge = int_in_range(p['charge_w'], 1, 1000000, 'charge_w')
    low = int_in_range(p['low_pct'], 1, 99, 'low_pct')
    critical = int_in_range(p['critical_pct'], 0, low - 1, 'critical_pct')
    return {'schema': STATE_SCHEMA, 'name': p['name'], 'capacity_ws': cap * 3600,
            'remaining_ws': initial * 3600, 'load_w': load, 'charge_w': charge,
            'low_pct': low, 'critical_pct': critical,
            'mains_present': True, 'logical_seconds': 0, 'revision': 0}


def event(state, kind, at=None, **fields):
    return {'schema': EVENT_SCHEMA, 'name': state['name'],
            'logical_seconds': state['logical_seconds'] if at is None else at,
            'kind': kind, 'synthetic': True, **fields}


def apply(state, action, params):
    """Pure deterministic transition; no I/O or host clock access."""
    new = state.copy()
    at = state['logical_seconds']
    events = []
    if action == 'mains':
        if set(params) != {'present'} or type(params['present']) is not bool:
            raise ValueError('mains needs boolean present')
        if state['mains_present'] != params['present']:
            new['mains_present'] = params['present']
            events.append(event(new, 'mains_restored' if params['present'] else 'mains_lost'))
    elif action == 'load':
        if set(params) != {'watts'}:
            raise ValueError('load needs watts')
        watts = int_in_range(params['watts'], 1, 1000000, 'watts')
        if watts != state['load_w']:
            new['load_w'] = watts
            events.append(event(new, 'load_changed', watts=watts))
    elif action == 'advance':
        if set(params) != {'seconds'}:
            raise ValueError('advance needs seconds')
        seconds = int_in_range(params['seconds'], 1, 86400 * 365, 'seconds')
        if state['logical_seconds'] + seconds > 2**53:
            raise ValueError('logical time limit exceeded')
        capacity = state['capacity_ws']
        start = state['remaining_ws']
        if state['mains_present']:
            rate = state['charge_w']
            end = min(capacity, start + rate * seconds)
            crossings = []
            for pct, kind in ((state['critical_pct'], 'battery_above_critical'),
                              (state['low_pct'], 'battery_above_low'), (100, 'battery_full')):
                boundary = capacity * pct // 100
                if start <= boundary < end or (pct == 100 and start < capacity and end == capacity):
                    threshold = boundary + 1 if pct != 100 else capacity
                    delta = (threshold - start + rate - 1) // rate
                    crossings.append((delta, kind))
        else:
            rate = state['load_w']
            end = max(0, start - rate * seconds)
            crossings = []
            for pct, kind in ((state['low_pct'], 'battery_low'),
                              (state['critical_pct'], 'battery_critical'), (0, 'battery_empty')):
                boundary = capacity * pct // 100
                if start > boundary >= end:
                    delta = (start - boundary + rate - 1) // rate
                    crossings.append((delta, kind))
        for delta, kind in sorted(crossings, key=lambda x: (x[0], x[1])):
            events.append(event(new, kind, at=at + delta))
        new['remaining_ws'] = end
        new['logical_seconds'] = at + seconds
    else:
        raise ValueError('unknown transition action')
    new['revision'] += 1
    return new, events


def signals(state):
    capacity = state['capacity_ws']
    remaining = state['remaining_ws']
    pct = 100 * remaining / capacity
    return {'schema': SIGNAL_SCHEMA, 'name': state['name'], 'synthetic': True,
            'guest_attached': False, 'logical_seconds': state['logical_seconds'],
            'mains_ok': state['mains_present'], 'battery_percent': round(pct, 3),
            'battery_low': 100 * remaining <= state['low_pct'] * capacity,
            'battery_critical': 100 * remaining <= state['critical_pct'] * capacity,
            'battery_empty': remaining == 0,
            'power_available': state['mains_present'] or remaining > 0}


def status(state):
    sig = signals(state)
    return {'state': state.copy(), 'signals': sig,
            'estimated_battery_runtime_seconds': state['remaining_ws'] // state['load_w'],
            'source': 'synthetic', 'physical_power_authority': False,
            'guest_attached': False}


def record(payload):
    return {**payload, 'record_sha256': digest(payload)}


def os_open_regular(path, flags, mode=0o600):
    fd = os.open(path, flags | getattr(os, 'O_NOFOLLOW', 0) | getattr(os, 'O_CLOEXEC', 0), mode)
    if not stat.S_ISREG(os.fstat(fd).st_mode):
        os.close(fd)
        raise ValueError('expected regular file, not a device')
    return fd


class Store:
    def __init__(self, directory):
        self.directory = Path(directory)
        self.journal = self.directory / 'journal.jsonl'
        self.lock = self.directory / 'store.lock'

    @contextmanager
    def locked(self, exclusive):
        # Only local paths are supported; caller must own/trust the state directory.
        self.directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        if self.directory.is_symlink():
            raise ValueError('state directory must not be symlink')
        dstat = self.directory.stat()
        if dstat.st_uid != os.getuid() or (stat.S_IMODE(dstat.st_mode) & 0o077):
            raise ValueError('state directory must be owned by caller and private (mode 0700)')
        fd = os_open_regular(self.lock, os.O_CREAT | os.O_RDWR)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH)
            yield
        finally:
            fcntl.flock(fd, fcntl.LOCK_UN)
            os.close(fd)

    def replay(self):
        if not self.journal.exists() and not self.journal.is_symlink():
            raise ValueError('not initialized; run init first')
        fd = os_open_regular(self.journal, os.O_RDONLY)
        try:
            with os.fdopen(fd, 'rb') as f:
                data = f.read()
        except Exception:
            raise
        if not data or not data.endswith(b'\n'):
            raise ValueError('journal incomplete or empty: fail closed')
        state = None
        prev = ZERO_SHA
        events = []
        records = 0
        for raw in data.splitlines():
            records += 1
            entry = strict_json_loads(raw)
            if entry.get('schema') != JOURNAL_SCHEMA or entry.get('sequence') != records - 1:
                raise ValueError(f'bad journal schema/sequence at record {records}')
            if entry.get('previous_record_sha256') != prev:
                raise ValueError(f'broken hash chain at record {records}')
            sha = entry.get('record_sha256')
            if sha != digest({k: v for k, v in entry.items() if k != 'record_sha256'}):
                raise ValueError(f'journal checksum failure at record {records}')
            action = entry.get('action')
            params = entry.get('params')
            if not isinstance(params, dict):
                raise ValueError('invalid journal parameters')
            if records == 1 and action == 'init':
                state = init_state(params)
                generated = [event(state, 'simulation_initialized')]
            elif records > 1 and action in ('mains', 'load', 'advance'):
                state, generated = apply(state, action, params)
            else:
                raise ValueError(f'unsupported action in journal record {records}')
            if entry.get('events') != generated or entry.get('state_sha256') != digest(state):
                raise ValueError(f'state/events mismatch at record {records}')
            events.extend(generated)
            prev = sha
        return state, events, records, prev

    def append(self, entry):
        payload = canonical(entry).encode('ascii') + b'\n'
        fd = os_open_regular(self.journal, os.O_WRONLY | os.O_CREAT | os.O_APPEND)
        try:
            if os.write(fd, payload) != len(payload):
                raise OSError('incomplete journal write')
            os.fsync(fd)
        finally:
            os.close(fd)
        dirfd = os.open(self.directory, os.O_RDONLY | getattr(os, 'O_DIRECTORY', 0))
        try:
            os.fsync(dirfd)
        finally:
            os.close(dirfd)

    def init(self, params):
        with self.locked(True):
            if self.journal.exists() or self.journal.is_symlink():
                raise ValueError('already initialized: refusing overwrite')
            state = init_state(params)
            genesis = record({'schema': JOURNAL_SCHEMA, 'sequence': 0,
                              'previous_record_sha256': ZERO_SHA, 'action': 'init',
                              'params': params, 'events': [event(state, 'simulation_initialized')],
                              'state_sha256': digest(state)})
            self.append(genesis)
            return status(state)

    def query(self, what):
        with self.locked(False):
            state, events, n, head = self.replay()
        if what == 'status':
            return status(state)
        if what == 'signals':
            return signals(state)
        if what == 'events':
            return events
        if what == 'audit':
            return {'valid': True, 'records': n, 'head_sha256': head, 'state_sha256': digest(state)}
        if what == 'snapshot':
            return {'schema': SNAPSHOT_SCHEMA, 'state': state, 'events': events,
                    'journal_head_sha256': head, 'state_sha256': digest(state),
                    'synthetic': True, 'guest_attached': False}
        raise ValueError('unknown query')

    def mutate(self, action, params):
        with self.locked(True):
            state, _, n, head = self.replay()
            new, events = apply(state, action, params)
            entry = record({'schema': JOURNAL_SCHEMA, 'sequence': n,
                            'previous_record_sha256': head, 'action': action,
                            'params': params, 'events': events,
                            'state_sha256': digest(new)})
            self.append(entry)
            return {'status': status(new), 'events': events}


def jsonrpc(req, store, allow_simulation):
    if not isinstance(req, dict) or req.get('jsonrpc') != '2.0' or not isinstance(req.get('method'), str):
        return {'jsonrpc': '2.0', 'id': req.get('id') if isinstance(req, dict) else None,
                'error': {'code': -32600, 'message': 'Invalid Request'}}
    rid = req.get('id')
    if 'id' in req and (type(rid) not in (str, int, float, type(None)) or (type(rid) is float and not math.isfinite(rid))):
        return {'jsonrpc': '2.0', 'id': None, 'error': {'code': -32600, 'message': 'Invalid id'}}
    # Notifications are ignored, including writes: never perform unacknowledged mutations.
    if 'id' not in req:
        return None
    method = req['method']
    params = req.get('params', {})
    if not isinstance(params, dict):
        error = {'code': -32602, 'message': 'Named object parameters required'}
    else:
        try:
            q = {'ups.status': 'status', 'ups.signals': 'signals', 'ups.events': 'events',
                 'ups.audit': 'audit', 'ups.snapshot': 'snapshot'}
            if method in q:
                if params:
                    raise ValueError('this method takes no parameters')
                result = store.query(q[method])
            elif method in ('ups.mains', 'ups.load', 'ups.advance'):
                if not allow_simulation:
                    return {'jsonrpc': '2.0', 'id': rid,
                            'error': {'code': -32001, 'message': 'Simulation mutations disabled'}}
                result = store.mutate(method.split('.')[1], params)
            else:
                return {'jsonrpc': '2.0', 'id': rid,
                        'error': {'code': -32601, 'message': 'Method not found'}}
            return {'jsonrpc': '2.0', 'id': rid, 'result': result}
        except ValueError as exc:
            error = {'code': -32602, 'message': str(exc)}
        except (OSError, json.JSONDecodeError) as exc:
            error = {'code': -32000, 'message': 'Journal unavailable or invalid: ' + str(exc)}
    return {'jsonrpc': '2.0', 'id': rid, 'error': error}


def emit(x):
    print(canonical(x))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--dir', default='./virtual-ups-state', help='local state directory (never global)')
    sub = ap.add_subparsers(dest='command', required=True)
    init = sub.add_parser('init', help='initialize a NEW, local synthetic UPS')
    init.add_argument('--name', default='ed209j-kl10')
    init.add_argument('--capacity-wh', type=int, default=100)
    init.add_argument('--initial-wh', type=int, default=100)
    init.add_argument('--load-w', type=int, default=200)
    init.add_argument('--charge-w', type=int, default=60)
    init.add_argument('--low-pct', type=int, default=20)
    init.add_argument('--critical-pct', type=int, default=5)
    for p in [init]:
        p.add_argument('--simulate', action='store_true', help='explicit consent for synthetic writes')
    for verb in ('status', 'signals', 'events', 'audit', 'snapshot'):
        sub.add_parser(verb)
    mains = sub.add_parser('mains')
    mains.add_argument('setting', choices=('on', 'off'))
    mains.add_argument('--simulate', action='store_true')
    load = sub.add_parser('load')
    load.add_argument('watts', type=int)
    load.add_argument('--simulate', action='store_true')
    advance = sub.add_parser('advance')
    advance.add_argument('seconds', type=int)
    advance.add_argument('--simulate', action='store_true')
    observation = sub.add_parser('inspect-tops20', help='classify local guest transcript; read-only')
    observation.add_argument('--log', required=True, help='guest console capture path')
    rpc = sub.add_parser('rpc-stdio')
    rpc.add_argument('--simulate', action='store_true', help='allow synthetic changes via JSON-RPC')
    args = ap.parse_args(argv)
    os.umask(0o077)
    store = Store(args.dir)
    try:
        if args.command == 'inspect-tops20':
            # Classifies guest TEXT, not authoritative guest or physical host state.
            with open(args.log, 'rb') as f:
                capture = f.read(MAX_CONSOLE_BYTES + 1)
            emit(inspect_tops20_console(capture))
            return 0
        if args.command == 'rpc-stdio':
            for raw in sys.stdin:
                try:
                    req = strict_json_loads(raw)
                except (json.JSONDecodeError, ValueError):
                    emit({'jsonrpc': '2.0', 'id': None,
                          'error': {'code': -32700, 'message': 'Parse error'}})
                    continue
                response = jsonrpc(req, store, args.simulate)
                if response is not None:
                    emit(response)
            return 0
        if args.command in ('status', 'signals', 'events', 'audit', 'snapshot'):
            emit(store.query(args.command))
            return 0
        if not args.simulate:
            raise ValueError('synthetic writes require --simulate')
        if args.command == 'init':
            emit(store.init({'name': args.name, 'capacity_wh': args.capacity_wh,
                             'initial_wh': args.initial_wh, 'load_w': args.load_w,
                             'charge_w': args.charge_w, 'low_pct': args.low_pct,
                             'critical_pct': args.critical_pct}))
        else:
            if args.command == 'mains':
                params = {'present': args.setting == 'on'}
            elif args.command == 'load':
                params = {'watts': args.watts}
            else:
                params = {'seconds': args.seconds}
            emit(store.mutate(args.command, params))
        return 0
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        print(f'Virtual UPS: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
