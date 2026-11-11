# DOCY v0.2c candidate qualification — 11 November 2026

Environment: supplied ooRexx 5.3.0 r13196 debug Debian package, extracted in a disposable runtime directory. No system installation required.

Command: `./tools/run_qualification.sh /path/to/unpacked/usr/local/bin/rexx`

- `tests/demo_test.rex`: 44 PASS
- `tests/test_extension.rex`: 2 PASS
- `tests/test_office_adapters.rex`: 24 PASS
- `tests/test_native_odt_archive.rex`: 14 PASS
- `tests/test_docy_archive_pipeline.rex`: 16 PASS
- `tests/test_office_error_handling.rex`: 7 PASS
- `tests/test_shared_mutation_plans.rex`: 33 PASS
- **Total 140 PASS, zero FAIL**.

The 33 new checks use the actual DOCY graph objects. They verify template placement and override change plans, descendant impact propagation, one local override warning, nonmutation during planning, revision fencing and negative cases.

PDF/ODT provider tests still use API-compatible doubles; binary format interoperability and independent office-suite conformance have not yet been performed. No cryptographic event-chain, Storage Fabric, remote coordination or source freshness acceptance is claimed.
