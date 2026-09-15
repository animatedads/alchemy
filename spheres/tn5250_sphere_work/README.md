# ooRexx Terminal Machine / TN5250 Gopher sphere

This is the project knowledge sphere for the generic ooRexx Terminal Machine and its TN5250 / IBM i personality. It is documentation and reasoning memory, not executable Terminal Machine code and not terminal-mutation authority.

Start with `ref.terminal-machine.release-v021`, `ref.terminal-machine.architecture`, `ref.terminal-machine.one-writer`, `ref.terminal-machine.known-state`, and `ops.terminal-machine.continuation`. Durable exact-topic records are in `terminal-machine.lessons`.

The implementation baseline documented by this sphere is `oorexx_terminal_machine_v0.21.zip`, SHA-256 `64fe1cb3b80c2948779a71088dacc2be5edef7b581c99618035fd9b79d8830c5`.

With LLM Gopher v0.19-dev1, load both the Gopher core pack and this sphere pack before exact corpus lookup because this sphere deliberately inherits the bounded core lookup service. The sphere access policy permits read/exec only so Gopher can use those bounded retrieval services; it does not grant authority to mutate a live terminal.
