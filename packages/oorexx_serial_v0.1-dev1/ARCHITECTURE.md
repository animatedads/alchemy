# ooRexx Serial architecture v0.1-dev1

```text
Application
    |
registered frame/data/line events
    |
SerialPort / SerialFrameStream
    |
SerialProvider SPI
   / \
Memory  Linux POSIX
          |
     Foreign Runtime
          |
 open/read/write/poll/termios/ioctl
          |
      OS serial driver
```

## Boundaries

**SerialPort** owns the application identity, configuration intent, event
source and framing attachments.

**SerialConnection** owns one provider-specific open transport.

**Framers** turn byte chunks into messages but do not change raw serial
semantics.  A device protocol may layer further semantic objects above a frame
stream.

**Device Runtime integration** is by identity projection.  A tty discovered by
Device Runtime can be passed to `SerialRuntime~openDevice()` without making
Serial depend on udev.

## Concurrency

`SerialPort~start` hides the native blocking/polling loop from the application.
The implementation waits in provider `pollRead()` and publishes normal Event
Runtime events.  Applications may also call `poll()` explicitly in deterministic
or embedded event loops.

## Future provider parity

A Win32 provider should map the same model to CreateFile/ReadFile/WriteFile,
DCB, COMMTIMEOUTS, WaitCommEvent and EscapeCommFunction.  Those APIs must remain
provider details; the common objects do not change.
