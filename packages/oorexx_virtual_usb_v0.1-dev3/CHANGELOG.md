# Changelog

## v0.1-dev3

- added generic interface descriptor model;
- added HID profile shorthand to `oorexx.virtual.usb.device/0.3`;
- standard interface-recipient `GET_DESCRIPTOR` now serves class/report descriptors;
- added FIDO2 USB HID development profile;
- added CTAPHID 64-byte packet framer/reassembler and channel allocation;
- added CTAPHID PING and CBOR paths;
- added minimal deterministic CBOR codec for CTAP2 values;
- added CTAP2 GetInfo, MakeCredential and GetAssertion;
- added Ed25519 credential/signature path through ooRexx Crypto v0.8.3;
- added discoverable development credential store;
- added user-presence policy seam;
- added semantic FIDO2 Event Runtime events;
- retained dev2 crypto-generator example and Raw Gadget provider behavior.

## v0.1-dev2

- declarative `/0.2` device profiles via `json.cls`;
- semantic USB function grouping;
- first-class mapped control objects;
- provider-confirmed configuration state and reconfiguration handling.
