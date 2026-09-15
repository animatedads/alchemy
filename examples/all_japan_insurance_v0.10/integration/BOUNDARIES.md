# Integration boundaries - AJI v0.10

Accounting is an executable external boundary, not a merged authority. `AllJapanInsuranceAccounting.cls` maps AJI-owned evidence into Accounting Core v0.7 `accounting.event/0.1` / `accounting.transaction/0.1`; Accounting Core owns journal mechanics and durable book truth.

The current `oorexxapis(20260828-191905).zip` roll-up is the compatibility baseline. Its embedded AJI v0.9 predecessor is exact; AJI v0.10 advances only this direct-insurance workstream.

FederationBank Merchant accounting adapters remain reference evidence only. Merchant Bank semantics/accounts are not AJI dependencies.

Federation Intermediaries remains a separate workstream. Any intermediary-to-AJI integration must cross an explicit adapter/service contract; it must not share or mutate AJI underwriting, policy, billing or claims state directly.

VMM remains an arm's-length external counterparty/interface where needed. VMM books, positions and market-making authority are not part of AJI.
