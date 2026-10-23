# ED209 RTO2 controller response repair — candidate

Source-backed incremental submission for the 20-MI smoke job. Origin: ED209 RTO2 20-MI candidate2 archive SHA-256 3a554a28ee512fd2998244b3bfe2551cf5fcc6ece5e30ecb4a181d24712fdec7, dated 22 October 2026.

This package contains the independently executable **controller response/commissioning repair slice** from that archive, not the whole 20-MI runner. The complete 20-MI campaign remains a separate candidate awaiting live tests.

## Repairs

- Route XTP by the commissioned symbolic identity GRID.MN.<MI>, never the destination MAC as route-table key.
- Detect plaintext guest rejection without mistaking it for an authenticated QFXTP response; reject it and issue a redacted diagnostic.
- Derive a dedicated HMAC-SHA256 RTO2 work key from the privately held registration key using a domain-separated context.
- Inspect the **actual** newc initramfs for expected MI/MU identity, exact derived grant, RTO2 code and commissioned symbolic route before changing any QEMU installation.
- Add controller trust through an additive, non-overwriting private manifest stage; never copy secrets into this repository.

Run: python3 -m unittest discover -s tests -p test_guest_preflight.py -v

## Scope and nonclaims

No private authority, password, instance hostname access token, registration key or issued H test key is included. The test uses only a deliberately synthetic key.

This package does not boot or commission MIs, deploy the full campaign, perform native named-service FIRST admission, prove mirrored RTO2 failover, or establish live 20/20 completion. It is a source artifact for Alchemy Autobuild qualification and later integration, not permission to replace F/H's running images.

The return path remains the established Grid XTP Queue Fabric wire adapter; service-first XTP dev25 integration remains a separate acceptance boundary.
