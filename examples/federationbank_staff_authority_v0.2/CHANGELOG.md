# Changelog

## v0.2

- Adds explicit `CUSTOMER` and `INSTITUTIONAL` staff-authority scopes.
- Binds scope into action, rule, decision and authority-envelope semantic identity and durable state.
- Adds institutional employee rules for `INTERMEDIARY_INTRODUCE`, `INTERMEDIARY_ADVISE`, and `INTERMEDIARY_ARRANGE`.
- Prevents an `INSTITUTIONAL` envelope from binding to an ordinary Core Banking command.
- Preserves v0.1 restore compatibility by treating missing scope as `CUSTOMER`.
- Adds executable scope-separation coverage.

## v0.1

Initial policy-driven staff authority, maker/checker, bounded delegation/elevation and exact Core Banking command binding.
