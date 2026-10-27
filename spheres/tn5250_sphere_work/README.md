# ooRexx Terminal Machine Gopher sphere v0.4

This is the project continuity sphere for the generic ooRexx Terminal Machine. TN5250/IBM i remains a first-class personality; IBM 3270/TN3270/TN3270E is the P0 implementation line.

Start with `ref.terminal-machine.3270-current`, `ref.terminal-machine.architecture`, `ref.terminal-machine.one-writer`, `ref.terminal-machine.known-state`, and `ops.terminal-machine.continuation`.

The current 3270 delivery documented here is `oorexx_terminal_machine_v0.22-candidate14.zip`, SHA-256 `2ef05bff6cb9df66041c060d7aceb31e60783948c5a51e9f211b2da7d91111f6`. Candidate14 binds complete s3270 peer-script evidence—ReadBuffer data, 12-field status and ok/error completion—into one reference snapshot and extends differential comparison to keyboard state. Candidate12 remains the inherited protocol/model/ownership execution baseline.

The sphere is documentation and reasoning memory. It grants no terminal-mutation, credential, MVS, Hercules, Queue Fabric, RPC, ConnectSelector, Socket Provider, or s3270 authority.

MVS Intention Runner dev10 now targets candidate13 and includes a candidate13 compatibility harness, but its authoring qualification leaves r13196 and live ED209Z/ED209ZZ execution unclaimed. Candidate14 does not alter TN3270LiveSession. The next live gate is candidate14 under r13196 followed by complete-response Terminal Machine↔s3270 semantic differential qualification on ED209Z and independently ED209ZZ.
