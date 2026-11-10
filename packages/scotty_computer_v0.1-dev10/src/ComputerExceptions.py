"""Run-scoped exception definitions and observation. Not a background monitor.

The parent Computer invocation supervises only its own child while it is running.
No process is created outside the job lifetime and a trigger does not kill a job.
"""
import datetime as dt
import json
import os
from pathlib import Path
import re
import shlex
import stat
import time

EXCEPTION_SCHEMA = 'scotty.computer.job-exceptions/1'
SAMPLE_SECONDS = 0.10
MAX_WALK_ENTRIES = 50000
MAX_WALK_DEPTH = 24
MAX_RULES = 16
OUTPUT_READ_CHUNK_BYTES = 1024 * 1024
MAX_OUTPUT_SCAN_BYTES_PER_RULE_STREAM = 64 * 1024 * 1024


def parse_registration(text, error):
    try:
        argv = shlex.split(text)
    except ValueError as exc:
        raise error('Malformed exception registration: ' + str(exc), 2) from exc
    if len(argv) < 5 or [x.casefold() for x in argv[:2]] not in (['job', 'exception'], ['job', 'exceptions']):
        raise error('Use job exception register JOB TYPE ...', 2)
    if argv[2].casefold() not in ('register', 'add') or len(argv) < 5:
        raise error('Use job exception register JOB TYPE ...', 2)
    name = argv[3].casefold()
    if not re.fullmatch(r'[a-z][a-z0-9_-]{0,39}', name):
        raise error('Invalid job name', 2)
    kind = argv[4].casefold()
    values = argv[5:]
    if kind == 'runaway_space':
        if len(values) != 3 or not values[1].isascii() or not values[1].isdecimal():
            raise error('Syntax: job exception register JOB runaway_space ABSOLUTE_DIRECTORY N meg|MB|MiB', 2)
        amount = int(values[1])
        factor = {'meg': 1000000, 'mb': 1000000, 'mib': 1048576}.get(values[2].casefold())
        if factor is None or not 1 <= amount <= 1000000:
            raise error('Size must be 1..1000000 meg|MB|MiB', 2)
        path = Path(values[0]); validate_directory(path, error)
        return name, {'type': kind, 'path': str(path), 'limit_bytes': amount * factor,
                      'unit': values[2], 'comparison': 'observed_bytes > limit_bytes', 'location': 'controller'}
    if kind in ('runtime_overrun', 'exceed_runtime'):
        if len(values) != 2 or values[1].casefold() not in ('seconds', 'second', 'sec'):
            raise error('Syntax: job exception register JOB runtime_overrun N seconds', 2)
        try: threshold = float(values[0])
        except ValueError: threshold = -1
        if not 0 < threshold <= 1800 or not threshold == threshold or threshold == float('inf'):
            raise error('Runtime exception threshold must be >0 and <=1800 seconds', 2)
        return name, {'type': 'runtime_overrun', 'limit_seconds': threshold, 'comparison': 'elapsed_seconds > limit_seconds'}
    if kind in ('output_contains', 'output_error'):
        if not values or len(values) > 2 or any(len(v.encode('utf-8')) > 256 for v in values):
            raise error('Syntax: job exception register JOB output_contains "ERROR:" [stdout|stderr|both]', 2)
        needle = values[0]
        stream = values[1].casefold() if len(values) == 2 else 'both'
        if not needle or stream not in ('both', 'stdout', 'stderr') or any(ch in needle for ch in '\x00\r\n'):
            raise error('Invalid output exception needle or stream', 2)
        return name, {'type': 'output_contains', 'needle': needle, 'stream': stream, 'comparison': 'literal bytes, case-sensitive'}
    raise error('Supported exception types: runaway_space, runtime_overrun, output_contains', 2)


def validate_directory(path, error):
    if not path.is_absolute() or str(path) in ('/', ''):
        raise error('Watched workspace must be an explicit absolute directory, not /', 4)
    parts = path.parts
    current = Path(parts[0])
    try:
        for part in parts[1:]:
            if part in ('.', '..'):
                raise error('Watched path may not traverse parents', 4)
            current = current / part
            if current.is_symlink():
                raise error('Watched directory path contains symlink', 4)
        if not current.is_dir():
            raise error('Watched directory does not exist', 4)
    except (PermissionError, OSError) as exc:
        raise error('Cannot access watched workspace: ' + str(exc), 4) from exc


def directory_bytes(path):
    """Apparent file bytes in a subtree. No symlinks followed; limited work."""
    seen = 0
    total = 0
    stack = [(str(path), 0)]
    while stack:
        folder, depth = stack.pop()
        if depth > MAX_WALK_DEPTH:
            raise RuntimeError('directory scan exceeded depth budget')
        with os.scandir(folder) as iterator:
            for ent in iterator:
                seen += 1
                if seen > MAX_WALK_ENTRIES:
                    raise RuntimeError('directory scan exceeded entry budget')
                st = ent.stat(follow_symlinks=False)
                if stat.S_ISREG(st.st_mode):
                    total += st.st_size
                elif stat.S_ISDIR(st.st_mode):
                    stack.append((ent.path, depth + 1))
    return total, seen


class RunObserver:
    def __init__(self, rules, out_path, err_path):
        self.rules = rules
        self.events = []
        self.triggered = set()
        self.start = time.monotonic()
        self.out_path = out_path
        self.err_path = err_path
        self.offsets = {}
        self.tails = {}
        self.complete = True
        self.samples = 0
        self.output_bytes_examined = 0

    def event(self, ix, kind, observed, rule=None):
        if ix in self.triggered:
            return
        self.triggered.add(ix)
        ev = {'type': kind, 'observed': observed,
              'at_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
              'elapsed_seconds': round(time.monotonic() - self.start, 3)}
        if rule is not None:
            ev['rule'] = rule
        self.events.append(ev)

    def tick(self):
        self.samples += 1
        elapsed = time.monotonic() - self.start
        for ix, rule in enumerate(self.rules):
            if ix in self.triggered:
                continue
            kind = rule['type']
            if kind == 'runtime_overrun':
                if elapsed > rule['limit_seconds']:
                    self.event(ix, kind, {'elapsed_seconds': round(elapsed, 3)}, rule)
            elif kind == 'runaway_space':
                try:
                    size, entries = directory_bytes(rule['path'])
                    if size > rule['limit_bytes']:
                        self.event(ix, kind, {'size_bytes': size, 'entries_seen': entries}, rule)
                except (OSError, RuntimeError) as exc:
                    self.complete = False
                    self.event(ix, 'measurement_unavailable', {'reason': str(exc)}, rule)
            elif kind == 'output_contains':
                self._check_output(ix, rule, final=False)

    def _check_output(self, ix, rule, final):
        """Read receipt bytes incrementally; drain any tail when the child exits.

        Backlog is not loss: a busy child can outrun a single 1 MiB sample.
        Incompleteness is recorded only for an unreadable or over-budget stream.
        """
        needle = rule['needle'].encode('utf-8')
        streams = ('stdout', 'stderr') if rule['stream'] == 'both' else (rule['stream'],)
        for stream in streams:
            path = self.out_path if stream == 'stdout' else self.err_path
            key = (ix, stream)
            try:
                with open(path, 'rb') as f:
                    while True:
                        offset = self.offsets.get(key, 0)
                        size = os.fstat(f.fileno()).st_size
                        remaining = MAX_OUTPUT_SCAN_BYTES_PER_RULE_STREAM - offset
                        if size > offset and remaining <= 0:
                            self.complete = False
                            self.event(ix, 'measurement_unavailable',
                                       {'stream': stream, 'reason': 'output scan byte budget exceeded',
                                        'bytes_examined': offset, 'size_bytes': size}, rule)
                            return
                        f.seek(offset)
                        chunk = f.read(min(OUTPUT_READ_CHUNK_BYTES, max(0, remaining)))
                        if not chunk:
                            break
                        self.offsets[key] = offset + len(chunk)
                        self.output_bytes_examined += len(chunk)
                        previous = self.tails.get(key, b'')
                        if needle in previous + chunk:
                            self.event(ix, 'output_contains',
                                       {'stream': stream, 'needle': rule['needle']}, rule)
                            return
                        self.tails[key] = (previous + chunk)[-(len(needle) - 1):] if len(needle) > 1 else b''
                        if not final:
                            break
            except OSError as exc:
                self.complete = False
                self.event(ix, 'measurement_unavailable',
                           {'stream': stream, 'reason': str(exc)}, rule)
                return

    def finish(self):
        # A completed child cannot produce further output: drain its receipts
        # instead of mistaking a temporary sampling backlog for missing data.
        self.tick()
        for ix, rule in enumerate(self.rules):
            if ix not in self.triggered and rule['type'] == 'output_contains':
                self._check_output(ix, rule, final=True)
        return {'schema': EXCEPTION_SCHEMA, 'registered': self.rules, 'raised': self.events,
                'count': len(self.events), 'observation_complete': self.complete,
                'samples': self.samples, 'sample_interval_seconds': SAMPLE_SECONDS,
                'output_bytes_examined': self.output_bytes_examined,
                'max_output_scan_bytes_per_rule_stream': MAX_OUTPUT_SCAN_BYTES_PER_RULE_STREAM,
                'policy': 'report-only; no process termination on exception'}
