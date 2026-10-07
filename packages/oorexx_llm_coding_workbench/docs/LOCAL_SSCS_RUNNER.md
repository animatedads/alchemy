# Local SSCS runner

This is the non-web access path for the coding workbench.

## One-shot

```sh
SSCS_ROOT=/path/to/semantic-source-store \
NOSQLSERVER_ROOT=/path/to/real-nosqlserver \
ALCHEMY_ROOT=/path/to/current-alchemy-objects \
CRYPTO_ROOT=/path/to/oorexx-crypto \
REXX=/path/to/rexx \
./tools/run_local_sscs.sh /var/lib/sscs PING
```

The same runner exposes `BOOTSTRAP`, `BUTTONS`, `MODEL`, `CREATE_PACKAGE`, `ADD_REQUIRES`, `CREATE_CLASS`, `ADD_ATTRIBUTE`, `ADD_METHOD`, `LIST_CLASSES`, `WRITE_METHOD`, `VIEW_CLASS`, `VIEW_METHOD`, `VIEW_ATTRIBUTE`, and `MATERIALISE`.

## Persistent controller session

```sh
./tools/run_local_sscs_session.sh /var/lib/sscs package/member.rex
```

Protocol currently supports `PING`, `BUTTONS`, `VIEW_CLASS`, `VIEW_METHOD`, `WRITE_METHOD`, and `MATERIALISE`; arbitrary string payloads are hex encoded.

This session exists so the LLM coding controller can keep local semantic context and invoke the Development Desk directly without a website.
