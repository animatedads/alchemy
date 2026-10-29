# Rasen Falcon public-site staging via General ooRexx Deployment

**Version:** v0.4.4, 29 October 2026. **Owner lane:** `rasenfalcon-website`.

## Explicit authority boundary

This adapter is a **review-only local staging consumer** of the existing General ooRexx Deployment `v0.1-dev4` POSIX provider, `bin/deploy_tree.sh`. It never implements an independent deployment engine, creates/starts a service, installs files to system roots, opens a listener, changes DNS or grants CMS/Brand/Wire publication authority.

The adapter requires the external general Deployment package as an explicit, pinned `--deployment-root` dependency; it is not bundled or copied into this package. The provider's content-addressed `releases/<generation>` and `current` symlink are the authoritative local stage primitive. A post-stage check independently verifies the generation marker, every byte, nine page digests, `noindex,nofollow` and a disallowing `robots.txt`.

The workspace must be an absolute **dedicated nested directory below `/tmp`**, with no symlink redirection. A later deployment to actual infrastructure MUST use the General Deployment target/host contracts, sealed SSC dependency package, qualified run-time and the Rasen Falcon host-specific release gate. Never reuse this temporary review workspace as a production installation.

## Commands

From `rasenfalcon_delivery_v0.4.4/` (with General Deployment provided separately):

```sh
WORK=/tmp/rasenfalcon-review-20261029/site1
DEPLOY=/path/to/oorexx_deployment_v0.1-dev4
python3 handoff/deployment/public_preview_staging.py plan --deployment-root "$DEPLOY" --workspace "$WORK"
python3 handoff/deployment/public_preview_staging.py stage --deployment-root "$DEPLOY" --workspace "$WORK"
python3 handoff/deployment/public_preview_staging.py verify --deployment-root "$DEPLOY" --workspace "$WORK"
RF_ROLE=public bash handoff/deployment/deploy.sh check-release
```

The last command is **expected to refuse** on a source-only package: production installation cannot begin without a reviewed role-specific `roles/public/manifest.tsv`, `services.txt`, `tests.tsv`, executable protocol tests, accepted native HTTPS server and explicit operator approval. Do not fabricate those as a proxy for real qualification. `install` and `start` are never used in this adapter.

## Evidence vocabulary

| Stage | Required evidence | This checkpoint |
|---|---|---|
| `SOURCE_ONLY` | Source package SHA + matching source inventory | Yes |
| `STAGED_LOCAL_REVIEW` | General Deployment content-addressed copy + verified preview, in isolated scratch directory | Yes (offline test, not a target host) |
| `INSTALLED` | Target host/files/units + installation receipt and rollback | NOT OBSERVED |
| `RUNNING` | `systemctl` process + port/SNI/TLS and public read probe | NOT OBSERVED |
| `QUALIFIED_LIVE` | Negative tests, exact host/provider provenance, CMS/Brand/Wire release receipts and authorized deployment record | NOT OBSERVED |

Local scratch staging cannot be used to infer any target service state. Source revisions imported from Website Publisher remain unreviewed, and all nine pages are non-indexable. No live activation or operator production cutover is authorized by this artifact.

## Test entrypoints

- `bash run_tests.sh`: website, security and source-lock tests, plus new adapter tests.
- `RF_GENERAL_DEPLOYMENT_ROOT=/absolute/path/to/oorexx_deployment_v0.1-dev4 bash run_tests.sh`: exercises the external General Deployment. Tests that require the provider are explicitly SKIPPED when it is unavailable; do not report skipped checks as PASS.
- General Deployment's own `tests/test_local_reconcile.sh` and `tests/test_dependency_namespace.sh` establish provider behavior independently.

The general Deployment component requires its own accepted/qualified deployment input before being used on public/private cloud nodes. It must not be replaced with Rasen-specific SSH copying, Nginx or another runtime.
