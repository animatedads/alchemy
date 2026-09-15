# ooRexx Queue Fabric + journal rewind live-patch test

This is deliberately a two-OS-process test. There is no socket listener inside
the runner and no side-channel file carrying the patch. The control object is a
persistent ooRexx Queue Fabric work package.

## 1. Start the runner

Use an empty store directory for a clean run:

```sh
rm -rf /tmp/rexx-livepatch-q
./run_runner.sh /tmp/rexx-livepatch-q 1 100 &
```

The runner executes `X(1)` through `X(100)`. Its mutable `NEXT` value lives in
`JournalPointedState`. Immediately before every `X(i)` the State-of-the-Nation
controller records a pointer-only freeze.

`runner.rex` reopens `ObjectQueueManager` on each loop. That replays the Queue
Fabric durable journal and makes patches written by another process visible.

## 2. Patch X and rewind five

From another shell:

```sh
./send_patch.sh /tmp/rexx-livepatch-q X X_v2.method 5
```

The sender puts an ooRexx `Directory` onto permanent queue `PATCH.INBOX`. It
contains the method name, an ooRexx Array of source lines, and the rewind request. No source file path
is read by the runner; the method source itself is in the queue payload.

Suppose old `X` has just completed 20. `NEXT=21`, so rewind 5 restores the point
before `X(16)`. Code remains patched, therefore 16..20 execute again under v2
and execution then continues with 21.

The original branch ending at `NEXT=21` remains retained and reconstructible.

## 3. Patch it again

The queue remains usable, so another live version can be sent later:

```sh
./send_patch.sh /tmp/rexx-livepatch-q X X_v3.method 3
```

## Direct Rexx commands

When `REXX_PATH` contains this directory plus the ooRexx class directory:

```sh
rexx runner.rex /tmp/rexx-livepatch-q 1 100
rexx send_patch.rex /tmp/rexx-livepatch-q X X_v2.method 5
```

Arguments:

- runner: `storeRoot delaySeconds limit`
- patch tool: `storeRoot methodName sourceFile [rewind]`

The example vendors its exact source closure from Journal Pointed State v0.1,
Queue Fabric v0.9-dev4, Alchemy Objects v0.8 and ooRexx Crypto v0.1.
