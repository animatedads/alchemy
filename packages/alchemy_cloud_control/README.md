# Alchemy Cloud Control v0.1-dev3 candidate

API authority: `alchemy.cloud-control/0.1`.

This continuation preserves the v0.1-dev2 authority boundary and expands its RESOURCE transport to one normalized machine/firewall vocabulary across Azure, GCP, AWS, OCI and Vultr.

```text
cloudctl PROVIDER machine list
cloudctl PROVIDER machine start|stop|reboot|destroy --machine HANDLE
cloudctl PROVIDER machine create ...
cloudctl PROVIDER firewall list|allow|revoke ...
```

Provider credentials remain provider-native. GCP requires an explicit `--account animated-ads-cy|bashqueue` and the packaged identity-checking `gcloud-account.sh`. Secret-bearing CLI fields are refused.

The transport itself does not grant authority and does not implement human confirmation. A caller such as ooRexx Cloud Console performs PLAN/APPLY and exact destroy confirmation before invoking an already-authorized RESOURCE action.

## Continuity

`adapters/cloudctl-v0.1-dev2.sh` is the exact dev2 transport preserved for provenance. `adapters/cloudctl.sh` is the dev3 candidate. Development Floor remains pinned to dev2 until this candidate receives the same r13196/package acceptance treatment.

The OCI reboot mapping deliberately uses `oci compute instance action --instance-id ... --action SOFTRESET` without the invalid historical `--compartment-id` action argument.
