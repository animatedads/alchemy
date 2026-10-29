# General Deployment dev5 integration — Rasen Falcon identity role

General ooRexx Deployment remains installation/staging authority; Rasen Falcon delivery remains activation/acceptance authority.

Construction inputs:
- Deployment `oorexx_deployment_v0.1-dev5` SHA-256 `109087c9e77d06987f0a8b4365540da76df97fe65eb8fa89952387e5e9db9802`.
- LDAP Identity dev22 SHA-256 `697c301c37ad1d77252a34db9028420c4c9a3e3dbe5c60de9be6fc91940341fc`.
- LDAP deployment handoff commit `0495e8604c62fc780aff3c95b94c935415ffc57d`.

The dev5 identity-role builder creates `roles/identity` in the existing delivery format with the complete owned LDAP package, verified relocatable dependency namespace, hardened `rasenfalcon-ldap.service`, non-secret config examples, hashed manifest, service list and mandatory live-test inventory.

The service launches through Deployment's namespace verifier/launcher; `REXX_PATH` is reconstructed from the installed namespace root rather than inherited from ambient process state.

Mandatory live acceptance remains `ready:ldap_bind`, `e2e:ldap_revoke`, and `e2e:sign_verify_revoke`. Missing credentials or owned live probes are NOT_RUN/failure, never synthetic PASS.

NOC and Office are distinct private HTTPS instances. `HOSTS.json` owns their unit identities: `rasenfalcon-noc-https.service` and `rasenfalcon-office-https.service`. No dummy generic substitute is valid.

This source integration performs no production host, certificate, DNS, firewall, service-start or public-cutover mutation.
