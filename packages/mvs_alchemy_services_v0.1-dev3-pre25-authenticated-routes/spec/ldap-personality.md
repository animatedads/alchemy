# MAS/LDAP personality — design boundary

MAS/LDAP is an MVS-facing compatibility personality backed by the separately supplied Alchemy LDAP / Identity Directory service. This package does not invent concrete Alchemy LDAP class names; binding must use that library's inspected public API.

Initial MVS concepts: LDAPINIT, LDAPBIND, LDAPSRCH, LDAPNEXT, LDAPATTR, LDAPVALUE, LDAPADD, LDAPMOD, LDAPDEL, LDAPCMP, LDAPUNBD.

Sessions and searches use opaque MAS handles. Search results are streamed/iterated so a large directory is not materialized in the S/370 address space. DN/filter input is parsed and validated before a semantic directory operation is sent. Binary attributes remain BYTES; character conversion is explicit.

MVS caller provenance and directory authentication are separate authorities. A successful directory bind does not manufacture MVS authority, and an MVS identity claim is not directory authentication. Credentials are not permanent MAS PARMLIB configuration.
