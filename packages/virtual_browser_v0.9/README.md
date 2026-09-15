# Virtual Browser v0.9

Non-rendering semantic browser engine. v0.9 adopts byte-identical Observation v0.5 and proves a real `VirtualBrowserObservationSession` as a registered Observation Queue Service producer/stream while preserving browser/API/placement authority boundaries.

The browser remains unaware of Queue Fabric delivery and consumer checkpoint semantics. Its observer produces detached state; Observation owns read-side stream/service coordination; API Client remains authoritative for browser outbound traffic.
