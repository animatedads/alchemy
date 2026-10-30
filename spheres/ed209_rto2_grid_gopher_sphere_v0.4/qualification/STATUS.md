# Evidence status

- ED209 RTO2 candidate3 is now published directly on GitHub main under `packages/ed209_rto2_20mi_candidate3`; its R-11 typed failure classifier remains local/source evidence, not field acceptance.
- Candidate3 pre-submit evidence: R-11 wrapper 4/4, guest image preflight 6/6 and additive overlay 2/2 PASS. Full legacy synthetic 20-MI rerun stalled; no synthetic 20/20 PASS is inferred.
- Grid dev15 provides generic first-class MU/MI topology and failure-domain evidence. It is not a claim that the ED209 10-MU/20-MI field estate is installed or accepted.
- Grid dev16 Identity Directory authorization increment: strict house standards PASS (3 files, 0 findings) and static contract tests 5/5 PASS. The ooRexx runtime test is NOT_RUN in this container because the exact r13196 executable was unavailable.
- LDAP Identity dev22 is the inspected identity source. The Grid seam uses its neutral IdentityDirectory and ACL decision, not LDAP Bind as authorization.
- GitHub XTP dev30 exists; field migration from candidate3's older segmented QFXTP path to service-first FIRST/KEY/DATA remains NOT ACCEPTED.
- R-10 MI-only digital result attribution remains open.
- Live controller-committed F/H 4/4 and estate 20/20: NOT OBSERVED.
- Reboot persistence, failover promotion, WAN service-first federation and mirrored RTO2 replay: NOT ACCEPTED.

- **2026-10-29:** Grid dev17 native runtime: authorization PASS, RPC dispatcher/ACL PASS, five static tests PASS on ooRexx 5.3.0 r13196. Earlier dev16 NOT_RUN claim superseded for this local test only; field 20/20 still NOT_ACCEPTED.
