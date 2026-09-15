# PDP-10 / KL10 Gopher sphere

Profile: `kl10`
Sphere: `kl10`

This pack is an engineering navigation layer for KL10 Model-B / TOPS-20 emulator development. It intentionally separates evidence into three tiers:

1. **Primary machine contract** — DEC processor and KL10 technical documentation plus recovered production microcode.
2. **Primary guest intent** — TOPS-20 V7 monitor, BOOT and POSTLD source at a fixed repository revision.
3. **Secondary implementation evidence** — independent emulator implementations used only after the first two tiers establish the required behavior.

The KL10 profile also loads the ooRexx language/service pack. The KL10 sphere explicitly inherits ooRexx service visibility, so source inspection may run under KL10 destination authority rather than requiring a switch to the ooRexx sphere.

Useful commands:

```sh
./gopher --profile kl10 context kl10
./gopher --profile kl10 help kl10
./gopher --profile kl10 open kl10.current-continuation
./gopher --profile kl10 search 041342 --sphere kl10
./gopher --profile kl10 search BLT --sphere kl10
./gopher --profile kl10 search PNRCOD --sphere kl10
./gopher --profile kl10 search NXM --sphere kl10
./gopher --profile kl10 examine source KL10IPL.cls --in <oorexxapis.zip> --nested <current/kl10-package.zip> --sphere kl10
```

The corpus stores concise engineering summaries and provenance URLs rather than redistributing scanned manuals. Project-continuity records are explicitly labelled as replay evidence and do not outrank DEC architecture or TOPS-20 source.


## 2026-09-02 checkpoint comparison
The recovered historical `pre_041342` fixture is now classified as an **event oracle, not a continuation state**. One-step execution reproduces the genuine `CST_AGE_ZERO` fetch event at `041342` and vector `044414`, but APR and several accumulator left halves diverge from the newly authentic 512K replay report. See `kl10.current-continuation` and `kl10.project-continuity`.
