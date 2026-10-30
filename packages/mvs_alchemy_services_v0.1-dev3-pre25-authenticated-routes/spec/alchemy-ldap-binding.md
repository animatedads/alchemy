# MAS/LDAP binding — dev22 reconciliation

MAS consumes the platform `identity.directory/0.1`, `identity.acl/0.1` and `ldap.conversation/0.1` contracts. A successful LDAP Bind attributes an identity; it does not authorize a MAS operation or remote route.

`MasLdapHostIdentityResolver` accepts only an injected trusted resolver returning an authenticated dev22 `LdapSession`. It never reconstructs identity from DN text, guest fields, source addresses or ConnectIntent options.

`MasAuthenticatedRouteAuthority~authorizeRoute(intent,provider)` satisfies the platform authority seam expected by ConnectSelector dev8. Admission requires:
1. authenticated LDAP dev22 session from trusted host composition;
2. independent endpoint-security attestation;
3. `IdentityDirectory~aclDecision(principalId,resourceId,action)` ALLOW for an explicit destination/provider mapping.

Missing/faulting evidence fails closed. HTTPS v0.4.8 TLS fields are transport evidence only; `MasHttpsExchangeChannelAttestor` additionally requires trusted context value `mas.private_ca_verified`. For XTP/RTO2, an estate/channel attestor is injected instead; MAS does not bypass Grid membership/epoch authority.

Planned MVS LDAP operations still map semantically to `LdapConversationService` and remain bounded/paged. No claim is made that live LDAPS or MVS LDAP assembler entry modules are complete.
