# Grid dev17 native runtime results (29 October 2026)

The exact ooRexx 5.3.0 r13196 interpreter, LDAP Identity dev22, RPC Service Core dev1 and Grid dev15 were used locally. The original dev16 test failed with Error 99.914 because INTERPRET cannot contain ::REQUIRES. Fixed with static ::REQUIRES. Malformed RPC context formerly returned INTERNAL; the wrapper now emits UNAUTHENTICATED for non-Directory/non-Table contexts. The estate read is allowed only with active principal ACL; ungranted management, disabled principal and unpublished methods are rejected.

Native auth test PASS; native RpcServiceDispatcher wrapper test PASS; Python static checks 5/5 PASS. Neither a production LDAP Bind nor live ED209 dispatch/20-MI work is qualified by these tests.
