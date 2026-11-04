# ooRexx Virtual USB Gopher Sphere v0.1

Authoritative continuity sphere for the ooRexx Virtual USB device model and its development FIDO2 authenticator.

The current Library executable baseline remains `oorexx_virtual_usb_v0.1-dev9.zip`, SHA-256 `efa8a1e5a31a8ae7e39360b5f9495772ef1132dccb620d1a896320d24edbc8f6`. The current repository/test candidate is dev11, archive SHA-256 `d052144c13e965fa7bc4e6bfbf1c0feed1cb7804eda6d11555e28f48661a33e3`. It closes the independent-review hidraw-generation gap while leaving FIDO/Raw-Gadget semantics unchanged. The sphere is deliberately separate from the executable package: it records architecture, qualification truth, dependency authority, hard-won Raw Gadget lessons, defensive whole-device trust doctrine, and the remaining path to a real hardware authenticator.

The dev9 Library package has passed its semantic/FIDO/Raw-Gadget bridge regression suite under ooRexx 5.3.0 r13196. A clean presenter-owned Linux Raw Gadget generation that reaches HID class binding and hidraw is still the next live acceptance boundary; the earlier dev8 CAFE:F1D0 observation was invalidated because the dev8 presenter itself failed to acquire the already-busy UDC.

The intended hardware continuation is a powered SoC with a USB device controller running the same provider-neutral device/FIDO semantics. A storage image may live on removable or embedded media, but the active SoC is the USB device. Production work must replace deterministic development credential generation and development user-presence/attestation behavior with qualified hardware entropy, protected key storage, physical user-presence, and appropriate attestation.

Start with:

    gopher context virtual-usb

then open the objects named in `packs/virtual-usb/00-sphere.json` `start_here`.
