# dev9 Pharo 12 live execution

Executed against the user-supplied stableStackVM12 plus latest-64 Pharo 12 image.

The live image demonstrated:
- passive `respondsTo:` changes false -> true after compiling a method into the resident class;
- the same resident object then executes the newly installed selector and returns 42;
- an existing method raising `Error` is caught as an exception;
- a genuinely absent selector raises `MessageNotUnderstood`;
- a `BlockClosure` remains callable and identity-stable.

This is real Pharo 12 execution, not a mock. It qualifies the Pharo-side semantics
required by the adapter. It does NOT yet claim that the C adapter has entered the
VM in-process, nor an ooRexx -> Pharo -> ooRexx callback crossing.
