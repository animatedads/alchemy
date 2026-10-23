# Candidate20 validation status

Prepared: 2026-10-15

Static/integration construction is based on the exact Library packages:
Memory Fabric dev10, RTO2 Grid dev14 (including Object Queue Fabric dev8 and
Cluster Object Memory Fabric Transport v0.2), and Audio V9 dev20 candidate19.

The executable qualification test is
`tests/test_audio_v9_memory_horizon_execution.rex`.

Expected proof points:

- adaptive horizon demand raised by an ordinary sparse-array `AT` read;
- next logical range resolves only to a current fenced Memory Fabric block;
- placement guard is mandatory before MOVE;
- Queue Fabric MOVE contains block identity but not destination PCM payload;
- runner moves NODE-A -> NODE-B and executes beside B-local data;
- demand is satisfied only after MOVE acknowledgement;
- cursor window advances to the next block without logical collapse;
- provider reincarnation fences the old route.

Runtime qualification is pending in this execution container because the prior
conversation-uploaded ooRexx r13196 `.deb` no longer has a downloadable backing
file in the current container.  No runtime PASS is claimed here.
