# LDAP Identity v0.1-dev20 candidate

This directory records the dev20 qualification-closure increment without falsely relabelling the still-dev14 exploded package tree on GitHub.

Authoritative complete source archive used for this increment:

- artifact: `oorexx_ldap_identity_v0.1-dev20.zip`
- SHA-256: `f709328b4127608d7723031b279e830df298bac99ee01b91242e04cb9f233bbc`
- derived from the Library/current dev19 candidate and corrected in this work session

Dev20 changes only the qualification/release boundary introduced by dev19:

- adds the restart-safe authority journal source and its recovery regression to GitHub;
- fixes the recovery regression's trapped-`SYNTAX` handler so it announces RC, SIGL, condition code and description;
- corrects the packaged version marker to 0.1-dev20 in the complete archive;
- preserves dev19 authority semantics unchanged: epoch regression and same-epoch holder substitution fail closed; XTP/carrier delivery evidence cannot become LDAP application-commit authority.

Qualification performed on the exact archive above:

- ZIP integrity: PASS
- MANIFEST.sha256: PASS
- ooRexx standards enforcer: 81 files, 0 errors, 136 warnings, PASS
- ooRexx runtime regression: NOT RUN in this container because no ooRexx executable is present

The existing `packages/oorexx_ldap_identity` exploded tree is older. This candidate directory is deliberately explicit about that lag rather than claiming the old tree is byte-equivalent to dev20.
