# Federation Intermediary UI notes — v0.8-dev4

v0.8-dev4 is a presentation and operator-usability increment over v0.8-dev3. The sealed v0.7 domain/security authority remains the accepted release baseline.

## Operator layout changes

- The worklist is now visually table-like rather than a stack of equal-weight cards.
- Summary KPIs remain server projections but use a denser scorecard treatment.
- The selected-case panel is a compact dossier with distinct provider state, case facts, journey, sealed document, history, and next-action regions.
- Product journeys are rendered as a horizontal six-stage operational strip. They remain presentation derived from authoritative RID case/work/provider fields; no browser workflow engine is introduced.
- Next intermediary action is visually separated from provider progress and historical evidence.
- Case facts are grouped into labelled fact tiles, reducing heading/value run-together and raw semantic-text appearance.
- Existing server-authoritative filters, selection, result revisions, permissions and signing challenges are unchanged.

## Authority boundary

No client-side product decision, provider-state progression, case completion, access decision, permission decision or signature meaning is introduced by this UI work. Dynamic business values continue to be inserted as text, and semantic actions still return Wire UI workspace/result context to the server for validation.

## Start

Use `./start.sh` for the Node-served static preview or `./start.sh --live` for the real development stack. There is no Python server fallback.
