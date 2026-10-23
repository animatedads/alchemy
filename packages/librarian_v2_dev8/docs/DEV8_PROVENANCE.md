# Librarian v2 dev8 — multi-parent provenance

This is a new evidence-only graph alongside dev7's single-parent compatibility API.
It supports multiple upstream relationships per source, shared ancestry,
transitive dependencies, and insertion-time cycle rejection. The graph does
not certify independence, validate source claims, or imply causal authority.

`CORROBORATION_CLAIM` means a party reports corroboration, not verified corroboration.
A graph without an edge is incomplete evidence, **not** proof of independence.

Next: attach relationships to exact source editions, source spans and proposition
occurrences; support historical correction/retraction of edges and immutable
snapshot identity. Do not use counts from this experimental graph for bias verdicts.

Qualification: source inspection only in this increment; executable ooRexx
regression qualification remains open.
