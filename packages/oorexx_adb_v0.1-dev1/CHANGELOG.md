# Changelog

## v0.1-dev1

First executable ooRexx-native ADB substrate.

- ADB 24-byte packet codec and validation.
- current 0x01000001 checksum-skipping protocol model, while retaining legacy checksums before negotiation.
- AUTH TOKEN / SIGNATURE / RSAPUBLICKEY state.
- RSA-2048 PKCS#1 v1.5 ADB challenge signing through ooRexx Crypto.
- exact Android 524-byte ADB public-key binary representation and base64 AUTH text.
- CNXN banner / feature parsing.
- multiplexed OPEN / OKAY / WRTE / CLSE stream state machine.
- semantic Event Runtime integration.
- STLS represented explicitly as a capability boundary.
- provider-neutral transport seam and deterministic memory provider.
- native Linux TCP transport through Foreign Runtime v0.22.6 and libc.
- USB architecture records FF/42/01 as interface class/subclass/protocol rather than endpoint addresses.
