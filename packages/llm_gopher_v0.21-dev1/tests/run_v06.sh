#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
G="$ROOT/gopher"
REXXC=${REXXC:-/mnt/data/oorexx_runtime_530/usr/local/bin/rexxc}
TD=$(mktemp -d)
trap 'rm -rf "$TD"' EXIT

$G --version | grep -q 'v0.16-dev1'

# Schemas are discoverable and explicitly advertise bounded edits.
$G --profile oorexx describe source.oorexx.method.edit --sphere oorexx > "$TD/desc.json"
python3 - "$TD/desc.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); r=x['result']; assert x['operation_status']['class']=='OPENED'; assert 'bounded-edit' in r['supports']; assert r['parameters']['replacement_path']['required'] is True
PY

cat > "$TD/Sample.cls" <<'REXX'
/* SENTINEL HEADER: must survive byte-for-byte */
::class Sample public
::attribute name

::method hello
  return "old"

::method untouched
  return "SENTINEL-UNTOUCHED"
REXX
cat > "$TD/hello.rex" <<'REXX'
::method hello
  return "new"
REXX
cp "$TD/Sample.cls" "$TD/Sample.before"

$G --profile oorexx exec source.oorexx.method.edit path="$TD/Sample.cls" class=Sample method=hello operation=REPLACE replacement_path="$TD/hello.rex" rexxc="$REXXC" sphere=oorexx > "$TD/rexx.json"
python3 - "$TD/rexx.json" "$TD/Sample.cls" "$TD/Sample.before" <<'PY'
import json,sys,pathlib
x=json.load(open(sys.argv[1])); after=pathlib.Path(sys.argv[2]).read_text(); before=pathlib.Path(sys.argv[3]).read_text()
assert x['operation_status']['class']=='UPDATED'; assert x['result']['committed'] is True
assert 'return "new"' in after and 'SENTINEL-UNTOUCHED' in after and 'SENTINEL HEADER' in after
assert before.replace('return "old"','return "new"') == after
assert x['result']['before_sha256'] != x['result']['after_sha256']; assert x['result']['validation']['rc']==0
PY

# Invalid ooRexx replacement must not be committed.
cp "$TD/Sample.cls" "$TD/Sample.good"
cat > "$TD/bad.rex" <<'REXX'
::method hello
  if then
REXX
set +e
$G --profile oorexx exec source.oorexx.method.edit path="$TD/Sample.cls" class=Sample method=hello operation=REPLACE replacement_path="$TD/bad.rex" rexxc="$REXXC" sphere=oorexx > "$TD/bad.json"
set -e
cmp "$TD/Sample.cls" "$TD/Sample.good"
python3 - "$TD/bad.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['operation_status']['class']=='VALIDATION_FAILED'; assert x['result']['committed'] is False
PY

# Stale digest fencing rejects editing the wrong generation.
set +e
$G --profile oorexx exec source.oorexx.method.edit path="$TD/Sample.cls" class=Sample method=hello operation=REPLACE replacement_path="$TD/hello.rex" expected_sha256=0000 rexxc="$REXXC" sphere=oorexx > "$TD/stale.json"
set -e
python3 - "$TD/stale.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['operation_status']['class']=='STALE_SOURCE'
PY

cat > "$TD/sample.py" <<'PY'
# SENTINEL HEADER: must survive byte-for-byte
import decimal

class Sample:
    CLASS_SENTINEL = "KEEP"

    def hello(self):
        return "old"

    def untouched(self):
        return "SENTINEL-UNTOUCHED"

class Other:
    pass
PY
cat > "$TD/hello.pyfrag" <<'PY'
def hello(self):
    return "new"
PY
cp "$TD/sample.py" "$TD/sample.before"
$G --profile oorexx exec source.python.method.edit path="$TD/sample.py" class=Sample method=hello operation=REPLACE replacement_path="$TD/hello.pyfrag" sphere=oorexx > "$TD/py.json"
python3 - "$TD/py.json" "$TD/sample.py" <<'PY'
import ast,json,sys,pathlib
x=json.load(open(sys.argv[1])); s=pathlib.Path(sys.argv[2]).read_text(); ast.parse(s)
assert x['operation_status']['class']=='UPDATED'; assert 'import decimal' in s; assert 'CLASS_SENTINEL = "KEEP"' in s; assert 'SENTINEL-UNTOUCHED' in s; assert 'class Other:' in s; assert 'return "new"' in s
# A bounded replacement is tiny; a lossy class regeneration would make this diff enormous.
assert x['result']['diff']['line_count'] < 20
PY

# Malformed Python replacement never reaches disk.
cp "$TD/sample.py" "$TD/sample.good"
printf '%s\n' 'def hello(self)' '    return "bad"' > "$TD/bad.pyfrag"
set +e
$G --profile oorexx exec source.python.method.edit path="$TD/sample.py" class=Sample method=hello operation=REPLACE replacement_path="$TD/bad.pyfrag" sphere=oorexx > "$TD/pybad.json"
set -e
cmp "$TD/sample.py" "$TD/sample.good"
python3 - "$TD/pybad.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['operation_status']['class']=='INVALID_ARGUMENT'; assert x['tool_status']['class']=='OK'
PY

# Task-oriented LLM command uses the same capability contract rather than requiring its exact name.
cat > "$TD/task.py" <<'PYTASK'
class Task:
    def value(self):
        return 1
PYTASK
cat > "$TD/value.pyfrag" <<'PYFRAG'
def value(self):
    return 2
PYFRAG
$G --profile oorexx edit method Task value --in "$TD/task.py" --replacement "$TD/value.pyfrag" > "$TD/task.json"
python3 - "$TD/task.json" "$TD/task.py" <<'PYCHECK'
import ast,json,sys,pathlib
x=json.load(open(sys.argv[1])); s=pathlib.Path(sys.argv[2]).read_text(); ast.parse(s)
assert x['operation_status']['class']=='UPDATED'; assert x['result']['task']=='edit method'; assert x['result']['capability']=='source.python.method.edit'; assert 'return 2' in s
PYCHECK

echo 'PASS ALL LLM GOPHER v0.6 BOUNDED SOURCE-EDIT TESTS'
