# Security

- No production POSIX operation invokes a shell.
- No caller path is passed through `SysWordexp`.
- Strong metadata methods fail closed when current runtime semantics are insufficient.
- Empty xattr values/lists are not silently interpreted as successful strong observations.
- Scalar `SysStat` results are explicitly non-coherent.
- Recursive deletion is not implemented in dev1; it waits for descriptor-relative traversal semantics.
