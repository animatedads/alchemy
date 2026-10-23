# Changelog

## 0.1-dev1

- Adds JSON envelope `semantic.source.control.machine/0.1`.
- Adds read-only `status`, `identify`, `compare`, `impact`, `source`, and `proposals`.
- Preserves semantic negative outcomes as successful observations.
- Uses SSC object APIs directly and does not scrape human CLI output.
- Compare/impact do not append tracking proposals.
- Deliberately excludes acceptance and proposal-decision mutation.
