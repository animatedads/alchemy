# Wire3D bundled dependencies

This development package is intentionally self-contained for review and Codex work.

## Crime dependencies

* `dependencies/crime_area_analytics_v0.3/` — complete supplied Crime Area Analytics v0.3 package.
* `dependencies/crime_enterprise_objects/CrimeEnterprise.cls` — investigation/domain object model used by the crime-space example.

The historical `examples/domain/CrimeEnterprise.cls` copy is retained so existing
examples continue to run, but consumers should treat the explicit dependency path
above as the dependency declaration.

Other Wire3D dependencies remain under `dependencies/` as supplied package ZIPs.
