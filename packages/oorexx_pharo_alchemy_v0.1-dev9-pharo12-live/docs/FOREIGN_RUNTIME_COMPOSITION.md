# Foreign Runtime composition

Foreign Runtime v0.22.6 remains the generic native substrate. Pharo Alchemy must not create a parallel generic FFI. Reuse dynamic library loading, ABI qualification, managed opaque resources, pinning and call-thread libffi callback/re-entry. The Pharo provider owns only VM identity/rooting, live selector discovery/send, exception mapping and VM-context rules.

Initial callbacks preserve Foreign Runtime's call-thread/call-lifetime rule. Arbitrary asynchronous Pharo Process re-entry is outside this contract until explicitly designed.
