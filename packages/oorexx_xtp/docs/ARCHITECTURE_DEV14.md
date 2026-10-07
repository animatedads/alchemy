# XTP dev14 — capability truth: multicast is not advertised

libxtp currently implements unicast sender/listener operation, L2/L3/L4 carriers,
wire filters, multipath striping/failover and path requalification. It does **not**
yet implement XTP multicast.

Therefore:

- XTP multicast capability is false.
- Socket negotiation must not select XTP to satisfy a multicast requirement.
- A group-shaped XTP address is only representational/future-facing and is not
  evidence that multicast is implemented.
- NORM may satisfy multicast requirements through the Socket Provider when it
  is otherwise eligible.
- XTP multicast may only be advertised after libxtp contains executable sender,
  receiver/group-membership semantics and corresponding qualification.

This prevents architecture/documentation capability from running ahead of the
transport implementation.
