# Rasen Falcon public role: site-only installation source (v0.4.5)

29 October 2026. Owner: `rasenfalcon-website`. Provider: General ooRexx Deployment `v0.1-dev4` and the Rasen Falcon owned public-role installer; no alternative deployment engine.

This executable source-slice assembler closes the prior **static site file-manifest** gap. It produces a deterministic `roles/public/files/` tree plus `roles/public/manifest.tsv` for 15 independently checked nonindexable preview files and `website/server/serve.rex` (16 files). The target locations are allowlisted under `/var/www/rasenfalcon/public/` and `/opt/rasenfalcon/public/server/`. Content, manifest paths and SHA-256 values are independently verified; provenance is from the source-locked site compiler. The assembler refuses symlinked, missing, extra, modified or otherwise unowned files. The public site adapter is parsed by the exact ooRexx 5.3.0 r13196 `rexxc` syntax compiler in an isolated local execution environment.

## Build and verify a review slice

From the root of the Rasen Falcon source candidate:

```sh
python3 handoff/deployment/public_role_slice.py assemble --output /tmp/rasenfalcon-review-20261029/site-install-slice
python3 handoff/deployment/public_role_slice.py verify --output /tmp/rasenfalcon-review-20261029/site-install-slice
RF_ROLE=public RF_RELEASE=/tmp/rasenfalcon-review-20261029/site-install-slice bash handoff/deployment/deploy.sh check-release
```

The last command MUST fail. This assembly intentionally does **not** create `services.txt`, `tests.tsv`, private certificate/key files, a systemd unit, a fake HTTPS listener, an anonymous fallback, or an ooRexx/Foreign Runtime native dependency closure. Those files must come from the qualified **own HTTPS** provider, the accepted SSC deployment and a reviewed public-role installation plan. `check-release` must be re-run against the combined role before an authorised non-production install. It is not permissible to make the check pass with dummy scripts or placeholder daemons.

`roles/public/public-slice.json` records `SOURCE_SLICE_ONLY_NOT_INSTALL_READY`, not `INSTALLED` or `RUNNING`. Even a locally staged preview is not a host install. The existing General Deployment v0.1-dev4 `deploy_tree.sh` remains the stage primitive; `handoff/deployment/deploy.sh` retains installation, service and live readiness authority. There is no production cutover here.

## Open owner dependencies

* HTTPS server: v0.4.8 Library source includes new streaming functions with static, not live, v0.4.8 qualification. Do not silently adopt it as an accepted replacement for the source-pinned preview adapter's v0.4.7; the HTTPS owner must provide a qualified version, Foreign Runtime closure and native test results.
* Private NOC/Office HTTPS: requires separate owner-private CA, mTLS and LDAP active attributed principal with explicit `HTTPS_LOGIN`; do not propagate these controls to the public apex.
* Public release: authenticated CMS/Brand/Wire receipts absent. Current content is `noindex,nofollow` and not a production publication candidate.
* Named non-production host, install rights, service unit, TLS identity and executable real readiness/e2e probes not yet provided. Host state is `NOT_OBSERVED`.

Local source-level qualification: full website+handoff tests with the external General Deployment package, plus the dedicated new 13-test site-slice suite; a real v0.4.5 host installation/readiness check remains **NOT_RUN**.
