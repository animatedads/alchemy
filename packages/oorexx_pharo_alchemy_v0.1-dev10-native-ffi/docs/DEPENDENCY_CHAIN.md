# Authoritative Alchemy dependency chain

The earlier dev3 `crypto.cls` blocker was a staging error, not a missing dependency.

The supplied `oorexxapis` corpus contains:

* `current/alchemy_objects_v0.8.zip`
* `current/oorexx_crypto_v0.8.3.zip`
* `current/oorexx_foreign_runtime_v0.22.6.zip`

The selected ooRexx distribution supplies `json.cls`.

For qualification the real source directories were placed on `REXX_PATH` together
with Alchemy Foreign Object v0.2. No fake Crypto or Foreign Runtime classes were
introduced.

The authoritative Foreign Object v0.2 test then executes successfully under the
supplied ooRexx 5.3.0 r13196 runtime and prints:

    ALCHEMY FOREIGN OBJECT v0.2 PASS

Crypto's Foreign Runtime provider remains an optional/native performance path;
its presence is part of the real dependency corpus and must not be mistaken for
a reason to fork or stub Crypto in Pharo Alchemy.
