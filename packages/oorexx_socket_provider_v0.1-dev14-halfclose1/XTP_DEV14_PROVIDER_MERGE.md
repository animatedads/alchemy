# XTP dev14 Socket Provider merge

Socket Provider v0.1-dev12 merges the current ooRexx XTP provider adapter from
`oorexx_xtp_v0.1-dev14` into the common Socket Provider distribution.

The merge is deliberately at the provider/access-class boundary.  It does **not**
vendor `libxtp`, `liboorexx_xtp_native.so`, XTP route state, or XTP carrier
selection into the generic socket core.

## Standard route

```text
SocketAddress(XTP)
      -> SocketSelector / SocketProvider
      -> RexxXtpSocketBinding
      -> XtpSocketBackend
      -> XtpProviderSocket / XtpProviderListener
      -> oorexx_xtp_native
      -> libxtp dev14
      -> L2 / native IPv4 protocol 36 / UDP carrier
```

The native XTP sender and persistent listener are both represented.  Accepted
socket objects retain the original `SocketAddress` object.  Replay, filtering,
routing and carrier selection remain below the provider seam in libxtp.

## XTP-specific access route

The merged adapter also retains the dev14 XTP-specific multipath access classes:

- `XtpSocketBackend~multipathSender()`
- `XtpSocketBackend~multipathListener()`
- `XtpMultipathSocket`
- `XtpMultipathListener`

They remain XTP-specific rather than being promoted into the protocol-neutral
`SocketProvider` API.

## Capability truth

Current dev14 executable truth is preserved:

```text
unicast              true
listener             true
multipath            true
path_requalification true
wire_filters         true
multicast            false
```

A group-shaped XTP address remains representable for forward compatibility but
cannot satisfy a multicast requirement.

## Runtime dependency

`src/XtpSocketProvider.cls` declares the native routines exported by
`liboorexx_xtp_native.so`.  Loading/using an XTP native operation therefore
requires a compatible XTP dev14 runtime on `LD_LIBRARY_PATH`.  The generic
Socket Provider core remains loadable without XTP installed.
