# Changelog

## v0.8-dev4

- Reworks the intermediary desktop into a denser operational layout following usability observations.
- Converts the case worklist from card-stack presentation to table-like rows with clearer case/product/provider/action/priority hierarchy.
- Converts the six-stage product journey from a tall document-flow rail to a compact horizontal operational stage strip.
- Splits selected-case content into provider state, fact tiles, journey, sealed document, authoritative timeline and a distinct next-intermediary-action zone.
- Keeps all RID/Wire UI authority boundaries unchanged: filters, selection, result revisions, provider status, permissions and signing remain server authoritative.
- Validated against the current `oorexxapis(20260901-112043).zip` Wire UI/Alchemy dependency set and ooRexx 5.3.0 r13196.
- Keeps package-root Node `start.sh`; no Python serving path is introduced.

## v0.8-dev3

- Adds package-root `start.sh` with Node preview and live ooRexx/Web Gateway modes.
