# ooRexx Virtual USB v0.1-dev9 source provenance

## Base

This development cut is derived from Library/SCCC component `oorexx_virtual_usb` artifact:

- `oorexx_virtual_usb_v0.1-dev3.zip`
- SHA-256 `19772e71e5f868f6a5f396d1616efea799ca8543edb9e108d2ab31d058e14976`

The 2026-10-07 Library check found dev3 as the latest stored Virtual USB package and the SCCC project catalogue identifies the same dev3 artifact/hash.

## Qualification inputs used for dev4 package-side testing

- ooRexx 5.3.0 r13196 debug `.deb` supplied in the conversation
  - SHA-256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`
- `oorexx_event_runtime_v0.1-dev1.zip`
  - Library materialized SHA-256 `cb7887a8139cf17789651ee56540fe001de704a22ae29990e2de5fc9bc985def`
- `oorexx_crypto_v0.8.3` Library copy used for qualification
  - materialized ZIP SHA-256 `5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49`
- `oorexx_foreign_runtime_v0.22.6` Library copy used for qualification
  - materialized ZIP SHA-256 `25a7b258b7920c355b96f19807515d6fb6e419687714396589b054a7029ab465`

These hashes record the actual files used for this development qualification. They are provenance evidence, not a substitute for SSC semantic source identity or a Deployment dependency lock.

## dev4 change boundary

The semantic FIDO2/CTAPHID implementation is retained from dev3. dev4 changes the Linux Raw Gadget execution/provider path, adds target-machine live qualification, and makes package-load/runtime requirements explicit. Host enumeration is not claimed until the target script passes on the Raw Gadget machine.

## dev6 host substrate provenance

The target reported that the operating system had been reinstalled.  The
existing `the local test dummy-hcd directory` directory still contained the
previous `dummy_hcd.c`, Makefile and built module, but dev6 does not treat that
old `.ko` as load authority.  The running kernel and its source/build tree are
now authoritative for native-module compatibility; retained source is only a
fallback when the matching kernel source file is unavailable.


## dev8 live-host evidence boundary

The dev8 change is driven by the first dev7 real-host observation: Linux
enumerated CAFE:F1D0 but created no HID interface.  Comparison with the Linux
Raw Gadget API/reference keyboard control loop showed that OUT control requests
are completed through `USB_RAW_IOCTL_EP0_READ`, including zero-length
`SET_CONFIGURATION`; the dev7 provider used `EP0_WRITE` for that status path.
The package-side tests can lock the direction invariant, but dev8 is not accepted
as live-qualified until the target host creates the HID interface/hidraw node.


## dev9 target-evidence correction

The first dev8 target log must not be treated as a provider qualification
result.  Its live script observed a pre-existing `5-1` device with
`CAFE:F1D0`, but the current presenter PID subsequently failed Raw Gadget UDC
registration with `-16` (`EBUSY`).  The selected UDC therefore belonged to an
older generation while the dev8 script was inspecting its sysfs node.

dev9 changes only the evidence/diagnostic boundary around that run; the dev8
EP0 direction repair remains the current provider hypothesis until a clean
presenter-owned generation exercises it.  No conclusion about dev8
`SET_CONFIGURATION` success or failure is retained from the stale-generation
run.


## Raw Gadget reference checked for dev9

The control-direction invariant and live-state sequencing were cross-checked
against `xairy/raw-gadget` commit
`8c6de5448ef2b8e4fc37021208c86c3f4dd579dc`.

Relevant reference material:

- `raw_gadget/raw_gadget.h`: EP0 WRITE answers IN requests, EP0 READ answers
  OUT requests; both are blocking response ioctls.
- `examples/keyboard.c`: `SET_CONFIGURATION` enables the endpoint, applies VBUS
  draw/configured state, and completes the OUT control request with
  `USB_RAW_IOCTL_EP0_READ` length 0.

dev9 intentionally does not change provider configuration ordering merely from
the stale dev8 run. A clean presenter-owned generation is required before any
further provider change is justified.
