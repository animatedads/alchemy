# Architecture

```text
Device Runtime / TCP discovery
          |
     AdbTransport
      /       \
 USB provider  native TCP provider
      \       /
       AdbSession
       /   |   \
   auth  banner streams[*]
    |             |
 Crypto       AdbStream
                  |
             Event Runtime
                  |
              application
```

Rules:

1. Transport supplies bytes; it does not own ADB semantics.
2. Authentication keys belong to the crypto/auth layer, not arbitrary session properties.
3. `OPEN/OKAY/WRTE/CLSE` are hidden by `AdbStream`.
4. A control request does not manufacture observed state.
5. Events are semantic (`ADB.CONNECTED`, `ADB.STREAM.DATA`), not exceptions.
6. Modern `STLS` is explicit in the protocol model even before its TLS provider is implemented.
7. USB class/subclass/protocol `FF/42/01` identifies an ADB interface. Endpoint addresses come from that interface's descriptors.
