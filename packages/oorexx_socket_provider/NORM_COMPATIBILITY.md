# NORM provider compatibility — dev8

Dev8 adds NORM as a first-class SocketProvider transport family without putting
NORM session mechanics into the common selector.

The common additions are intentionally limited to:

- `SocketTransportKind~NORM`
- `SocketScheme~NORM`
- `SocketAddressFamily~NORM`
- `SocketFamilies~norm`
- `SocketAddresses~norm(group, port, interface, source, nodeId, logicalName, metadata)`
- `RexxNormSocketBinding`

The NORM provider owns libnorm instance/session creation, sender/receiver
lifecycle, multicast interface and SSM configuration, FEC/repair parameters,
event handling, object-buffer lifetime, and native descriptor use.

Applications continue to call `SocketProvider~sender()/listener()` or the
resolved-address `senderAt()/listenerAt()` forms.  They do not call libnorm.
