# Changelog

## 0.1-dev1

- Added semantic Messaging and Presence object/access-class contracts.
- Added dynamic provider offers and selection with no permanent capability cache.
- Added transient Intention discovery adapter for send/presence operations.
- Added provider-private XMPP projection for RFC 6120/6121 basic messaging and presence.
- Added conservative ASCII XMPP address codec with fail-closed Unicode boundary.
- Added `XmppSocketTransport` using SocketProvider isolation rather than raw sockets.
- Explicitly excluded MUC, PubSub, file transfer, avatars and extension policy from core.
- Added complete environment qualification script and contract tests.
