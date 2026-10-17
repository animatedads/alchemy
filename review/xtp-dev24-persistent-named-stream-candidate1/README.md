# XTP dev24 persistent named-service stream — Candidate 1

**Isolated native C++ development candidate; not an ED209 or SSH production promotion.**

Exact base: `oorexx_xtp_v0.1-dev24.zip` SHA-256 `9599ee6fc2d8a0fb2df5285ca28c199af7782e07eb44c422690325ee7315d331`.
Apply the preceding named-service SORT correction from parent review commit `361ba8bb20a188a78b2215361d9a342df59ad97d` before this patch.

`xtp_dev24_stream_candidate1.patch.xz` is a source patch containing:
- New `xtp::NamedServiceStreamSender` / `NamedServiceStreamListener` native C++ API.
- FIRST named-service admission and acknowledged persistent DATA under one XTP KEY.
- Peer/key/priority pinning, ordered binary writes, bounded sizes and explicit EOM.
- New native loopback regression and a detailed contract/qualification document.
- New `make test-named-stream` target.

To apply after the previous priority overlay, from inside the extracted XTP directory:

```bash
xz -dc /path/to/xtp_dev24_stream_candidate1.patch.xz | patch -p1
make -j4 all test-named-stream
make test-service
```

**Local evidence:** g++ C++17 `-Wall -Wextra -Werror` builds PASS; persistent stream loopback PASS in five repeats; existing `make test-service` PASS; ooRexx 5.3.0 r13196 native priority/SocketSelector regressions PASS; complete XTP suite including native ooRexx PASS. The patch also passed `patch -p1 --dry-run` against the exact preceding overlay.

**Security boundary:** UDP source address + XTP KEY are not cryptographic authentication. This path is a single-session, unicast IPv4 UDP experiment with no live WAN/raw36/L2 qualification, no persistent checkpoint, no session multiplexing, no crypto authorization, and no SSH gateway adoption. Preserve deployed Candidate 2 and emergency access.

See the full replacement-source ZIP `xtp_dev24_named_service_stream_candidate1.zip` delivered alongside this patch for easier review.
