# Frozen timezone test fixtures

Named zone files copied verbatim from the test host's `/usr/share/zoneinfo`,
whose `/usr/share/zoneinfo/tzdata.zi` declares `# version 2025b`.
They are **test evidence**, not a promised current or complete IANA database.
IANA timezone database: https://www.iana.org/time-zones

`synthetic/` contains minimum TZif data to exercise v1, v2 64-bit transition
records, 2040+, malformed files and rejection of a v4 leap-second record.
Production deployments should provision and pin their own tzdb edition.
