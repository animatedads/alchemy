# oorexx_python_gate v0.1

- **Architecture:** Tom Dyer
- **Coding:** Claude (Opus 5.5), 14 Nov 2026
- **Written by:** Claude (Opus 5.5)

This gate fails any estate package that carries Python, or calls Python, without saying why ooRexx can't do the job. It is written in ooRexx and logs through oorexx_logging. Autobuild v0.5.3 runs it first on every package.

## The rule

Python is allowed only when the package root holds `PYTHON_JUSTIFICATION`, with one line per Python file or caller:

```
tools/sdk.py | the vendor ships only a Python SDK with no C API and no published wire protocol to implement in ooRexx
```

A reason needs at least 10 words. The gate cannot tell a good reason from a bad one. It prints every reason in the build log, so the VERIFIER and the Architect can. "Reading a file is complex" is not a reason: the estate has `crypto.cls`, `oorexx_archive`, `oorexx_compress`, `json.cls` and `.stream`.

## What counts as Python

- `*.py`, `*.pyw` and `*.pyi` files.
- Files whose `#!` line names python. Renaming the file doesn't hide it.
- `.rex`, `.rexx`, `.cls`, `.orx` and `.sh` files with a line that runs python on a script, `-m`, `-c` or `-u`. For example `"python3 codehehe.py"` or `address system 'python3 x.py'`. Words, comments and `echo python` are not calls. A caller's entry is keyed by the caller's own path.
- Exempt, but listed in the report: anything under `vendor/`, `upstream/` or `third_party/`. That is third-party code carried unchanged.
- `.git/` is never scanned.

## Use

```
rexx packages/oorexx_python_gate_v0.1/bin/python_gate.rex PACKAGE_DIR
```
```
rexx packages/oorexx_python_gate_v0.1/bin/python_gate.rex PACKAGE_DIR --output report.json --advisory
```

Exit codes: 0 PASS, 1 FAIL, 2 usage error. With `--advisory` it always exits 0. Progress goes to stderr; the JSON report (`alchemy.python-gate.report/1`) goes to stdout.

## Limits

The check is lexical. It doesn't know whether a line runs, so a string that spells out a Python command line counts as a call. This gate's own tests do exactly that: they hold `"python3 codehehe.py"` as fixture data. That gives a false positive, and it is meant to: the answer is a justification line, not an exemption. This package carries one.

## Tests

```
rexx packages/oorexx_python_gate_v0.1/tests/test_python_gate.rex
```

There are 23 checks, Tom's `rexx.app` parody among them. Over all 497 packages on `main` (14 Nov 2026), 317 pass and 180 fail. See the Autobuild v0.5.3 README.

Needs: ooRexx 5.3, `packages/oorexx_logging_v0.7`, `packages/oorexx_logging_stream_target_v0.1`.
