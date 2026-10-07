# ooRexx Serial v0.1-dev1

A provider-neutral serial-port object model for ooRexx.

The application API deliberately does not expose `termios`, `DCB`, ioctl numbers,
poll descriptors, native handles, or byte framing loops.

```rexx
serial = .SerialRuntime~new(.LinuxPosixSerialProvider~new)
port = serial~open('/dev/ttyUSB0', .SerialConfiguration~new(115200))

frames = port~framed(.SerialLineFramer~new)
frames~on('frame', processor, 'packet')
port~on('carrier', monitor, 'carrierChanged')

port~start
```

## Core objects

- `SerialRuntime`
- `SerialPortIdentity`
- `SerialConfiguration`
- `SerialPort`
- `SerialLineState`
- `SerialProvider` / `SerialConnection`
- `SerialMemoryProvider`
- `LinuxPosixSerialProvider`
- `SerialDelimiterFramer`
- `SerialLineFramer`
- `SerialFixedLengthFramer`
- `SerialLengthPrefixedFramer`
- `SerialFrameStream`

## Event vocabulary

- `SERIAL.PORT.OPENED`
- `SERIAL.PORT.CLOSED`
- `SERIAL.DATA`
- `SERIAL.FRAME`
- `SERIAL.BREAK`
- `SERIAL.ERROR`
- `SERIAL.PORT.DISCONNECTED`
- `SERIAL.LINE.CTS.CHANGED`
- `SERIAL.LINE.DSR.CHANGED`
- `SERIAL.LINE.DCD.CHANGED`
- `SERIAL.LINE.RI.CHANGED`
- `SERIAL.LINE.DTR.CHANGED`
- `SERIAL.LINE.RTS.CHANGED`

## Linux provider

The Linux provider uses Foreign Runtime v0.22.6 directly against libc for
`open`, `read`, `write`, `poll`, termios configuration, `tcflush`,
`tcsendbreak`, and modem-line ioctls.

The `termios`/`pollfd` layout and constants are explicitly ABI-qualified for
`linux-x86_64-le-lp64`.  No claim is made that those layouts are portable to
other ABIs.

## Design rule

A byte arriving is observation.  Setting DTR/RTS or changing baud is control.
The API does not manufacture an observed line-state transition merely because
a control call was requested.  Providers report line state separately when the
platform can observe it.
