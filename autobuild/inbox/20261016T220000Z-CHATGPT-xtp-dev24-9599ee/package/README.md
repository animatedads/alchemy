# ooRexx XTP v0.1-dev24

Dev24 repairs and qualifies the ooRexx named-service binding while retaining XTP-owned priority, RATE/BURST, multipath, multicast and ROUTE/XROUTE mechanics.

Applications select named services. IP addresses do not form service identity; they are carrier/route plumbing underneath XTP. Named service identity is carried in FIRST and admitted before the ordinary KEY/ROUTE fast path.

Operational priority is transport-neutral policy. XTP consumes planner decisions and enforces the XTP-owned portion, including SORT/DEADLINE, path/fallback admission and the per-context capacity cap. MAX_PARALLEL_CONTEXTS and AGGREGATE_CAP_PERCENT remain higher-layer orchestration/admission controls.

## dev24 binding repairs

- Registers `xtpNativeSendService`, `xtpNativeListenerOpenServices`, and `xtpNativeListenerLastService` in the ooRexx native routine table.
- Fixes the `-Werror=misleading-indentation` failure in the allowed-service parser.
- `XtpNamedServiceManager~listener` exposes `planner` and `operatingState`.
- Native ooRexx linking includes the operational planner archive.
- Shell tests are invoked through `bash`, so archive executable-bit loss is not an acceptance blocker.

Native raw36 and L2 qualification require `CAP_NET_RAW`; `CAP_NET_ADMIN` is not required unless the test changes interfaces or routes.
