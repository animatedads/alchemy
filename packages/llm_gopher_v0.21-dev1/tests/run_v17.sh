#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
PY=${LLM_GOPHER_PYTHON:-python3}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

"$ROOT/gopher" --profile java language describe java > "$TMP/module"
grep -q '"id": "java"' "$TMP/module"
grep -q '"examiner_capability": "source.java.examine"' "$TMP/module"
grep -q '"compile_capability": "source.java.compile"' "$TMP/module"

"$ROOT/gopher" --profile java language resolve Demo.java > "$TMP/resolve"
grep -q '"class": "FOUND"' "$TMP/resolve"
grep -q '"id": "java"' "$TMP/resolve"

cat > "$TMP/HelloSwing.java" <<'EOF'
import javax.swing.SwingUtilities;
public final class HelloSwing {
    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> System.out.println("ok"));
    }
}
EOF
"$ROOT/gopher" --profile java exec source.java.compile path="$TMP/HelloSwing.java" release=17 sphere=java > "$TMP/compile"
grep -q '"class": "VALID"' "$TMP/compile"
grep -q '"classes_retained": false' "$TMP/compile"

"$ROOT/gopher" --profile java examine source HelloSwing.java --in "$TMP" --symbol HelloSwing > "$TMP/examine"
grep -q '"kind": "java"' "$TMP/examine"
grep -q '"match_kind": "EXACT_DECLARATION"' "$TMP/examine"
grep -q '"declaration": "class"' "$TMP/examine"

cat > "$TMP/Wrong.java" <<'EOF'
public class Other {
    public void run() {
        try { throw new RuntimeException("x"); }
        catch (RuntimeException e) {}
    }
}
EOF
"$ROOT/gopher" --profile java rules check "$TMP/Wrong.java" --language java --sphere java > "$TMP/rules"
grep -q '"JAVA.SOURCE.PUBLIC_TYPE_FILENAME"' "$TMP/rules"
grep -q '"JAVA.EXCEPT.EMPTY_CATCH"' "$TMP/rules"
grep -q '"breach_count": 2' "$TMP/rules"
grep -q '"blockers": 1' "$TMP/rules"
grep -q '"advisories": 1' "$TMP/rules"


cat > "$TMP/Outer.java" <<'EOF'
public class Outer {
    public static class Inner {}
}
EOF
"$ROOT/gopher" --profile java rules check "$TMP/Outer.java" --language java --sphere java > "$TMP/nested-public"
grep -q '"class": "CORRECT"' "$TMP/nested-public"

cat > "$TMP/Methods.java" <<'EOF'
public class Methods {
    public void run() {}
    public void caller() { run(); }
}
EOF
"$ROOT/gopher" --profile java exec source.symbol.lookup path="$TMP/Methods.java" symbol=run language=java > "$TMP/method"
grep -q '"class": "FOUND"' "$TMP/method"
grep -q '"declaration": "method"' "$TMP/method"
grep -q '"count": 1' "$TMP/method"

"$ROOT/gopher" --profile java context java --full > "$TMP/context"
grep -q '"language_modules"' "$TMP/context"
grep -q '"java.lessons"' "$TMP/context"
grep -q '"source.java.compile"' "$TMP/context"

if [ -n "${LLM_GOPHER_TEST_API_ROLLUP:-}" ] && [ -f "$LLM_GOPHER_TEST_API_ROLLUP" ]; then
  "$ROOT/gopher" --profile java examine source JndiJmsBankNetwork.java \
      --in "$LLM_GOPHER_TEST_API_ROLLUP" \
      --nested current/testapps/federationbank_java_atm_v0.1.9.zip \
      --symbol JndiJmsBankNetwork > "$TMP/real-jms"
  grep -q '"class": "EXAMINED"' "$TMP/real-jms"
  grep -q '"match_kind": "EXACT_DECLARATION"' "$TMP/real-jms"
  grep -q '"line": 21' "$TMP/real-jms"
  grep -q 'federationbank_java_atm_v0.1.9/src/main/java/com/federationbank/atm/bank/JndiJmsBankNetwork.java' "$TMP/real-jms"

  "$ROOT/gopher" --profile java examine source WireSwingEdt.java \
      --in "$LLM_GOPHER_TEST_API_ROLLUP" \
      --nested current/wire_ui_swing_v0.2-dev3.zip \
      --symbol WireSwingEdt > "$TMP/real-swing"
  grep -q '"class": "EXAMINED"' "$TMP/real-swing"
  grep -q '"line": 7' "$TMP/real-swing"
fi

echo "PASS ALL LLM GOPHER v0.17 JAVA/LANGUAGE-MODULE TESTS"
