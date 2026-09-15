# Alchemy Dependency Floor v0.4

Bootstrap seeding plus accepted-repository dependency cataloguing.

The catalogue is **manifest first**.  When `integration.json` is present its
package name/version is authoritative and the entry records `identitySource =
MANIFEST`.  Directory-name parsing is retained only for legacy trees without a
manifest and is recorded as `DIRECTORY_FALLBACK`.

A present but malformed/unsupported manifest is repository corruption and is
never silently replaced with directory inference.

Dependency-floor seeding remains `BOOTSTRAP_ONLY_NOT_ACCEPTANCE` and uses the
leased accepted-main transaction supplied by Alchemy Transport.
