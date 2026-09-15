# Design: replayable IBM big iron

## Governing invariant

If a value can change future guest execution, it belongs in the machine freeze boundary or the machine must refuse to freeze while that value is live and unmodeled.

## Ownership

```text
IBM4361Machine
  +-- IBM370CPU
  |     +-- IBM370PSW
  +-- IBM370Storage
  +-- IBM370Clock
  +-- IBM370ChannelSubsystem
        +-- IBM370ChannelProgram ...
        +-- IBM370IODevice ...
```

The CPU does not own host files. Devices do not own CPU state. Channel programs are first-class stateful objects. The state codec composes versioned state and rejects unknown attachment/state shapes.

## IPL correctness boundary

v0.1 made the first 24 bytes visible but loaded the PSW too early. v0.2 corrects that architectural boundary.

The implied IPL CCW reads 24 bytes to absolute zero with Read, count 24, command chaining and SLI. The channel then fetches the CCW at absolute 8. Only when the IPL channel program ends successfully is the PSW at absolute zero loaded.

This gives us useful deterministic freeze points inside boot itself.

## Explicit v0.2 support

- implied Read IPL
- CCW0 decode and reserved-bit checks
- command chaining
- TIC
- SLI and skip interpretation
- sequential Read fixture
- active channel-program freeze/reload
- sequential-media record-position freeze/reload
- completed-machine and mid-channel deterministic replay

## Deliberate v0.2 omissions

- CPU instruction fetch/decode/execute
- full S/370 BC/EC PSW semantics
- data chaining
- IDA
- non-IPL PCI interruption presentation
- channel pending-interrupt serialization
- CKD DASD
- real tape transport
- card reader / punch / printer
- 3270
- DAT
- host-time mapping

These are omissions, not synthesized defaults. Unsupported future-determining state fails closed.

## Next useful work

The MVT turnkey corpus should drive the next devices rather than speculation:

1. inventory the Hercules configuration and media/device addresses;
2. add a file-backed read-only media identity object (path is configuration, digest is identity);
3. implement the actual IPL device type used by the turnkey system (likely CKD DASD unless a tape/card install path is selected);
4. use Hercules plus IBM manuals to oracle each device command encountered;
5. when the IPL PSW finally transfers control, implement only the guest CPU opcodes execution actually reaches;
6. retain a freeze/replay proof at each new machine-state boundary.
