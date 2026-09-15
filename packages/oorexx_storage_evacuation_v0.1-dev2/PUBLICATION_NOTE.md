# GitHub publication note

This source tree is de-vendored. The supplied standalone archive embedded Storage Fabric under `vendor/storage_fabric/` and copied the same `StorageFabric.cls` into `src/`. Those files are provenance-listed in `vendor/README.md` but are not republished here.

For the GitHub source layout, the final `::requires` in `src/StorageEvacuation.cls` is changed from the distribution-local `vendor/storage_fabric/StorageStreaming.cls` path to `StorageStreaming.cls`. Supply the separately published Storage Fabric `src/` directory through `REXX_PATH`. No Storage Fabric source is owned by this component.

`SHA256SUMS.txt` is retained as provenance for the original supplied standalone distribution; it therefore names the intentionally omitted dependency files.
