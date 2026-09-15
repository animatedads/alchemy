# General ooRexx Deployment v0.1-dev2

This checkpoint implements the common deployment authority needed by Audio workers now and by MCP/Wire hosted components later. Deployment reconciles declared state with observed target state and performs a fresh verification pass after mutation.

`NativeDeployment.cls` makes host-native repair a general contract: reuse a supplied native artifact only when its target probe succeeds, otherwise rebuild from supplied source when policy permits and probe again. `HostedModuleDeployment.cls` defines the common hosted lifecycle for MCP, Wire and future modules.

`deploy_tree.sh` supplies idempotent, content-addressed local/SSH staging. `deploy_hosted_module.sh` deliberately refuses to call a module live unless package-load, activation and live-probe stages all occur. On HTTPS Server v0.4.4 route activation is compose-before-start because route registration is immutable after server start.

Audio V9 dev2 is the first downstream consumer. It reuses the already-installed exact r13196 on the current fleet and repairs Foreign Runtime ABI mismatch by target-native rebuild only where the real load probe fails.
