# v0.1-dev13 GTK demo handoff

This cut is a binary handoff for x86_64 Linux/glibc.  It contains a locally built SWI-Prolog 10.0.2 runtime, the compiled Alchemy native bridge, and an email-rule fixture in source and QLF form.

## Runtime layout

- `lib/libprolog_alchemy_native.so` — ooRexx/Alchemy bridge, linked to bundled SWI with an `$ORIGIN`-relative RUNPATH.
- `swipl/` — SWI-Prolog 10.0.2 install tree built from the supplied `swipl-10.0.2.tar.gz`, core-only (`SWIPL_PACKAGES=OFF`).
- `demo/email/email_rules.qlf` — compiled Prolog rule fixture.
- `demo/email/email_rules.pl` — readable authority for the demo rule.
- `demo/email/EmailDemoObjects.cls` — minimal live email object contract.

The consuming GTK application should add this package's `src` directory to `REXX_PATH` and its `lib` directory to the ooRexx native-library search path.  The native bridge locates bundled `libswipl.so.10` relative to itself.

This binary is architecture-specific.  Android/Termux or another CPU/ABI requires rebuilding from the included bridge source against the target ooRexx and SWI installations; do not reuse this x86_64/glibc `.so` there.

## Evidence in this build environment

- SWI-Prolog 10.0.2 configured and built successfully from the user-supplied source tarball.
- `libprolog_alchemy_native.so` compiled successfully against ooRexx 5.3.0 headers and SWI 10.0.2 headers/library.
- installed bridge RUNPATH is relative and resolves the bundled `libswipl.so.10`.
- bundled `swipl --version` reports 10.0.2.
- `email_rules.qlf` loads and exports `email_rules:route_email/2`.
- dependency-free Alchemy contracts pass 12/12.

Full ooRexx-to-SWI callback execution is still a host integration test for the GTK application because the authoritative external Alchemy Object / Foreign Object dependency package is intentionally not forked into this bridge package.
