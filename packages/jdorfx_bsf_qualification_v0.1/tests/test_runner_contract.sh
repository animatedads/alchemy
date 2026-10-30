#!/usr/bin/env bash
# MOCK TRANSPORT ONLY: validates qualification control flow; no actual ooRexx, BSF or JavaFX semantics.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
mkdir -p "$T/oo/bin" "$T/oo/lib" "$T/oo/include" "$T/bsf" "$T/jdorfx" "$T/rx/native/fixtures" "$T/rx/ootest/interpreter_bugs/crash" "$T/mockbin" "$T/fx" "$T/evidence"
printf 'fixture' >"$T/bsf/BSF.CLS"
printf 'fake-jar' >"$T/bsf/bridge.jar"
printf 'fake-library' >"$T/bsf/bridge.so"
printf 'say "jdorfx test"\n' >"$T/jdorfx/sample.rex"
printf 'sample external\n' >"$T/outside.rex"
printf 'mock javafx' >"$T/fx/javafx.graphics.jar"
printf 'mock javafx' >"$T/fx/javafx.controls.jar"
for n in bsf_demo bsf_callback; do
  printf 'fake fixture\n' >"$T/rx/native/fixtures/$n.cls"
  printf 'say "fixture"\n' >"$T/rx/native/fixtures/${n}_client.rex"
done
for n in stalecrash validgc; do
  printf 'mock cpp\n' >"$T/rx/ootest/interpreter_bugs/crash/$n.cpp"
  printf 'mock rexx\n' >"$T/rx/ootest/interpreter_bugs/crash/$n.rex"
done
cat >"$T/mockbin/g++" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
while [[ $# -gt 0 ]]; do
  if [[ $1 == -o ]]; then shift; : >"$1"; exit 0; fi
  shift
done
exit 1
EOS
cat >"$T/oo/bin/rexx" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
case "$(basename "$1")" in
stalecrash.rex)
  if [[ ${MOCK_FAILURE:-} == native ]]; then echo 'send failed, CheckCondition=0; now collecting'; else echo 'send failed, CheckCondition=1; now collecting'; fi
  echo 'survived the collection'
  echo 'SYNTAX 88.922'
  ;;
validgc.rex)
  echo 'valid send, CheckCondition=0; now collecting'
  echo 'survived the collection'
  ;;
bsf_demo.rex)
  echo 'StringBuilder length: 25'
  if [[ ${MOCK_FAILURE:-} != bsf ]]; then echo 'done'; else echo 'not-done'; fi
  ;;
bsf_callback.rex)
  echo 'sorted by length: [fig, kiwi]'
  echo 'after Java thread: 1'
  echo 'done'
  ;;
sample.rex)
  [[ $(pwd) == "$(dirname "$1")" ]] || { echo 'wrong sample cwd'; exit 10; }
  if [[ ${MOCK_FAILURE:-} == jdorfx ]]; then echo 'wrong'; else echo 'JDORFX-SAMPLE-OK'; fi
  ;;
*) exit 9;;
esac
EOS
chmod +x "$T/mockbin/g++" "$T/oo/bin/rexx"
JAVA_HOME=$(java -XshowSettings:properties -version 2>&1 | sed -n 's/^ *java\.home = //p' | head -1)
[[ -f $JAVA_HOME/lib/server/libjvm.so ]] || { echo 'SKIP mock contract test: no local libjvm.so'; exit 0; }
export OO_ROOT="$T/oo" RX2CPP_ROOT="$T/rx" BSF_HOME="$T/bsf" BSF_JAR="$T/bsf/bridge.jar" BSF_NATIVE_LIBRARY="$T/bsf/bridge.so"
export JDORFX_HOME="$T/jdorfx" JDORFX_SCRIPT="$T/jdorfx/sample.rex" JDORFX_EXPECTED_TEXT=JDORFX-SAMPLE-OK
export JAVAFX_MODULE_PATH="$T/fx" JDORFX_HEADLESS_OK=1 JAVA_HOME
export PATH="$T/mockbin:$PATH" REPEATS=1 MAX_SECONDS=10
call_ok(){ local phase=$1; "$ROOT/bin/qualify.sh" "$phase" >"$T/$phase.out" 2>&1 || { cat "$T/$phase.out"; echo "mock $phase failed"; exit 1; }; grep -q '^PASS' "$T/$phase.out"; }
call_fail(){ local phase=$1; shift; if "$ROOT/bin/qualify.sh" "$phase" >"$T/fail.out" 2>&1; then echo "mock $phase incorrectly PASSED"; exit 1; fi; for arg in "$@"; do grep -Fq -- "$arg" "$T/fail.out" || { cat "$T/fail.out"; echo "Expected $arg"; exit 1; }; done; }
call_ok native
call_ok bsf
call_ok jdorfx
MOCK_FAILURE=native call_fail native 'condition'
MOCK_FAILURE=bsf call_fail bsf 'did not complete'
MOCK_FAILURE=jdorfx call_fail jdorfx 'expected output'
JDORFX_EXPECTED_TEXT= call_fail jdorfx 'mandatory'
JDORFX_SCRIPT="$T/outside.rex" call_fail jdorfx 'must reside inside'
rm -f "$T/fx/javafx.controls.jar"
call_fail jdorfx 'javafx.controls.jar'
printf 'mock javafx' >"$T/fx/javafx.controls.jar"
EVIDENCE_DIR="$T/evidence" call_ok bsf
logs=( "$T"/evidence/jdorfx-bsf-*/receipt.txt )
[[ -f ${logs[0]} ]] || { echo 'evidence missing'; exit 1; }
grep -Fq 'bsf_jar=' "${logs[0]}"
[[ -f ${logs[0]%receipt.txt}/bsf_demo.1.log ]] || { echo 'evidence log missing'; exit 1; }
echo 'PASS mock runner: 3 happy paths, 6 negative paths, evidence retained (NOT runtime qualification)'
