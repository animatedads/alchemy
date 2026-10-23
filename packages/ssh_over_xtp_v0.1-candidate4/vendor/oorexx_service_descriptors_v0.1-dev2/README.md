# ooRexx Service Descriptors v0.1-dev2

Named-service authority for transport-independent service admission. Service descriptors contain **no IP addresses**. A descriptor binds a canonical service name to an authoritative registered operational class and a logical route peer. Physical addressing remains a property of the transport route table.

Administrative surface (ooRexx):

- `servicectl.rex add NAME --class CLASS --peer LOGICAL_PEER`
- `servicectl.rex set-class NAME CLASS`
- `servicectl.rex set-peer NAME LOGICAL_PEER`
- `servicectl.rex set-point NAME SERVICE_POINT`
- `servicectl.rex policy NAME STATE`
- `servicectl.rex enable|disable NAME`

`policy`/`capacity` resolve the service's registered class and ask the Operational Degradation Planner. Applications do not self-assert a class.
