# ooRexx Terminal Machine Gopher sphere v0.5

This is the project continuity sphere for the generic ooRexx Terminal Machine. TN5250/IBM i remains a first-class personality; IBM 3270/TN3270/TN3270E is the P0 implementation line.

Start with `ref.terminal-machine.3270-current`, `ref.terminal-machine.architecture`, `ref.terminal-machine.one-writer`, `ref.terminal-machine.known-state`, and `ops.terminal-machine.continuation`.

The current 3270 delivery documented here is `oorexx_terminal_machine_v0.22-candidate15.zip`, SHA-256 `9153b098543b3d00d334aed5d479b7541e8243138a20d3270700851cd0a1eec7`. Candidate15 corrects the s3270 differential fixture exposed by an independent ooRexx 5.3.0 r13196 run and enforces exact ReadBuffer row geometry so malformed captures cannot shift later field addresses.

The sphere is documentation and reasoning memory. It grants no terminal-mutation, credential, MVS, Hercules, Queue Fabric, RPC, ConnectSelector, Socket Provider, or s3270 authority.

Candidate14's complete-response status/keyboard binding remains intact. The next gate is an exact-r13196 rerun of candidate15, followed by live ED209Z/ED209ZZ differential evidence.
