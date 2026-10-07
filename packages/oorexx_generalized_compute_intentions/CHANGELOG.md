# Changelog

## v0.1-dev2

- Added `GeneralizedComputeStructuredIntentionProvider` using the current Intention Service `name/propose` provider shape.
- Added opaque staged tokens so workload/context objects are never flattened into command text.
- Added `GeneralizedComputeIntentionRequest` and `GeneralizedComputeIntentionEvent` for ordinary READY/dispatch integration.
- Added non-mutating `PREPARE_ADMISSION` and `PlannedAdmittanceHandoff` as the explicit seam into the authoritative router/WLU/allocation path.
- Added structured bridge qualification and retained dynamic rediscovery/no-mutation tests.

## v0.1-dev1

- Initial object-preserving planned admittance route.
- Independent compute/allocation/WLU/router advisory assessments.
- Dynamic candidate rediscovery and non-mutating qualification.
