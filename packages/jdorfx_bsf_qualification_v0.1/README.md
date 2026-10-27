# JDORFX / BSF4ooRexx850 interpreter qualification v0.1

This is an **independent, fail-closed** three-phase qualification harness. Authenticated Rasen Falcon lane: `jdorfx-bsf-qualification`. It does not change, adopt or claim ownership of the `rx2cpp` compiler.

## Phases

- `native`: compiles the existing `stalecrash` / `validgc` fixtures from a pinned `animatedads/oorexx/oorexx2cpp` checkout; each iteration checks immediate `CheckCondition=1`, `SYNTAX 88.922`, forced-GC survival, and valid-call control.
- `bsf`: runs **interpreted** existing `bsf_demo` and `bsf_callback` fixtures, including Java objects, a `Comparator` callback and Java-thread `Runnable`. Compiled parity is independently exercised by `oorexx2cpp/native/test_bsf.sh`; this test makes no compiled-code claim.
- `jdorfx`: runs a **specified real upstream** JDORFX sample with the selected interpreter/bridge/JDK/JavaFX/display. Successful exit is a smoke test, **not** image equivalence, animation timing or command-set acceptance.

Prerequisites (absolute paths): `OO_ROOT` points at an installed ooRexx prefix; for native and BSF, `RX2CPP_ROOT` points at the `oorexx2cpp` directory of a pinned `animatedads/oorexx` checkout. For BSF and JDORFX, `BSF_HOME` contains `BSF.CLS`, `BSF_JAR` is one exact selected bridge JAR, `BSF_NATIVE_LIBRARY` is an architecture-compatible `.so`, with `JAVA_HOME` optional. The script does **not** pick a duplicate dependency via `find | head -1`. For JDORFX specify `JDORFX_HOME`, `JDORFX_SCRIPT` (one actual sample), a working GUI display, and JavaFX from a bundled JDK or explicit `JAVAFX_MODULE_PATH` / configured `JAVAFX_CLASSPATH`. External module path is passed through `JAVA_TOOL_OPTIONS`; JAR/classpath users must configure their JVM explicitly.

```sh
export OO_ROOT=/absolute/ooRexx RX2CPP_ROOT=/absolute/animatedads/oorexx/oorexx2cpp
REPEATS=3 ./bin/qualify.sh native
export BSF_HOME=/absolute/bsf4oorexx BSF_JAR=/absolute/bsf4ooRexx-850-bin.jar
export BSF_NATIVE_LIBRARY=/absolute/libBSF4ooRexx850.so
REPEATS=3 ./bin/qualify.sh bsf
export JDORFX_HOME=/absolute/JDORFX JDORFX_SCRIPT=/absolute/JDORFX/selected-sample.rex
REPEATS=3 ./bin/qualify.sh jdorfx
bash tests/run.sh
```

`tests/run.sh` validates shell syntax and **fail-closed preflight**, not runtime. Record exact tested ooRexx revision/patch, selected JAR/BSF/JDORFX archive checksum, JVM/JavaFX version, ABI, script checksum, logs, GC and callback results. Use the **new Ismaili release**, not Schaller's 2024 implementation, for the new command acceptance; the user-supplied announcement's 100 JDOR and 140 JDORFX command counts are **not verified by this package**.

Source: `animatedads/oorexx/oorexx2cpp/ootest/interpreter_bugs/TICKET_bug2.md` and `BUG_REPORTS.md`: r13284 still had a native-argument stale activation crash, and the local patch survived 3/3 trials versus unpatched crash 3/3. This makes BSF a plausible affected caller, **not proof of the historical BSF/JDORFX crash cause**. Upstream thesis page: https://wi.wu.ac.at/rgf/diplomarbeiten/.

## Blockers

No ooRexx/BSF/JDORFX installed in the validation container; phase runtime results are **NOT_RUN**. The current Ismaili source archive checksum and command-level visual/animation evidence are also missing; upstream native-argument patch merge is not confirmed. Do not describe this as production-qualified or as an approved Wire UI renderer. See `qualification/STATUS.md`.
