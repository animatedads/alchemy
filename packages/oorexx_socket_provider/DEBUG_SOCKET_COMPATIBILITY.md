# Debug Socket Transport compatibility

Checked against uploaded `oorexx_debug_socket_transport_v0.1-dev3`.

The Debug component correctly consumes an already-selected object with
READ/WRITE/CLOSE and preserves the accompanying SocketAddress object.
Socket Provider dev7 supplies that vocabulary through `SocketStreamAdapter`;
the Debug component remains unchanged and external.
