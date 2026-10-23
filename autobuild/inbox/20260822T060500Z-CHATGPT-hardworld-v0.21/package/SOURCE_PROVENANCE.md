# Source provenance for Alchemy Git submission

This durable Git submission carries the already sealed `virtual_ryta_hardworld_v0.21` release plus the exact Camera/WLU companions needed for the new v0.21 evidence-bridge acceptance tests.

Accepted source archives used to construct the transport bundle:

- HardWorld v0.21 ZIP SHA-256: `568efd0b6f47c1b823b4b412db7be0ca8111b27739aead021ff392bc95ea4c1d`
- Camera v0.34 ZIP SHA-256: `ac81df5b833f749228f5852c6ce66c7a063d2f569eb467370ddc40ea3c446457`
- WLU v0.2 ZIP SHA-256: `94381d1acf722346d6969765526990ad25e83e4718ca6432ae86d732b5fb6b8a`

For connector-safe Git transport, their extracted trees are packed together as an xz-compressed tar stream and split into small base64 chunks. The reconstructed transport SHA-256 is:

`972295e0f5024c1914a224bc316adba4f1d9894f72e1b98a131db5faaf66ae94`

`prepare_release.sh` verifies that transport hash, extracts it, and verifies the native `MANIFEST.sha256` of HardWorld, Camera and WLU before the declared acceptance tests run.

This first durable Git handoff is intentionally `artifact_only`: Alchemy v0.4 publishes source trees from a pristine re-extraction, while this package reconstructs the large release tree during the verified preparation test. The transport therefore cannot masquerade as an ordinary source-tree publication. The runner still archives the deterministic Git package and durable result/log evidence.
