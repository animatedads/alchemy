# Storage Fabric DSFS-like qualification

Target runtime: supplied ooRexx 5.3.0 r13196.

Qualification covers:
- real StorageRef / StorageObject / StorageCatalogue / StorageNamespace classes;
- JCL-like PATHOPTS handling;
- TEXT round trip;
- append creating a new StorageRef while retaining the previous object;
- RECORD stream round trip;
- directory -> MASDIR manifest -> Hercules AWSTAPE creation.

It does NOT claim live ED209Z/ED209ZZ JCL interception, live Storage Fabric durable
provider qualification, or live Hercules tape mount. Those remain separate live gates.
