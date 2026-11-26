# Provenance: alchemy_cloud_control v0.2-dev3

- Architecture: Tom Dyer.
- v0.1-dev4 (bash adapters, `packages/alchemy_cloud_control_v0.1-dev4`): ChatGPT/Codex. Its command shapes and its
  `cloud-fake` and `fake-gcloud-account.sh` test fixtures are kept.
- ooRexx rewrite (`cloudctl.rex`, `src/*.cls`, the rules engine, PLAN/APPLY, ledger, oorexx_logging events, `xtp`,
  `discover`): Claude (Opus 5.5), 7 November 2026. It ran only on Tom's workstation until this package.
- 26 November 2026 fixes (add-only, named removals, error reasons, AWS pager, test registry): Claude (Opus 5.5),
  at Tom Dyer's instruction ("fix cloud controller", 10:50). Source staged from Tom's workstation through the
  Claude desktop bridge, changed and tested in the Ubuntu 22.04 build container (ooRexx 5), written back with an
  mtime guard. The originals are kept on the workstation in `cloudctl/var/backup-20261126/`.
- Deliberate-breakage controls, all caught: add-only off for named rules, AWS_PAGER unset, the read-only hint
  removed.
- Field evidence for the faults: Codex (CODEX-PC, GPT-6) runs of orders A (REQ-00006061) and C (REQ-00006185).
- v0.2-dev3 differs from v0.2-dev1 only in redaction: v0.2-dev1 still carried the live GCP project ID of ed209e (one
  example in `cloudctl/README.md`) and the Vultr instance ID of ed209k (in `curl-fake` and `discover-fake`). Neither
  is a credential; both are now example values, as promised for the package. v0.2-dev1 stays in git history.
- v0.2-dev3: v0.2-dev1 and v0.2-dev2 failed in autobuild on two test_discover checks ("kit check: a missing CLI is
  named"). The test removed the fake aws and expected cloudctl to find no aws, but the autobuild runner has the real
  aws installed. The two checks now run on a PATH holding only the tools a run needs and the remaining fakes, with
  REXX_PATH set so ::requires 'json.cls' is still found. Rehearsed with a stand-in aws on PATH: 30/30.
