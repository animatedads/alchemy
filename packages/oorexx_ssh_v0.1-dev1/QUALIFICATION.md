# Qualification

The required dev1 suite covers:

1. subsystem registration and deny-by-default behavior;
2. no implicit shell;
3. registered exec verb dispatch without shell parsing;
4. endpoint authority independent of registration;
5. Foreign Runtime loading of native libssh;
6. owned native session allocation/free;
7. explicit libssh server-version gate.

A live listener is deliberately not claimed by dev1.
