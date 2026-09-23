# POSIX Foundation integration — dev6

Storage Evacuation now consumes `oorexx.posix/0.1` for authoritative coherent
`lstat`, symlink target reads, and directory enumeration.  Generation fencing
fails closed if coherent metadata cannot be obtained.

The supplied POSIX v0.1-dev1 temporary `rxposixgap` provider is packaged only
as a sealed dependency for qualification.  It is not Evacuation source
authority and MUST NOT be edited in this package.

## Deliberately unresolved platform gaps

Evacuation does not add new local shell implementations for missing POSIX
facilities.  v0.1-dev1 does not yet expose all operations needed to retire the
older compatibility adapters, notably realpath/canonicalization, file-time
restoration (`utimensat` semantics), strong ACL handling, and the complete
strong xattr/materialisation contract.  Existing dev5 compatibility paths are
isolated and retained only until the platform supplies those operations.

`EvacInventory` no longer shells to `find`; it recursively consumes the POSIX
directory iterator and uses coherent POSIX `lstat` for every discovered object.
`EvacPosixMetadataProbe` no longer shells to `stat` or `readlink`.
