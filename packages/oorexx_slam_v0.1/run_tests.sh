#!/bin/sh
# SLAM v0.1 qualification: segmenter, SQLite node store, edge weights, Task turns, corpus.
# Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-10-28.
# Needs: ooRexx 5.x (rexx on PATH, plus its headers to build Rexx/SQL and the foreign runtime), gcc, g++, make, patch, SQLite 3 dev files,
# and a JDK 17 or later (javac, java) for the Java reader and the Federation Bank ATM probe.
# ALCHEMY_REPO_ROOT: the alchemy checkout (default: two directories above this package).
# REXXSQL_LIBDIR: a directory that already holds librexxsql.so (default: build it now).
# REXX_INCDIR, REXX_LIBDIR: passed to the Rexx/SQL build when ooRexx is not installed system-wide.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO=${ALCHEMY_REPO_ROOT:-$(CDPATH= cd -- "$ROOT/../.." && pwd)}
P="$REPO/packages"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
if [ -z "${REXXSQL_LIBDIR:-}" ]; then
  echo "== build librexxsql.so"
  sh "$P/oorexx_rexxsql_backend_v0.1/tools/build_rexxsql.sh" "$WORK/lib"
  REXXSQL_LIBDIR="$WORK/lib"
fi
echo "== build libforeign_runtime.so (the fd_door code needs foreign.cls to load)"
FOREIGN="$P/oorexx_foreign_runtime_v0.22.6"
REXX_BINDIR=$(dirname -- "$(command -v rexx)")
mkdir -p "$WORK/foreign"
${CXX:-g++} -std=c++17 -O0 -fPIC -I"${REXX_INCDIR:-$REXX_BINDIR/../include}" -shared -o "$WORK/foreign/libforeign_runtime.so" "$FOREIGN/src/foreign_runtime.cpp" -ldl
export LD_LIBRARY_PATH="$REXXSQL_LIBDIR:$WORK/foreign${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$ROOT/vendor/rx2cpp:$P/oorexx_rexxsql_backend_v0.1/src:$P/oorexx_native_database_backends_v0.1/src"
cd "$ROOT"
echo "== corpus closure"
rexx corpus/corpus_check.rex corpus/circular_corpus_v2.csv | head -3
echo "== SLAM qualification"
rexx tests/test_slam.rex "$WORK|$P/oorexx_ml_v0.1-dev11|$ROOT/corpus/circular_corpus_v2.csv"
echo "== ChatGPT's task: compose, run, check two ways, break, learn"
rexx tests/test_compose.rex "$WORK|$P/oorexx_crypto_v0.8.3/src/crypto.cls|$P/oorexx_adb_v0.1-dev1/src/AdbAuth.cls"
echo "== ability before score on real contracts (rule from Claude (Opus 4.8))"
rexx tests/test_needs.rex "$WORK|$P/oorexx_crypto_v0.8.3/src/crypto.cls|$P/oorexx_adb_v0.1-dev1/src/AdbAuth.cls"
echo "== rx_mod_inverse condition check (fix found by SLAM, in the repository since 1f422d76)"
rexx tests/test_modinv.rex "$WORK|$P/oorexx_crypto_v0.8.3/src/crypto.cls|CHECK|$WORK/modinv.db|v0.8.3"
echo "== SLAM chooses its own path (ChatGPT's third task)"
rexx tests/test_choose.rex "$WORK|$REPO|$ROOT/tests/fixtures/standalone_pool.txt"
echo "== FDSqrt runs until the answer does not change (bug found by SLAM, ChatGPT's fourth task): both copies"
for v in dev8 dev5; do
  rexx tests/test_fdsqrt.rex "$WORK|$P/fd_door_micro_motion_v0.2-$v/src/FDDoorMicroMotion.cls|$P/oorexx_vision/src/Vision.cls|CHECK|$WORK/fdsqrt_$v.db|$v"
done
echo "== the door code that uses FDSqrt: standard deviation and gradient size"
for v in dev8 dev5; do
  REXX_PATH="$P/fd_door_micro_motion_v0.2-$v/src:$FOREIGN/rexx:$REXX_PATH:$REXX_BINDIR" rexx tests/test_fdsqrt_door.rex "$WORK|CHECK|$WORK/fdsqrt_door_$v.db|$v"
done
echo "== Gemini's two questions: a stated tie rule; a false result lowers a score without wiping its prior"
rexx tests/test_ties.rex "$WORK"
echo "== PROVED: a tier above TESTED (certificates checked in exact rationals, ooRexx Maths v0.8 CERTIFIED route)"
REXX_PATH="$REXX_PATH:$P/oorexx_maths_v0.8/rexx" rexx tests/test_proof.rex "$WORK|$P/fd_door_micro_motion_v0.2-dev8/src/FDDoorMicroMotion.cls|$ROOT/tests/fixtures/fdsqrt_fixed14.cls|$P/oorexx_vision/src/Vision.cls|$P/oorexx_crypto_v0.8.3/src/crypto.cls|$P/oorexx_adb_v0.1-dev1/src/AdbAuth.cls"
echo "== which tool wrote which code: provenance, a habit found by shape, outcomes by tool (needs git history)"
REXX_PATH="$REXX_PATH:$P/oorexx_maths_v0.8/rexx" rexx tests/test_provenance.rex "$WORK|$REPO"
RT="$P/oorexx_reasoned_thought_v0.1/src"
echo "== SLAM's evidence argued by the Reasoned Thought engine; SLAM's actions resting on its conclusions"
REXX_PATH="$REXX_PATH:$P/oorexx_maths_v0.8/rexx:$RT" rexx tests/test_reasoning.rex "$WORK|$REPO"
echo "== legislation -> small model -> SLAM -> Reasoned Thought: Computer Misuse Act 1990 (XML), CPS guidance, made-up cases"
REXX_PATH="$REXX_PATH:$RT" rexx tests/test_law.rex "$WORK|$ROOT"
echo "== did Gemini apply its own stated standard evenly? (the Reasoned Thought standard-application audit, unchanged)"
REXX_PATH="$REXX_PATH:$RT" rexx tests/test_gemini_standard.rex
echo "== one set of events, many offences: the shared word list (gate 6), the Mrs P case, the Computer Misuse Act in E.W. and S."
REXX_PATH="$REXX_PATH:$RT:$(dirname "$(command -v rexx)")" rexx tests/test_screen.rex "$WORK|$ROOT|$REPO"
echo "== second language: the Java reader (fixture compiled by javac first, so it is real Java)"
E="$REPO/examples"
ATM="$E/federationbank_java_atm_v0.1.9"
mkdir -p "$WORK/javac" "$WORK/atm/c" "$WORK/atm/p"
javac -d "$WORK/javac" "$ROOT/tests/fixtures/Shapes.java"
rexx tests/test_java.rex "$WORK|$ROOT/tests/fixtures/Shapes.java|$ATM|$E/federationbank_engine_v0.9.1/src/FederationBankAtmGateway.cls"
echo "== one rule, two languages: run the real ATM (Java) and the real bank (ooRexx) on the cases SLAM chose"
find "$ATM/src/main/java" -name '*.java' | xargs javac --release 17 -d "$WORK/atm/c"
javac --release 17 -cp "$WORK/atm/c" -d "$WORK/atm/p" "$ROOT/tests/rules/OfflineRuleProbe.java"
java -cp "$WORK/atm/c:$WORK/atm/p" OfflineRuleProbe > "$WORK/probe_java.txt"
# The engine's dependencies at the nearest versions in the repository (its DEPENDENCIES.txt names
# security_effect 0.10, queue_fabric 0.9-dev4, db_skeleton 0.45, civicport 0.12, which are not here).
FB="$E/federationbank_engine_v0.9.1/src:$P/security_effect_v0.14/src:$P/security_effect_v0.14/runtime:$P/legal_effect_v0.14/src:$P/institutional_policy_v0.8/src:$P/oorexx_queue_fabric_v0.9-dev5/src:$P/alchemy_objects_v0.8/src:$P/oorexx_crypto_v0.1/src:$P/oorexx_db_skeleton_v0_46:$P/civicport_v0.14/src:$P/oorexx_jms_queue_bridge_v0.1-dev7-fb1/src"
(cd "$WORK" && REXX_PATH="$FB" rexx "$ROOT/tests/rules/offline_rule_probe.rex" > "$WORK/probe_rexx.txt")
rexx tests/test_rules.rex "$WORK|$E/federationbank_engine_v0.9.1/src/FederationBankAtmGateway.cls|$ATM/src|$WORK/probe_rexx.txt|$WORK/probe_java.txt"
echo "== Body Slam: how the estate hangs together (each label proved by an interpreter run; the scanner against RxLexer on real files)"
rexx tests/test_bodyslam.rex "$WORK|$REPO|25"
echo "== third language: C++ (needs OOREXX_SRC: an ooRexx source tree; RX2CPP_ROOT: animatedads/oorexx's oorexx2cpp; Boost headers)"
if [ -n "${OOREXX_SRC:-}" ] && [ -n "${RX2CPP_ROOT:-}" ] && [ -d "${OOREXX_SRC}/interpreter" ]; then
  g++ -std=c++17 -fsyntax-only "$ROOT/tests/fixtures/shapes.cpp"
  BIF="$RX2CPP_ROOT/external/bif"
  REXX_PATH="$ROOT/tests/bif:$REXX_PATH" rexx tests/bif/bif_compare.rex "$OOREXX_SRC/interpreter|$BIF/native/rxbif.cpp|$BIF/tests/differential.cpp|$WORK/bif_cases.txt" > "$WORK/bif_compare.log"
  ${CXX:-g++} -std=c++17 -O1 -I"$RX2CPP_ROOT/include" -I"$BIF/native" "$BIF/native/rxbif.cpp" "$ROOT/tests/bif/NativeSide.cpp" -o "$WORK/native_side"
  "$WORK/native_side" "$WORK/bif_cases.txt" > "$WORK/bif_native.txt"
  rexx tests/bif/interp_side.rex "$WORK/bif_cases.txt" > "$WORK/bif_interp.txt"
  REXX_PATH="$ROOT/tests/bif:$REXX_PATH" rexx tests/test_cpp.rex "$WORK|$ROOT/tests/fixtures/shapes.cpp|$OOREXX_SRC/interpreter|$BIF|$ROOT/tests/fixtures/Shapes.java|$WORK/bif_cases.txt|$WORK/bif_interp.txt|$WORK/bif_native.txt"
else
  echo "SKIP C++: set OOREXX_SRC and RX2CPP_ROOT to run it"
fi
echo "== fourth language: NetRexx (needs NETREXX_HOME: the NetRexx 5 distribution; OOREXX_SRC; SYSUTILS_NRX: sysutils.nrx)"
if [ -n "${NETREXX_HOME:-}" ] && [ -n "${OOREXX_SRC:-}" ] && [ -n "${SYSUTILS_NRX:-}" ]; then
  sh tests/netrexx/qtime_pair.sh "$NETREXX_HOME" "$OOREXX_SRC" "$WORK/qtime"
  sh tests/netrexx/translate_all.sh "$NETREXX_HOME" "$SYSUTILS_NRX" "$WORK/n2j"
  rexx tests/netrexx/translate_pairs.rex "$WORK/n2j|$WORK/translate.db|$WORK/translate_summary.txt"
  rexx tests/test_netrexx.rex "$WORK|$NETREXX_HOME/examples/ibm-historic/qtime.nrx|$OOREXX_SRC/samples/qtime.rex|$SYSUTILS_NRX|$WORK/qtime/qt_nrx.txt|$WORK/qtime/qt_rexx.txt|$WORK/translate_summary.txt"
else
  echo "SKIP NetRexx: set NETREXX_HOME, OOREXX_SRC and SYSUTILS_NRX to run it"
fi
echo "== compiler code: BOLT (needs LLVM_SRC: an llvm-project tree holding bolt/; RX2CPP_ROOT)"
if [ -n "${LLVM_SRC:-}" ] && [ -n "${RX2CPP_ROOT:-}" ] && [ -d "${LLVM_SRC}/bolt" ]; then
  rexx bin/slam.rex ingest "$WORK/bolt.db" "$LLVM_SRC/bolt"
  rexx bin/slam.rex ingest "$WORK/rx2cpp.db" "$RX2CPP_ROOT/core" "$RX2CPP_ROOT/rules" "$RX2CPP_ROOT/hybrid" "$RX2CPP_ROOT/native" "$RX2CPP_ROOT/external" "$RX2CPP_ROOT/inspector" "$RX2CPP_ROOT/kernel"
  rexx tests/llvm/next_node.rex "$WORK/next_node.txt|BOLT=$WORK/bolt.db>$WORK/bolt.db@KIND,KIND+,SKELETON,SKELETON+,FAMILY,FAMILY+|RX2CPP_SELF=$WORK/rx2cpp.db:REXX>$WORK/rx2cpp.db:REXX@KIND,KIND+,SKELETON,SKELETON+|BOLT_TO_RX2CPP=$WORK/bolt.db>$WORK/rx2cpp.db:REXX@KIND,KIND+,SKELETON,SKELETON+"
  rexx tests/test_llvm.rex "$WORK/bolt.db|$WORK/rx2cpp.db|$WORK/next_node.txt"
  echo "== identical code folding, learned from BOLT's IdenticalCodeFolding"
  rexx tests/test_fold.rex "$WORK|$ROOT/tests/fixtures|$WORK/bolt.db|$WORK/rx2cpp.db"
else
  echo "SKIP BOLT: set LLVM_SRC and RX2CPP_ROOT to run it"
fi
echo "== runtime libraries: LLVM libc and libc++ (needs LIBC_SRC: an llvm-project tree holding libc/ and libcxx/; about 6 minutes)"
if [ -n "${LIBC_SRC:-}" ] && [ -d "${LIBC_SRC}/libc" ] && [ -d "${LIBC_SRC}/libcxx" ]; then
  rexx bin/slam.rex ingest "$WORK/libc.db" "$LIBC_SRC/libc/src" "$LIBC_SRC/libc/include"
  rexx bin/slam.rex ingest "$WORK/libcxx.db" "$LIBC_SRC/libcxx/include" "$LIBC_SRC/libcxx/src"
  rexx tests/llvm/next_node.rex "$WORK/libc_node.txt|LIBC=$WORK/libc.db>$WORK/libc.db@KIND,KIND+,SKELETON+|LIBCXX=$WORK/libcxx.db>$WORK/libcxx.db@KIND,KIND+,SKELETON+|LIBC_TO_LIBCXX=$WORK/libc.db>$WORK/libcxx.db@KIND,KIND+,SKELETON+|LIBCXX_TO_LIBC=$WORK/libcxx.db>$WORK/libc.db@KIND,KIND+,SKELETON+"
  rexx tests/test_libc.rex "$WORK/libc.db|$WORK/libcxx.db|$WORK/libc_node.txt"
else
  echo "SKIP libc: set LIBC_SRC to run it"
fi
echo "== unit tests SLAM writes: ooTest and JUnit (needs OOTEST_ROOT: an unzipped ooTest snapshot; JUNIT_CP and NETREXX_HOME for JUnit; about 40 minutes)"
if [ -n "${OOTEST_ROOT:-}" ] && [ -f "${OOTEST_ROOT}/ooTest.frm" ]; then
  sh tests/unit/qualify.sh "$WORK" "$REPO" "$OOTEST_ROOT" "${JUNIT_CP:-}" "${NETREXX_HOME:-}"
  rexx tests/test_unit.rex "$WORK"
else
  echo "SKIP unit tests: set OOTEST_ROOT to run it"
fi
