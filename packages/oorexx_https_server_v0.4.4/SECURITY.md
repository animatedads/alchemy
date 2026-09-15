# Security notes — ooRexx HTTPS Server v0.4.4

RxSock is the sole accepted-socket descriptor and network-I/O owner. OpenSSL operates on memory BIOs and never receives the fd.

TLS native calls remain serialized through one Foreign Runtime/OpenSSL lane. Foreign Runtime v0.17.1 repairs a separate introspection concurrency bug, but that does not justify reopening unrestricted TLS-native overlap while the target-host HTTPS portability line is still being closed.

A pre-TLS resource-control boundary queues accepted unauthenticated peers into a bounded FIFO and services them with a fixed worker set instead of creating an unbounded new ooRexx activity per peer. Queue overflow closes the connection and releases its generation pin immediately.

Failed/incomplete handshakes do not run TLS shutdown. Direct peer EOF during handshake is treated as abort/noise rather than a server ERROR, reducing log-amplification risk.

This remains a small application HTTPS server, not a general Internet edge proxy. Long-lived/slow connections can occupy workers until configured read/write/request limits expire; broader Internet-facing DoS controls may still belong at a hardened edge/load-balancer layer.

The HTTP parser rejects ambiguous framing, invalid Host/header syntax, embedded NULs and configured size/count violations.

TLS evidence is transport evidence only. It is not itself Authentication, Access Control, method/object Permission, or Security Effect authority. Those remain separate application/security-layer responsibilities through the interceptor boundary.
