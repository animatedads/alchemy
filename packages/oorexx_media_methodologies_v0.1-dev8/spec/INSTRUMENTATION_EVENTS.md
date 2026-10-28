# Media methodology instrumentation events

Instrumentation Mesh dev7 is used only as an **operational observation** layer.

Media Methodologies may emit:

- `METHODOLOGY_EXECUTION_STARTED`
- `METHODOLOGY_EXECUTION_COMPLETED`
- `METHODOLOGY_NOT_APPLICABLE`
- `METHODOLOGY_EXECUTION_FAILED`

The event authority is `MEDIA_METHODOLOGY_EXECUTION`. Event evidence records the methodology and implementation identity plus detached material references. Every event carries `observation_promotion=false` and `source_authority_unchanged=true`.

These events answer operational questions such as *which experiment is running, where did it finish, and which provider withheld itself?* They do not assert that a reconstructed feature existed in the source.

Instrumentation Mesh owns replay/deduplication of the event timeline. Wire3D dev29.22 can present that timeline in the Keynote/NOC view. Wire3D remains a consumer/presentation layer and acquires no media or scientific authority.
