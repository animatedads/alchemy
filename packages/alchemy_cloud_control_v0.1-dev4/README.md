# Alchemy Cloud Control v0.1-dev4

API authority: `alchemy.cloud-control/0.1`.

This release preserves the Cloud Control authority boundary while providing one normalized RESOURCE transport across Azure, GCP, AWS, OCI and Vultr. Provider credentials remain in provider-native stores; GCP requires an explicit configured account.

```text
cloudctl PROVIDER machine list
cloudctl PROVIDER machine start|stop|reboot|destroy --machine HANDLE
cloudctl PROVIDER machine create ...
cloudctl PROVIDER firewall list|allow|revoke ...
cloudctl PROVIDER firewall reconcile --scope SCOPE --rule NAME --protocol PROTO [--port PORT] --sources CIDR[,CIDR...]
```

## Source-set reconciliation

`firewall reconcile` makes the ingress sources for one scoped protocol/port rule exactly match the requested non-empty source set. It preserves unrelated rules. Empty source sets fail closed. Azure and GCP update/create their named rule; AWS, OCI and Vultr compute a source-level diff and add/remove only matching ingress entries.

This generic operation deliberately contains no ED209 or XTP topology. XTP or another specialist supplies the desired peers; Cloud Control owns provider mutation syntax.

## Authority and safety

- The transport does not perform human confirmation. Callers such as ooRexx Cloud Console own PLAN/APPLY and exact destroy confirmation.
- Secret-bearing command options are refused.
- GCP requires `--account animated-ads-cy|bashqueue` and the identity-checking `gcloud-account.sh`.
- Provider IAM remains final authority.
- `adapters/cloudctl-v0.1-dev2.sh` is retained byte-for-byte as historical provenance.

## Qualification

The offline RESOURCE suite passes for machine inventory/lifecycle/create and firewall list/allow/revoke/reconcile across all five providers. No live provider mutation is claimed. See `qualification/QUALIFICATION.txt`.
