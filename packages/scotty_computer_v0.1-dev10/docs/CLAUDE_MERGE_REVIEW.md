# Claude Computer merge review — 2026-10-13

Input files: `Computer.wrapper` (the supplied no-extension shell wrapper), `Computer.rex`, `ComputerIntentions.cls`, and `ComputerTest.sh` in this directory's `claude_reference/`. Their source credits are retained as supplied: architecture Tom Dyer; coding Claude Sonnet 5.5.

## Observed test result

The four input files were mounted in a clean temporary directory, and `IntentionService.cls`, `IntentionProviders.cls` and the NLP sources from Library Intention Service v0.1-dev11 were made available. The provided `ComputerTest.sh` completed **39 PASS, 0 FAIL** under the uploaded ooRexx 5.3.0 r13196 extracted runtime. Thus the submitted first cut is runnable, despite its `UNTESTED` header.

## Useful engineering contributions

- A native ooRexx phrase provider preserving case-sensitive path slots.
- A readable help catalogue and explicit slot requirements.
- Local/remote disk and memory diagnostic intentions, with the SSH `--job-id` correlation interface.
- A deploy-ZIP transfer intention and an explicit confirmation command.
- A self-scoring test harness using a throwaway HOME rather than a normal user's live settings.
- A candid firewall placeholder rather than pretending provider-specific authority exists.

## Reasons for selective rather than literal merge

1. **Confirmation entropy and binding.** `ComputerKit~pendingSave` (Claude source lines 151–164) constructs short pseudo-random numeric tokens and stores an unbound original phrase; `pendingTake` (166–173) removes the file with shell `rm -f`. Dev2 instead uses 192-bit OS randomness, mode-0600 files, serialization under flock, 10-minute lifetime, one-time consumption, and an immutable preview fingerprint of the selected ZIP and authoritative SSH helper. It rechecks node mapping before transferring.
2. **Shell composition.** Claude uses `address system` with a manually quoted command built from paths and configured HOME; its safety filters reject several metacharacters but cannot establish general shell argument isolation. Dev2 uses a hex-only ooRexx-to-Python boundary and Python `subprocess.run([...])` argv. No raw user utterance is evaluated as shell source.
3. **SSH test authority.** Claude's test stub defines `node=x` and its case statement always takes the unknown-node branch, yet it exits successfully after echoing arbitrary arguments. That confirms the process was invoked but does not validate the actual SSH contract. Dev2's tests assert the exact `--job-id`, `NODE`, command, `--transfer` and path argument boundaries, while preserving the real attached script unchanged in `adapters/`.
4. **Discovery.** Claude's `ComputerFactory~build` explicitly registers a fixed catalogue. Dev2 retains the earlier per-invocation IntentionService discovery snapshot. Neither package should be presented as arbitrary general natural-language understanding or a complete specialist-plugin registry.
5. **File search.** The Claude latest-copy intent searches only matching filenames and orders by mtime. The existing dev1 engine also checks `.cls` members inside ZIP archives, with candidate semantic-version ordering. Dev2 retains that behavior.
6. **Firewall.** `Computer fix the firewall on ed209f` still fails closed. The attached `sshnode.sh` does not map ed209f; `cloudctl.sh` has provider-specific firewall operations, but there is no verified cross-provider authority binding for this request. No cloud ingress changes were executed.
7. **Test isolation.** The original self-scoring script leaves temporary directories behind. Dev2's qualification uses `trap` cleanup for native integration and Python `TemporaryDirectory` for unit tests; the original harness remains included solely as reference.

## Tested integration result

21 Python tests passed plus native ooRexx end-to-end qualification (including mock SSH argv and one-use ZIP confirmation). Native `Computer run tests` separately completed the package qualification. No live remote SSH session, transfer, or firewall change was performed.

## Future implementation

A specialist intention catalogue loaded on demand by capability advertisement (not an ever-growing command switch) is a separate subsequent increment. Keep `IntentionService` as authority and preserve the unchanged `sshnode.sh`, `cloudctl.sh` and the ConnectSelector service boundary.
