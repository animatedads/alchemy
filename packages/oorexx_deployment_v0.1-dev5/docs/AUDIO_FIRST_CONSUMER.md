# Audio V9 as first consumer

The first executable consumer is Audio V9 Voice Recovery. The current seven-worker fleet already has x86_64 ooRexx 5.3.0 r13196 and unzip, so Deployment must not reinstall those merely because it can.

The known fault is the packaged Foreign Runtime v0.22.6 binary requiring GLIBC_2.38 while several workers provide older glibc. Audio dev2 therefore unpacks the authoritative source package, attempts a real ooRexx Foreign Runtime load probe, and rebuilds only `libforeign_runtime.so` on the target when that probe fails. Compatible workers reuse the supplied object. The spatial provider receives the same reuse-if-loadable-else-rebuild treatment.

Worker launch remains separate from repair. Reconcile/readiness may complete on every node while workers remain stopped; `--start` is an explicit application action after the readiness gate and corpus verification pass.
