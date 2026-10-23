# Architecture

```text
Messaging / Presence
        |
      XMPP session
        |
  XmppBoshTransport          <- this package / XEP-0206
        |
  BOSH logical stream        <- generic XEP-0124 package
        |
  HTTP exchange authority
        |
      HTTPS
        |
 stream/socket selector
        |
   TCP / XTP / ...
```

Neither adjacent package learns the other's semantics. `XmppBoshTransport` is the only layer that understands both the XMPP stream contract and the protocol-neutral BOSH extension seam.
