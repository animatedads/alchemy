# ooRexx ODT v0.1-dev1

Native package-level OpenDocument Text access for Spiral 1 COTS-interface qualification.

The library treats ODT as an interchange/document format, not as a LibreOffice Writer reimplementation. It provides semantic ooRexx document, heading, paragraph and table objects plus read/write access and a small dynamic intention-facing capability projection.

## Public access route

- `OdtAccess~open(path)`
- `OdtAccess~create(title, creator)`
- `OdtAccess~save(document, path)`
- `OdtAccess~describe(document)`
- `OdtAccess~capabilities`
- `OdtIntentionAccess~discover(document)`

## Spiral 1 boundary

This is the access-class demonstration for a COTS/open document interface. It reads and writes ODT package structures directly and does not attempt to reproduce Writer layout, pagination, editing UI or office-suite behaviour.

## Qualification

`tools/test_environment.sh --deb /path/to/oorexx-5.3.0-r13196.deb` performs compile/contract/package checks and, when LibreOffice is installed, independently opens the generated ODT and converts it to PDF.
