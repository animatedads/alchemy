# Wire application deployment v0.1 candidate 2

Native adapter source for four receiving modules: HTTPS Server v0.5, Wire UI Server v0.17.1, Queue Fabric Web Gateway v0.2, and General ooRexx Deployment v0.1-dev3.

The source is ooRexx, not a new Python/Java runtime. The `.wapp` signature verifier and immutable storage must be bound to the trusted Crypto + Deployment layer. This GitHub increment includes reusable native classes, module splice contract, reproducible test cases and the authoritative Wire runtime sphere article.

The exact **full replacement source files** and five native tests are packaged in the independently delivered `wire_application_deployment_v0.1_candidate2.zip`, SHA-256 `7e9d67d4a4f762cde64f4486615d6f8ee65894cad43dc6e25fea7176a57ab36b`. Do not claim that the four accepted original packages have been replaced by this commit: the original modules are not overwritten here.

**Qualified locally:** five native contract test programs and six `rexxc` compilation checks against ooRexx 5.3.0 r13196. **Not qualified:** a public network WebSocket + TLS session, remote RexxOS deployment, crash/restart journal replay, fully authenticated .wapp verifier, inflight session migration.

See `MODULE_WIRING.md` for the exact seams and `spheres/wire_ui_runtime_gopher_sphere_v0.2` for architectural authority.
