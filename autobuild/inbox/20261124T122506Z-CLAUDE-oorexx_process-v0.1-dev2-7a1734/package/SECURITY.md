# Security

- The normal provider never constructs a shell command string.
- argv elements are passed as discrete exec arguments; shell metacharacters have no special meaning.
- captured output is bounded by `maxOutputBytes` while the provider continues draining pipes to avoid child deadlock.
- unsupported environment overlays and detached execution fail closed in dev1.
- secrets should not be placed in argv. A future environment/secret-injection contract must preserve that rule.
