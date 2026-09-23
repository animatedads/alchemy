# Architecture

`oorexx_process` owns a higher semantic contract than Unix process syscalls.

Its public namespace and version are independent from `oorexx_posix`:

- library: `oorexx_process_v0.1`
- API: `oorexx.process/0.1`
- entry class: `.ProcessRunner`

The dev1 provider (`rxprocessnative`) directly implements the currently missing managed-execution substrate with `fork`, `execvp`, pipes, `poll`, `waitpid` and signals. This native provider is an implementation detail, not permission to move Process semantics into POSIX.

If general primitives such as `posix_spawn`, targeted `waitpid`, fd actions or start identity later become available from RxUnixSys / a common POSIX-native substrate, the provider can be replaced without changing the Process API.

## Boundary

Lower layer owns: pid, signal, pipe, spawn/exec/wait primitives.

Process owns: argv preservation, stdio policy, timeout/cancellation, bounded capture, execution/result classification, lifecycle semantics and redacted diagnostics.
