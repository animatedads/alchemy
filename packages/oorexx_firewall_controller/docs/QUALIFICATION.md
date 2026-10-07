# Two-node qualification

Use the gateway as the server and the HTTPS/RexxOS side as the client.  The
scripts deliberately mirror the existing QueueRexx peer qualification shape.
Production integration should attach the binding to each node's resident peer
mesh rather than launch a second mesh.

Before starting the gateway service, include the operator/admin IPv4 address in
`PROTECTED_CSV`.  The server refuses any block request for that exact address or
protected /24.

A successful report must produce both:

```text
BLOCK exact=<source> minutes=1440
BLOCK network=<source /24> minutes=10
```

On the gateway verify:

```sh
nft list table inet alchemy_firewall
```

The same request ID replay must not extend either timeout.  A changed request
using the same request ID must be rejected with `REQUEST_ID_CONFLICT`.

A request whose payload `from_node` differs from the authenticated Queue Fabric
peer must be rejected with `PEER_IDENTITY_MISMATCH`.
