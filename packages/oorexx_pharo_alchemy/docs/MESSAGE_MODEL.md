# Message model

The boundary primitive is conceptually:

    SEND(receiverIdentity, selector, arguments, authority) -> object | exception

It is not a wire-format commitment.

Rules:

1. Receivers and arguments are live objects when their runtime is resident.
2. A returned foreign object is interned by authoritative runtime identity.
3. Re-crossing an interned object returns the original resident object.
4. Selector discovery is passive: `understands` must not invoke the method.
5. Existing method + exception is a foreign failure, never 'message absent'.
6. ooRexx UNKNOWN composition preserves the receiver's previous UNKNOWN exactly.
7. Pharo `doesNotUnderstand:` is the symmetric unresolved-message seam.
8. Nested Rexx -> Pharo -> Rexx -> Pharo sends are legal and retain identity.
9. Blocks are objects, not callback IDs at the public semantic layer.
10. Collections remain objects unless an explicit value-conversion policy says otherwise.
11. Class objects/metaclasses are objects and may cross the same boundary.
12. Lifetime/release must not allow a stale proxy to alias a newly allocated object.
