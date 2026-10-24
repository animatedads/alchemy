# References

- US Naval Research Laboratory NORM repository: `USNavalResearchLaboratory/norm`.
- `include/normApi.h` inspected from repository master; blob SHA `0caa5c34e72e5fecd42c373bf49b7433530065be`.
- Header identifies NORM API version 1.5.10 and exposes the instance/session/event/multicast functions consumed by this provider.

The provider intentionally uses the public C API rather than NORM C++ internals.

## dev3 qualification notes

- Live runtime in the qualification container: libnorm 1.5.7 (`NormGetVersion`).
- Public API contract checked against NRL `include/normApi.h` blob `0caa5c34e72e5fecd42c373bf49b7433530065be` (header version 1.5.10).
- dev3 uses only the public 1.5.x C API subset documented in that header.
