# RasenFalcon native HTTPS endpoint content qualification — v0.4.5

This is **executable endpoint verification** against the exact release candidate bytes, not a mock `200` check. Run **only after** owned native ooRexx HTTPS has been installed/activated under an independently approved host deployment; it does not install, start, authorize publication, or issue any certificate.

```sh
# From this package's root — must point at the exact intended published build tree
bash website/deploy/site_contract_probe.sh https://rasenfalcon.com
```

The script calls the Python 3 standard-library HTTPS verifier and checks nine HTML pages, CSS, JS, favicon and robots against the local `website/site/build-manifest.json` and SHA-256 of each asset. It verifies TLS chain, server hostname/SNI and TLS >=1.2, rejects redirects and compressed response bodies, and optionally pins the certificate leaf:

```sh
RF_SITE_CA_FILE=/secure/path/to/reviewed-trust.pem \
RF_SITE_LEAF_SHA256=64_lowercase_hex_chars \
bash website/deploy/site_contract_probe.sh https://rasenfalcon.com
```

An explicit CA trust path is a **trusted input**, not a means to disable verification. No `-k`/unverified SSL context exists. The command refuses IP literals, unrelated hosts, non-HTTPS and arbitrary URLs. It issues **no unknown-path challenge**: doing so against the owned HTTPS firewall could accidentally block the probing source. Negative firewall tests must use a separately approved and isolated client.

A passing result has `content_integrity=PASS` and `tls_server_verified=true`. It *always* retains `cms_release_authorized=NOT_TESTED`, `private_mtls=NOT_TESTED`, `service_installed=NOT_TESTED`, and `production_approved=false`. A published deployment must separately prove its CMS/Brand/Wire release receipts and the owned `oorexx_deployment` installation/rollback evidence. A `preview` tree (currently marked `noindex,nofollow`) is **not** production content and cannot be construed as approved even if it is successfully served over TLS. The probe is read-only and was tested with an ephemeral local TLS fixture, not the live site.

This probes the **public** apex only. Private `noc` and `office` have their own server identities, private CA and required per-device **mutual TLS**, and require different security qualification; this verifier must never replace their mTLS tests.
