# Computer v0.1-dev8 — output exception evidence correctness

- Output backpressure during a live run no longer permanently marks observation incomplete.
- Final stdout/stderr scan drains outstanding bytes, checking for a literal exception string even after a burst exceeds one sample.
- Streams are independently bounded to 64 MiB examined per rule; exceeding the budget yields an explicit `measurement_unavailable` event and exit code 6, not an ungrounded clean result.
- Strings crossing 1 MiB read boundaries are detected.
- Five new Python regression cases in `tests/test_dev8.py`.
- No daemon, no background monitoring, no remote escalation; existing authority remains unchanged.
- Submission through the Alchemy Autobuild branch protocol, not a direct merge to main.
