# Rexx queue distinction correction

Correction to the earlier mesh-debug note.

There are two different queue primitives in ooRexx:

- `.Queue` is an in-memory ooRexx object queue for the same ooRexx environment. It is suitable when worker objects can share queue object references through a registry such as a `.Directory`.
- `.RexxQueue` is a named Rexx queue object suitable when a named queue is needed across Rexx activity boundaries or processes.

Design implication:

- `InternalQueueTransport` should wrap `.Queue` objects stored in a shared registry.
- `RxQueueTransport` should wrap `.RexxQueue` named queues.

Do not collapse the two lifecycles.

For `.Queue`, use object operations such as `queue`, `pull`, and `items`.

For `.RexxQueue`, use the named queue object and its own operations such as `push`, `pull`, and `queued`.

The non-destructive lifecycle rule still applies:

- attach/open/ensure should not drain messages;
- purge/reset should be explicit test setup;
- teardown should only remove a named queue when the transport owns it.

Test these as separate ladders:

1. Same-environment mesh using `.Queue` and a registry of queue objects.
2. Named-queue mesh using `.RexxQueue`.

This distinction likely explains part of the confusion around the mesh transport pickle.
