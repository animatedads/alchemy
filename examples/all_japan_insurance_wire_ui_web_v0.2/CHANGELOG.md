# Changelog

## v0.2

- Adds runnable ooRexx AJI `WireUIApplication` development backend.
- Adds real Wire UI Server v0.17 + Queue Fabric + Web Gateway bootstrap/WebSocket
  service on port 8090 by default.
- `./start.sh --live` now starts both the authoritative service and browser shell;
  an externally supplied bootstrap remains supported.
- Vendors exact required runtime source subsets from the supplied
  `oorexxapis(20260828-191905).zip` for a predictable local development launch.
- Advances semantic site release to `ALL_JAPAN_INSURANCE_OPERATIONS@2`.
- Replaces unsupported v0.1 `SUMMARY`/`TIMELINE` server primitives with
  JS-v0.4-dev4-supported `SEMANTIC_RECORD`/`OFFER_LIST` primitives.
- Adds explicit projection bindings so policy, billing, claim and accounting
  values actually render in a live semantic session.
- Adds server-issued policy collection and `AJI.POLICY.OPEN` drill-down.
- Keeps fixture values on the ooRexx side only; the live browser remains free of
  AJI business truth/calculation logic.
- Adds full authoritative round-trip regression through the real Queue Fabric
  gateway and Alchemy Wire UI JavaScript runtime.

## v0.1

- First separate AJI browser projection shell and non-authoritative preview.
- Builder v0.11 / Server v0.17 structural qualification only.
- No authoritative bootstrap/application service was shipped.
