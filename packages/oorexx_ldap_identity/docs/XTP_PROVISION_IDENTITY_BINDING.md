# XTP provisioning identity binding through LDAP Identity

This increment supplies the Identity Directory side of the `xtp.provision`
admission contract requested by the XTP provisioning lane.

`XtpProvisionLdapResolver~resolveSession(info)` consumes only trusted XTP session
metadata after `XtpProvisionIngress` has required an OPEN encrypted session. It
does **not** accept a principal from the request payload.

Admission requires all of the following simultaneously:

- service is exactly `xtp.provision` and the established KEYID is nonzero 16-hex;
- the `service:xtp.provision` principal and `resource:xtp.provision` are ACTIVE;
- exactly one current XTP_ENCRYPT binding for that KEYID exists for the service;
- service-wide/shared key ownership is counted as a conflict and cannot identify an MI;
- the key-set owner is `service:xtp.provision/client:<mi-principal>` and the owner,
  key set and key generation retain the same subtree/ownership relationship used
  by `XtpLdapKeySource`;
- the generation is ACTIVE or RETIRING, inside its validity window and, when
  ACTIVE, consistent with the key set's active generation;
- `<mi-principal>` is an ACTIVE NODE or WORKLOAD principal whose id starts `mi:`;
- `aclDecision(<mi>, resource:xtp.provision, XTP_PROVISION)` explicitly ALLOWs;
- Identity Directory revision is unchanged across the decision.

The returned `FENCE_REVISION` is a local Identity Directory revocation/ACL fence,
not a distributed leader-election epoch. Replication/failover authority remains
with the existing Identity Directory peer/authority contracts. Any directory
mutation during the decision invalidates admission and requires a retry.

No Secret Broker value is materialized by this resolver. XTP owns cryptographic
session establishment and its LDAP key source owns trusted Secret Broker key
materialization. This adapter owns only the current semantic binding from that
established KEYID to the exclusive MI principal and explicit admission ACL.
