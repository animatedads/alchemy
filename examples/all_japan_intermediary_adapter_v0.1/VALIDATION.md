# Validation

Runtime: ooRexx 5.3.0 r13196 Internal Test Version.

Adapter tests: 4/4 PASS:

1. intermediary submission reaches actual AJI authority; the distribution actor is denied AJI underwriting authority;
2. FederationBank legal identity cannot replace All Japan insurer identity;
3. sales target cannot satisfy `DEMANDS_AND_NEEDS`;
4. actual AJI submission/underwriting/quote/bind lifecycle projects `RECEIVED -> APPROVED -> OFFERED -> BOUND` into the same RID case with increasing provider sequence.

All Japan Insurance v0.4 upstream suite: 31/31 PASS.
Adapter `.cls` compilation: 3/3 PASS `rexxc`.
