# Evidence revision integration

Media Methodologies does not own belief or factual-truth revision.  It may consume the detached classification produced by `EvidenceRevisionAudit` and apply that classification to the **lifecycle of a reconstruction candidate or comparison record**.

`MediaMethodologyRevisionBridge` maps:

| EvidenceRevisionAudit classification | Media candidate lifecycle |
| --- | --- |
| `NO_REVISION` | `UNCHANGED` |
| `ADMITTED_DELTA_BACKED` | `REVISED` |
| `MUTATED_GROUND_ID` | `QUARANTINED` |
| `UNVERIFIED_REMOVAL` | `QUARANTINED` |
| `POLICY_CHANGE_REQUIRES_REVIEW` | `REVIEW_REQUIRED` |
| any unsupported/invalid/unexplained state | `UNRESOLVED` |

`ADMITTED_DELTA_BACKED` remains policy-relative evidence about a revision.  It is not proof that either reconstruction is factually true.  The bridge can never promote a candidate into captured observation and can never manufacture provenance, revocation or witness authority.
