# Validation — ooRexx Memory Fabric v0.1-dev6

Qualified against the supplied ooRexx 5.3.0 r13196 package.

Native connector rebuild:

```sh
make -C native clean all OOREXX_INCLUDE=/path/to/r13196/usr/local/include
```

Environment qualification:

```sh
REXX_BIN=/path/to/r13196/usr/local/bin/rexx tests/environment_test.sh
```

Observed passes:

```text
PASS memory.fabric/0.1
PASS memory.fabric object snapshot epoch
PASS memory block connector
PASS memory fabric provider lifecycle
PASS memory block lifecycle + MI attachment fencing
PASS memory.fabric.paging/0.1 RexxOS MI large-page backing contract
PASS registered.job.economic/0.1
PASS memory.fabric multi-provider capacity
PASS registered.job.execution-context/0.1
PASS: Memory Fabric snapshot epochs + native MU memory-block bag + provider/bag lifecycle + MI attachment fencing + RexxOS paging + service/economic/execution-context qualification
```

Paging qualification covers pinned-page refusal, stale transfer-plan fencing, dirty swap-out, clean no-copy eviction, exact swap-in, dirty rewrite to retained backing, MI epoch restart/rebind, old attachment fencing, recovery obligation projection and MU bag owner-epoch reincarnation.

The qualification byte helpers are not the production data path. Production page movement remains below `memory.fabric.paging/0.1` in the native QEMU/shared-memory/DMA implementation.
