# Implementation notes

The first source pass intentionally stops before inventing an ABI for the one
remaining construction detail: the negotiated RXPA host-service table used by
`rxpa_set_object_type()`.

The provider source therefore contains an explicit fail-closed factory until
the exact V2 host-service negotiation entry point from the pinned CREXX
revision is wired.

Next action:

1. wire the host-services table from the pinned `crexxpa.h` contract;
2. compile the provider;
3. author cREXX fixtures against the pinned compiler;
4. run nested A -> RXPA -> B -> RXPA -> C qualification.

Everything else stays on documented RXPA surfaces: native payload
copy/finalize, native class/member metadata and `CALLMETHOD`.
