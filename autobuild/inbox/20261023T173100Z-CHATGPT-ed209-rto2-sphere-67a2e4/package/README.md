# ED209 RTO2 Grid Gopher Sphere v0.1

This sphere records the implementation boundaries, field evidence, failure repairs and acceptance criteria for the ten-MU / twenty-MI RexxOS ED209 Grid.

Use `gopher --profile ed209-rto2-grid context ed209-rto2-grid --full` after installing the sphere profile and pack.

**Status:** working local F/H MI registrations reported; RTO2 candidate2 built; controller-response repair submitted for Autobuild; **no confirmed live 20/20 RTO2 run** and no accepted latest-XTP end-to-end Grid deployment.

## Boundaries
- Existing registered Queue Fabric over segmented XTP transports actual work. SSH through `sshnode.sh` is operator management of the owning MU only, not a substitute for MI job dispatch.
- Native XTP named-service identity comes from Service Descriptor Registry in FIRST, not port numbers or receiver-channel strings; later KEY/DATA belongs to the admitted context.
- MI↔MU uses L2 EtherType 0x817D; non-Google MU↔MU native IPv4 protocol 36; Google-involving MU↔MU encapsulated UDP 62801.
- Queue Fabric transport acknowledgement, RTO2 captured/committed state, Storage Fabric durable commit, Migratable Job lease and Job-to-Node allocation are different authorities.
- Preserve proven F/H guest FAST crypto, boot registration and L2 TAP return paths; no blind replacement of installed private authority.

## Provenance
- `ed209_rto2_20mi_candidate2_managed.zip` SHA-256 `940ee1835f9dd53ceea42a14e0eb7880e4dc374d6813cfbc686972debe23b4e1`
- Original candidate2 zip SHA-256 `3a554a28ee512fd2998244b3bfe2551cf5fcc6ece5e30ecb4a181d24712fdec7`
- Local test scope: 6/6 guest-image tests and 2/2 additive overlay tests. Existing candidate2 records an earlier 7/7 fleet sorter test and a bounded native authenticated RTO2 response. No fresh live 20/20 result.
- Related existing spheres: `rto`, `queue-transport`, `job-node-allocator`, `storage-fabric`, `work-load-units`.

## Acceptance gate
A single run ID must produce twenty distinct authenticated and locally committed RTO2 receipts, one from each assigned MI route, all computing `500500`. Missing one is FAIL; a synthetic fixture is not a live result. Promotion of XTP dev25 named-service transport requires independent real FIRST/KEY/DATA tests on L2, raw36 and UDP carriers.

Tracking: https://github.com/animatedads/alchemy/issues/17
