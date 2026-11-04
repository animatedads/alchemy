# UK legislation corpus (raw CLML)

Source acquisition area for offence-neutral legal analysis in SLAM and Reasoned Thought.

## Intended raw-source paths

- `law/uk/ukpga/2006/35/data.xml` — Fraud Act 2006
- `law/uk/ukpga/1968/60/data.xml` — Theft Act 1968
- `law/uk/ukpga/2000/8/data.xml` — Financial Services and Markets Act 2000
- `law/uk/ukpga/1992/5/data.xml` — Social Security Administration Act 1992
- `law/uk/ukpga/2002/29/data.xml` — Proceeds of Crime Act 2002
- `law/uk/ukpga/1977/45/data.xml` — Criminal Law Act 1977
- `law/uk/fetch_manifest.json` — independently checked provenance for all six XML files

**Status (2026-10-30):** directory scaffold only; the six raw statutory files
and their fetch manifest are NOT yet delivered. This README does NOT constitute
evidence that any legislation was downloaded.

Upstream exact endpoints are `https://www.legislation.gov.uk/ukpga/<year>/<chapter>/data.xml`.
Source content is UK legislation under Crown copyright; attribute
`legislation.gov.uk`, The National Archives, and the applicable Open Government
Licence and carry the upstream URI with each manifest record.

## Retrieval and validation

Source-only fetch helper: `docs/architecture/tools/fetch_uk_legislation_clml.py`.

The helper places hash-named XML files and an HTTP, XML, size and digest manifest
in an isolated output directory. The runner must then compare each XML document's
legislation identity and URL to its requested Act, validate **all six**,
re-hash after copying into the intended Git paths, and independently verify that
the Git revision contains the same raw bytes. If even one fails, publish a
failure report, not a false six-of-six successful corpus.

Retain `source_sha256`, retrieved UTC time, response headers, byte count,
root QName, upstream version details if exposed, exact URL and final URI,
repository destination, and Git revision for each file. Report
`historical_event_date_applicability=NOT_ASSESSED` unless separately checked
against commencement, amendments, repeals and territorial extent.
The current `/data.xml` endpoint alone does not establish the historical
text applicable to an alleged act with an unknown event date.

Do not delete or silently substitute older source snapshots on refresh.
Preserve existing immutable manifests or use versioned snapshot directories.

Architecture and event fixture:
`docs/architecture/OFFENCE_EVENT_CONTRACT_v0.1.md`,
`docs/architecture/fixtures/mrs_p_roof_credit_pension_v0.1.json`.
