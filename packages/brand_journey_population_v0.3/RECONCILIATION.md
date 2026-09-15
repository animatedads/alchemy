# v0.2 branch reconciliation

Two chats independently advanced the same Brand Journey Population v0.1 source
to version 0.2. The archives are both internally valid but are not byte-identical
and do not implement identical APIs.

| Concern | `2d1e0b...` branch | `37f792...` branch | v0.3 decision |
|---|---|---|---|
| Upstream source provenance | Population-owned; unknown stays `UNSPECIFIED` | Cohort-owned with confident defaults | Population-owned; unknown stays `UNSPECIFIED` |
| Local cohort selection provenance | Population carries much of it | Cohort-owned | Cohort-owned |
| Duplicate attachment attempts | Counted | Rejected but not counted | Counted as provenance, never denominator |
| Detailed denominator exclusions | Coarser | Feature/outcome/window split | Retained detailed split |
| Missing comparison arm | Explicit insufficiency | Explicit insufficiency + detailed quality helpers | Retained detailed quality handling |
| Local Wilson comparison marker | No explicit marker | `COMPARISON_AVAILABLE` | Retained |
| BIE v0.6 confidence reasoning test | Indirect | Explicit | Retained |
| Pre-aggregated provenance limitation | Explicit | Partial/mixed limitations | Both retained |
| Convenience sampling | Recorded, not moralized | Configurable provenance | Recorded, not moralized |

The v0.3 API separates upstream-source facts from local-analysis facts and
composes them only when producing native Brand Interaction Effect v0.6 cohort
provenance. The old cohort `configureProvenance(...)` method remains as a
compatibility fallback so neither v0.2 calling convention is needlessly lost.
