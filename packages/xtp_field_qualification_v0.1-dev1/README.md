# XTP field qualification kit v0.1-dev1

**Architecture:** Tom Dyer (decision D-07). **Coding:** Claude (Opus 5.5). **Written by:** Claude (Opus 5.5), 29 October 2026.

The field run for XTP dev36. It is the first run of XTP's protected named-service sessions between real hosts, not one host talking to itself. It produces the receipt that the other lanes are waiting for before they mark internode transport ready (REQ-00001637, REQ-00001867, REQ-00001915, REQ-00002025).

## What it tests

`run_protected_matrix.sh` covers every directed pair of the enabled ED209 hosts in `inventory.tsv`, over two carriers:
- native XTP (IPv4 protocol 36, level 3);
- XTP over UDP (level 4).

Each pair-and-carrier makes three opens to the named service `svc.field`, whose key is made for the run and removed after it:

| # | Open | Must |
|---|---|---|
| 1 | clear, with no key | be refused by the listener: `AUTH_REQUIRED` (DIAG 17) |
| 2 | the right key id with a wrong secret | be dropped by the listener: "open tag did not verify" |
| 3 | the right key | carry 1 MiB each way, encrypted, byte-exact. Both ends must agree on the key, and the digests at both ends must match |

A pair passes only if all three checks pass. Checks 1 and 2 show that the far end enforces the protection, not just that it is reachable. Check 2 is judged from the listener's own log, so an unreachable host can never pass it.

Every opener and acceptor prints its dev36 protection evidence (`docs/SECURITY.md` of `oorexx_xtp_v0.1-dev36`, "Protection evidence"). The receipt keeps both lines for every passing pair, in `evidence.txt`.

A failure is named:
- `NO_RESPONSE_OR_FILTERED`: nothing came back;
- `LOCAL_PERMISSION`: protocol 36 without `CAP_NET_RAW`;
- `CLOCK_SKEW`: a protected open checks the clocks to within 30 s;
- `LISTENER_NOT_STARTED`;
- otherwise, the first `FIELD_FAIL` line.

A host that is not x86-64 is reported as `UNSUPPORTED_ARCH`, and its pairs are skipped.

## How it touches the hosts

- **Access:** only through `/home/hc3/alchemy-autobuild/sshnode.sh`, never `ssh` or `scp` directly. This is the same rule as `qualification/field` in the XTP package.
- **Files:** on each host, one directory, `$HOME/xtp-field-dev36`, holding the binary and the run's two key files (mode 600). It is removed at the end. Nothing is installed.
- **sudo:** only with passwordless sudo, and only to give that one binary `cap_net_raw`. If `setcap` is missing, sudo instead runs that binary for the protocol-36 tests.
- **This machine:** results go under `results-protected-YYYYMMDD-HHMMSS/` in this package. The keys are deleted there too, once the run ends.

## The binary

`bin/xtp-field` is one static x86-64 binary. It is built from `src/xtp_field.cpp` and the libxtp sources of `oorexx_xtp_v0.1-dev36` (commit 4ee94748), with glibc 2.39 and OpenSSL 3.0.13 linked in.

It is committed, with `bin/xtp-field.sha256`, for three reasons:
- the ED209 hosts run five clouds' Linux images, and a binary built on a newer distribution would not load on the older ones;
- no compiler or library has to be installed anywhere;
- every host runs the same bytes, and their hash is in the receipt.

The script refuses any binary that does not match the hash. `make` rebuilds it (it needs static glibc and libcrypto); `make test` checks the hash and runs the whole controller on one machine (below).

It uses libxtp itself (`open_session`, `SessionListener`, `KeyTable::load_file`), not a separate packet engine. It takes numeric addresses only: the linker's warnings about hostname lookup concern code in libcrypto that it never calls.

## Running it (the operator's machine)

```
cd ~/alchemy-autobuild/xtp-field-dev36/alchemy/packages/xtp_field_qualification_v0.1-dev1
nohup bash run_protected_matrix.sh > ~/alchemy-autobuild/xtp-field-dev36/run.log 2>&1 &
```

It ends with `FIELD_PROTECTED_COMPLETE results=<dir>`; `<dir>/SUMMARY.txt` is the receipt. With 8 hosts, 112 pair-and-carrier runs take roughly 20 to 40 minutes.

Optional settings:
- `XTP_FIELD_NODES="ED209A ED209C"` limits the hosts;
- `XTP_FIELD_BYTES` changes the transfer size;
- `XTP_UDP_BASE_PORT` (default 43600) sets the UDP ports used, which are 43600 to 44599.

## Local test

`make test` runs the controller end to end against a stand-in `sshnode.sh`, where each "node" is a directory on this machine. It checks:
- three reachable nodes: every pair passes on both carriers;
- nothing is left on the nodes after the run;
- the receipt exists, the run's keys are gone, and the only 64-hex values in any log are data digests;
- an unroutable destination is reported `NO_RESPONSE_OR_FILTERED`, never passed;
- an aarch64 node is reported `UNSUPPORTED_ARCH`.

## What a pass does and does not show

**It shows** that two real hosts across the internet ran encrypted named-service XTP sessions, that each end enforced the service's protection against a clear open and a wrong key, and the throughput and round-trip time it measured.

**It does not show:**
- **MU↔MI over L2 (EtherType 0x817D).** MIs are RexxOS guests with no shell. That needs the MU's own L2 to its MIs, a later step.
- **TLS above the stream.**
- **LDAP keys.** Here the keys come from a key file. LDAP is tested on one host, in `oorexx_xtp_v0.1-dev36`.
- **aarch64 hosts.** They are reported as `UNSUPPORTED_ARCH`. A binary for them needs OpenSSL built for aarch64.
