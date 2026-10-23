# SSH-over-XTP Candidate 4 — XTP dev24 dependency adoption

- Upstream source: unmodified `oorexx_xtp_v0.1-dev24.zip`.
- Policy: unmodified `oorexx_operational_degradation_planner_v0.1-dev3.zip`.
- Service registration: unmodified `oorexx_service_descriptors_v0.1-dev2.zip`.
- The bridge consumes `SendOptions.service_name`, `ListenOptions.allowed_services`, `ReceiveResult.service_name` and the existing operational planner.
- Reuses service-first XTP admission and retains explicit HMAC challenge-response and OpenSSH key authentication.
- No class self-assertion, no IP address in service registry, and no changes to the underlying XTP route graph.
- Does not provide native context persistence or a KEY-only DATA fast path. Each bridge frame is separately sent as a named FIRST; this is a compatibility boundary, not the final architecture.
- Tested on loopback only, not ED209 WAN. Keep Candidate 2 field baseline.
- Separate upstream issue: `decode_named_service` throws for malformed descriptors and the listener `receive` loop does not catch before parsing. Bad FIRST can throw to caller.
- Current upstream dev24 `make test-service` checks static registration and C++ wire admission; the optional real r13196 native module roundtrip should also be part of upstream regression.
- Planner dev3 `make test` does not invoke `tests/test_capacity.cpp` even though it is shipped. Test it explicitly before claim of capacity qualification.

## Local qualification record

- `make clean all && make test`: PASS against exact vendored dev24/planner dev3 source.
- Six SSH bridge transport tests: PASS.
- Policy/audit tests: PASS.
- Named-service admission tests: 12 PASS, including three explicit unsupported-capacity-refusal checks.
- Separate upstream SDK test: XTP dev24 native ooRexx `.so` compiled under `-Werror` with provided r13196 headers; native named-service send/receive r13196 processes PASS.
- XTP dev24 C++ admission and operational tests: PASS.
- Planner dev3 `make test` and explicit `test_capacity.cpp`: PASS.
- OpenSSH loopback against Candidate 4: NOT_RUN (OpenSSH binary absent in this environment).
- Native raw36 ED209 WAN against Candidate 4: NOT_RUN.

Do not promote Candidate 4 based on inherited Candidate 2 WAN evidence.
