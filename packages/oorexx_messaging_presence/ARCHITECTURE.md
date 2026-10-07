# Architecture

## Spiral 1 route

```text
human / application / agent
          |
          v
   Intention discovery
          |
          v
 Messaging / Presence access classes
          |
          v
 current provider offers
          |
          +---- XMPP provider
                    |
                    v
             XmppSession engine
                    |
                    v
             XmppSocketTransport
                    |
                    v
          SocketProvider / SocketSelector
                    |
                 TCP/TLS
```

The layers have separate authority:

1. **Messaging/Presence** owns semantic objects and operations.
2. **Provider Registry** owns only current provider selection from fresh offers.
3. **XMPP Provider** owns protocol projection, not application semantics.
4. **XmppSession** owns RFC 6120 session mechanics and XML stream correctness.
5. **SocketProvider** alone owns socket acquisition and transport isolation.

An Intention never chooses XMPP, TCP, TLS, a JID, or a stanza.  It asks for a
semantic operation.  Discovery determines whether such an operation is
currently possible.

## Object preservation

`Message`, `MessagingAddress`, `PresenceState` and their metadata remain ooRexx
objects through the access layer.  Provider projection is intentionally at the
last responsible boundary.

## Extension boundary

XMPP extension namespaces are outside this component.  A future extension must
be a separately registered plugin/provider and may expose its own semantic
objects and transient Intention surface.  It must not enlarge `Messaging` or
`Presence` merely because XMPP happens to have an extension for something.
