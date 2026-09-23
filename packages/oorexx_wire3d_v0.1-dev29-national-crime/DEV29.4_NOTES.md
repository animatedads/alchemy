# dev29.4 — stop/search temporal activity

Adds a separate STOP & SEARCH observation layer to the England & Wales national map.

Bundled source discovery:
- stop/search CSV files found: 0
- source rows: 0
- located event rows exported for browser presentation: 0

Features:
- STREET CRIME and STOP & SEARCH remain separate semantic layers.
- Controlled-drugs filter.
- Hour-of-day selector and 24-hour histogram.
- Event-level points projected on the same geography.
- Only records with useful datetime precision participate in hourly filtering.
- exact-midnight timestamps are conservatively marked DATE_OR_MIDNIGHT_UNCERTAIN rather
  than silently asserted to be genuine midnight activity.
- stop/search activity is not labelled as crime or drug dealing.

The browser JSON is a presentation fixture generated from the bundled source. Production
ingestion authority remains the ooRexx Crime Area Analytics CSVStream path.
