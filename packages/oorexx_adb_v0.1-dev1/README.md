# ooRexx ADB v0.1-dev1

A provider-neutral, event-oriented Android Debug Bridge client substrate for ooRexx.

The application model is deliberately not a transcription of ADB's C implementation. The wire protocol, authentication, transport and stream multiplexing live below semantic session/stream objects. Applications register behaviour against session and stream events.

## Current executable scope

- 24-byte ADB packet codec (`CNXN`, `AUTH`, `STLS`, `OPEN`, `OKAY`, `WRTE`, `CLSE`)
- protocol-version / checksum negotiation model
- CNXN banner + feature parsing
- multiplexed `AdbStream` state machine
- Event Runtime integration for connection, authentication and stream events
- ADB AUTH RSA/PKCS#1 v1.5 signing delegated to ooRexx Crypto's RSA primitive
- Android's 524-byte ADB RSA public-key representation and public-key AUTH payload
- provider-neutral transport seam
- deterministic memory transport for protocol qualification
- Linux native TCP transport through Foreign Runtime v0.22.6 + libc

## Application shape

```rexx
transport = .LinuxAdbTcpTransport~new('192.0.2.20', 5555)
auth = .AdbAuthenticator~new(myAdbKey)
phone = .AdbSession~new(transport, auth, 'adb:lab-phone')

phone~on(.AdbEvents~CONNECTED, observer, 'phoneConnected')
phone~connect

do while phone~state <> 'ONLINE'
    phone~pump(5000)
end

shell = phone~shell('getprop ro.product.model')
shell~on(.AdbEvents~STREAM_DATA, observer, 'shellData')
```

The application never constructs ADB headers, calculates magic/checksum values, routes stream IDs, or handles AUTH packet types.

## Important current boundary

`STLS` is modelled and surfaced as `ADB.TLS.REQUESTED`, but dev1 does not yet perform the modern ADB TLS handshake / wireless-debugging pairing flow. Classic authenticated ADB and the core multiplexed transport are the first boundary.

USB is deliberately a transport provider, not part of `AdbSession`. The planned USB provider discovers interface class/subclass/protocol `FF/42/01`, then discovers the actual bulk IN/OUT endpoint addresses from descriptors. `FF/42/01` are not endpoint addresses.
