# Dev8 Secure Route Admission — ConnectSelector

**Component** `connect-selector` | **Date** 2026-10-29 | **ZIP** `oorexx_connect_selector_v0.1-dev8.zip` | **SHA-256** `1cc89a61f2b8f4f4e4ee0b32480ce1b149658bb89a67522d466db8dfb4a296fc`.

## Design boundary
`ConnectAuthenticatedRoutePolicy` composes `ConnectRoutePolicy` with a trusted platform authority. It does not accept any application-provided `ldapAuthenticated`/`httpsVerified`/peer flag as evidence. Remote RPC, QueueFabric and RTO2 require affirmative authorization; precise operation/mode/provider/destination ACL always remains authoritative. A faulting attestor fails closed, redacting exception details. For a production MU↔MI service, authorization must be tied to the **actual** authenticated secure endpoint and independently verified LDAP principal/service name. It must not rely on an intention's metadata.

Runtime, not ConnectSelector, owns RTO2 epoch/fencing/promotion. SocketSelector owns socket carrier decision. Serialization Selector owns representation; RPC Service Core owns published operations and their dispatch. JMS→QueueFabric and QueueFabric→JMS preserve their asymmetric durable acknowledgements.

## Evidence
Dev8 test passed under ooRexx r13196; full ConnectSelector suite with pinned QueueFabric persistence, shared RPC/SOAP/JSON-RPC, RTO2 dev15 estate member and optional instrumentation passed. Seven production classes compile; 19-file strict standards check 0 findings; 26-member ZIP integrity and 25-line SHA manifest passed.

No claim of a live secure endpoint, LDAP/HTTPS credential verification, RTO2 invocation, JMS broker, or installed/running server. RFE #882 CommandHandler needs r13289+ (independent test blocked on r13196).

## Git and integration gaps
The dev8 class and negative test are published under `packages/oorexx_connect_selector_v0.1-dev8/`. Remaining GitHub catch-up is the full package import, not just change patches. Next critical handoff is a verified adapter from the **platform's own** LDAP v22 and HTTPS certificate/channel service plus MU↔MI named-service membership to the `authorizeRoute` authority. No unapproved production cutover.
