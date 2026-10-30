# XTP Named Services — dev22

## Boundary

Applications name a service. They do not name an IP endpoint.

Examples:

- `ssh.management`
- `radar.primary`
- `fire-control.primary`
- `facilities.air-conditioning`
- `telemetry.internode`
- `backup.bulk`

A service descriptor resolves to a logical XTP route peer. `libxtp` then resolves
that logical peer through its L2/L3/L4 ROUTE table. IPv4/IPv6/MAC/VPN carrier
addresses therefore remain below the service layer.

```
service name
    -> registered operational class
    -> logical route peer
    -> libxtp best_paths()
    -> L2 / L3 / L4 route
```

## FIRST address segment

For named XTP services dev22 places a private address-format descriptor in the
FIRST information segment before application data. The format id is `0xA11C`.
It contains the canonical UTF-8 service name and a 64-bit FNV-1a lookup token.
The token is only a fast lookup hint; the canonical name remains authoritative.
It is not an address and is not an XTP context KEY.

The address segment is present only in FIRST. After context establishment, XTP
KEY/ROUTE processing remains the fast path.

This private format is an Alchemy profile; it is not claimed to be one of the
Internet or ISO formats defined in XTP 3.4.

## Admission

A listener may be opened with a set of locally registered service names. A
FIRST without an admitted name is discarded before CNTL acknowledgement. This
is the transport admission point required for degradation policy.

The ooRexx `XtpNamedServiceManager` derives that admitted set from the local
Service Descriptor Registry and, when supplied, the Operational Degradation
Planner. The caller does not supply its own operational class.

`SAMPLE` and `AGGREGATE` decisions are not treated as permission to send the
unmodified object. They remain upstream transformation requirements.

## No-IP rule

No XTP service descriptor field accepts an IP address. IP addresses are legal
only in the XTP ROUTE table where the underlying L3/L4 link is configured.
