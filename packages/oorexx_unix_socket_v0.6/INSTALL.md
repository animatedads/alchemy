# Installation / use

## Foreign Runtime

Build or install ooRexx Foreign Runtime v0.22.6 against the ooRexx runtime you intend to use. `foreign.cls` must be resolvable by ooRexx and `libforeign_runtime.so` by the native loader.

Example for an unpacked Foreign Runtime tree:

```sh
export FOREIGN_RUNTIME_HOME=/path/to/oorexx_foreign_runtime_v0.22.6
export REXX_PATH="$FOREIGN_RUNTIME_HOME/rexx${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$FOREIGN_RUNTIME_HOME/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
```

Add this package directory to `REXX_PATH`, or require `unixsocket.cls` by an explicit path.

The libc bridge is resolved relative to `unixsocket.cls` automatically. `OOREXX_UNIX_SOCKET_BRIDGE=/some/bridge.json` may be supplied before first socket use, but the bridge must carry a profile matching an ABI that Foreign Runtime itself qualifies.

## Example

```rexx
server = .UnixSocket~new('SOCK_STREAM')
address = .UnixAddress~pathname('/tmp/example.sock')

call .UnixSocket~unlinkPath address~name
if server~bind(address) \= 0 then do
    say server~errno server~errorText
    exit 1
end
server~listen(16)
peer = server~accept

say .UnixSocket~abiProfile .UnixSocket~abiQualified

::requires 'unixsocket.cls'
```

## Qualification runner

```sh
export REXX=/usr/local/bin/rexx
export OOREXX_HOME=/usr/local
export FOREIGN_RUNTIME_HOME=/path/to/oorexx_foreign_runtime_v0.22.6
./tests/run.sh
```

The runner additionally requires a C compiler and Python 3 for the release-time ABI metadata forcing probe. These are qualification dependencies, not runtime dependencies for applications.

The runner fails if:

- a dedicated `librxunixsocket.so` is present;
- `unixsocket.cls` requires the old `rxunixsocket` native package;
- known x86-64 ABI magic reappears in `unixsocket.cls`;
- the JSON ABI profile differs from the host C headers;
- a mismatched ABI bridge reaches native library loading rather than failing at the Foreign Runtime profile gate.
