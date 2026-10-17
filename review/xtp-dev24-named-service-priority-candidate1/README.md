# XTP dev24 named-service SORT/priority correction (Candidate 1)

Review-only source overlay. Copy `overlay/` paths into an extracted matching XTP dev24 tree; do not replace the accepted release automatically.

Source authority: `oorexx_xtp_v0.1-dev24.zip`, SHA-256 `9599ee6fc2d8a0fb2df5285ca28c199af7782e07eb44c422690325ee7315d331`.
Planner dev3: `5249c30611edf1e3606a54f74d6ce703ad8e77abc6f25b586a877ec8d67fc35d`.
Socket Provider dev16: `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`.
ooRexx 5.3.0 r13196 package: `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`.

Validated locally: `make test-service` PASS, `make test-native-service-priority` PASS with extracted r13196 and Socket Provider dev16; `XTP_SKIP_BUILD=1 bash tests/run_tests.sh` PASS.

Fix: previously named-service sends discarded XTP SORT priority. The new native route carries service identity and priority together. This does not supply persistent FIRST→KEY context, aggregate capacity enforcement, raw36/WAN qualification, or any ED209 deployment.

No changes to `main`, previously submitted Autobuild candidate, firewall, routes, credentials or running SSH.
