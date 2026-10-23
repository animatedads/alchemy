# RTP and socket isolation telemetry

RTP does not instantiate the socket telemetry package. `RtpEndpoint` accepts a SocketProvider. If that provider has a `TelemetrySocketBinding`, the carrier is observed below RTP automatically.

This keeps three independent evidence planes:

- Socket telemetry: acquisition and carrier I/O.
- RTP instrumentation: endpoints, sender/receiver state, frames and samples.
- SIP instrumentation: signalling, auth, registrations and calls.

No layer derives authority from another layer's counters.