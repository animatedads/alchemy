# Named Service Descriptor Layer

The application-facing object is a **named service**, not an IP endpoint.

Examples:

- `ssh.management`
- `radar.primary`
- `fire-control.primary`
- `facilities.air-conditioning`
- `telemetry.internode`
- `backup.bulk`

Each descriptor binds a canonical service name to an authoritative registered
operational class and, when needed, to a **logical transport peer key**.  The
logical peer is not an address.  XTP, TCP, XMPP, NORM, Queue Fabric and Storage
Fabric adapters may resolve that peer through their own transport/configuration
layer.

IP addresses are explicitly outside this package.  For XTP they belong only in
`libxtp` ROUTE records used to establish the underlying L2/L3/L4 path.

The service registry is authoritative for the operational class.  A remote
caller is never trusted to promote itself to a more important class.
