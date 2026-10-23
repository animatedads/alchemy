# SSH-over-XTP v0.1 Candidate 4 — named-service FIRST integration

**Development-only source candidate.** Does not replace the field-qualified Candidate 2 on ED209F/openSUSE or edit their routes, credentials, firewall or Grid services.

This candidate rebases the independent SSH bridge onto **unaltered XTP dev24**, consuming its native service `FIRST` API rather than placing a symbolic service envelope into SSH data. The gateway reads an existing ooRexx Service Descriptors TSV snapshot and an Operational Degradation Planner dev3 TSV snapshot; no IP addresses are stored in a service descriptor.

Native XTP `FIRST` admission must match the locally registered `ssh.management` service point before the XTP receiver sends CNTL. The registered class is sourced only from the gateway's local service file. The planner must allow the class in the requested operating state. Unknown, disabled or mismatched services and unavailable/unsupported policies fail closed. Registered-class THROTTLE/SAMPLE/AGGREGATE, capacity scopes and nontrivial fallback/protected-path constraints are **refused**, not falsely claimed implemented.

The existing independent 256-bit shared-secret HMAC challenge/response and local OPEN/LOCKED/SEALED gate remain unchanged for SSH authentication and active-session policy. OpenSSH itself verifies its own remote host key and user public-key authentication. The gateway still serves one client/session per launch.

## Build / tests

    make clean all
    make test
    python3 tests/test_openssh.py  # conditional: requires OpenSSH binaries; NOT_RUN is rc=77

When installing on AlmaLinux, **build locally** (`make clean all`). Never copy an openSUSE binary that requires newer GLIBC/GLIBCXX versions. `make test` executes the UDP loopback transport/policy/regression tests, not a WAN raw36 qualification.

## Example gateway invocation (development only)

Provide a root-owned `services.tsv` and `operational.tsv` in a trusted directory. `examples/` contains the matching dev24 service/class schema, but must be installed separately and with trusted ownership. The logical service peer `gateway_rx` must exist in `XTP_ROUTE_FILE`; IP addressing belongs only in that route table.

    XTP_ROUTE_FILE=/path/to/routes.tsv \
    ./bin/ssh-xtp gateway --rx-peer gateway_rx --tx-peer client_rx \
      --service ssh.management --key-file /path/to/shared.hex \
      --client-id ed209f --policy-file /etc/ssh-xtp/state \
      --service-registry /etc/ssh-xtp/services.tsv \
      --operational-registry /etc/ssh-xtp/operational.tsv \
      --operating-state normal --ssh-port 22

Client OpenSSH `ProxyCommand` invokes `ssh-xtp client` as in Candidate 2, with `--service ssh.management`; this is the *native XTP named service*, not a remote TCP port. The client's route peer remains a logical XTP route key.

Gateway registries are verified regular bounded files owned by root, not writable by group/others, and opened with O_NOFOLLOW. There is an explicit `--allow-user-owned-registry-for-test yes` override only for local tests. The operational state is sampled at listener construction; restarting/requalifying is required when it changes. The SSH LOCKED/SEALED master switch remains independently dynamic.

**No WAN qualification yet for Candidate 4.** Prior ED209F WAN proof belongs only to Candidate 2. See `docs/DEV22_UPSTREAM_REVIEW.md` for upstream issues and why persistent native KEY contexts are not yet claimed.

## Candidate 4 rebase (2026-10-16)

This package rebases the standalone SSH-over-XTP native bridge on **unaltered XTP v0.1-dev24**, **Operational Degradation Planner v0.1-dev3**, and **Service Descriptors v0.1-dev2** from the Library. Those upstream packages already contain the dev22 native routine registration/build repairs. Do **not** reapply the old candidate patches. The application bridge and its local security policy are separate from the XTP core.

**Boundary:** dev24 admits named services at XTP FIRST, but does not yet provide a persistent FIRST→DATA/KEY stream context suitable for all SSH application frames. This bridge retains transaction-per-frame semantics and explicitly does not claim the persistent-context fast path. Native XTP owner must supply that API before replacing the bridge strategy.

**Qualification:** from clean extraction `make clean all && make test`, and optionally `python3 tests/test_openssh.py` where OpenSSH is available. Production ED209F/openSUSE still uses field-qualified Candidate 2, not this package. No firewall, systemd, credentials or live processes are changed by this delivery.

**Operational planner:** only policies enforceable by this gateway are admitted. Capacity scope (per-context, max parallel, aggregate), fallback qualification, and upstream SAMPLE/AGGREGATE semantics are not promoted to an unconditional SSH permit; service tests remain conservative. dev3 class policy still supplies one authoritative class name per service.


## Git/autobuild submission provenance

The managed Git source submission retains the complete extracted upstream `vendor/` source trees while omitting redundant nested vendor ZIPs. `UPSTREAM_SHA256.json` retains the exact SHA-256 digests of those upstream distributions. Builds use the extracted sources, not the nested ZIPs. This is a development candidate and not ED209 WAN-qualified.
