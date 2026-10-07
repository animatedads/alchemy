value = .LdapCancelCodec~encodeRequestValue(73)
decoded = .LdapCancelCodec~decodeRequestValue(value)
ignore = .LdapIdentityTest~assert(decoded["ok"], "Cancel request value decodes")
ignore = .LdapIdentityTest~equal(73, decoded["cancelId"], "Cancel target message id")

bad = value || '00'x
decoded = .LdapCancelCodec~decodeRequestValue(bad)
ignore = .LdapIdentityTest~assert(\decoded["ok"], "Cancel trailing bytes rejected")

registry = .LdapOperationRegistry~new
op = .LdapOutstandingOperation~new(9, "TEST", .true)
ignore = .LdapIdentityTest~assert(registry~register(op), "outstanding operation registers")
ignore = .LdapIdentityTest~equal(0, registry~requestCancel(9), "active cancellable operation accepts cancel")
ignore = .LdapIdentityTest~assert(op~cancelRequested, "operation sees cancel request")
ignore = registry~complete(9)
ignore = .LdapIdentityTest~equal(.LdapCancelBuild~RESULT_TOO_LATE, registry~requestCancel(9), "completed operation reports tooLate")
ignore = .LdapIdentityTest~equal(.LdapCancelBuild~RESULT_NO_SUCH_OPERATION, registry~requestCancel(999), "unknown operation reports noSuchOperation")

/* LDAP message IDs are unique only while outstanding.  Completion knowledge
 * must not permanently reserve an ID; a new operation with that ID replaces
 * the old tooLate tombstone. */
reused = .LdapOutstandingOperation~new(9, "RFC4533_REFRESH_AND_PERSIST", .true)
ignore = .LdapIdentityTest~assert(registry~register(reused), "completed message id can be reused")
ignore = .LdapIdentityTest~equal(0, registry~requestCancel(9), "reused message id addresses new outstanding operation")

/* Registries are association-local.  The same LDAP message ID in another
 * association has independent cancellation state. */
otherRegistry = .LdapOperationRegistry~new
otherOp = .LdapOutstandingOperation~new(9, "RFC4533_REFRESH_AND_PERSIST", .true)
ignore = .LdapIdentityTest~assert(otherRegistry~register(otherOp), "same message id valid on another association")
ignore = .LdapIdentityTest~equal(0, otherRegistry~requestCancel(9), "other association cancels its own operation")

say "LDAP CANCEL CODEC: OK"

::requires "tests/TestSupport.cls"
::requires "src/LdapCancel.cls"
