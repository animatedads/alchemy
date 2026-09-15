# Alchemy Objects v0.4.3 security model

## Trust hierarchy

Hosted customer/LLM code is an agent, not a security authority. It executes under an Alchemy-owned ooRexx Security Manager. Service policy is evaluated first. An optional customer/tenant policy is a constrained delegate that can deny additional operations but cannot turn a service denial into an allow.

Protected ooRexx methods are interpreter checkpoints, but protection and cryptographic authorization are separate concepts. A protected method may be:

- allowed/denied by service/tenant policy alone;
- capability-gated by the Security Manager; or
- allowed through the Security Manager while performing final capability consumption in its own body.

Cryptographic evidence proves integrity/provenance according to the configured proof mechanism. It does not convey execution authority.

## Capability binding and expiry

`AlchemyCapabilityAuthority` MAC-authenticates a canonical record containing:

- capability schema/id;
- subject;
- target Alchemy object id;
- operation;
- purpose;
- issued-at text;
- optional `base-day:seconds-of-day` expiry;
- nonce;
- authenticated optional claims (currently including locked-method subkey selection).

The expiry representation avoids one-second precision loss from very large absolute-second numbers under ordinary Rexx numeric precision. `issueForSeconds()` constructs this expiry, including day rollover. `verify()` rejects malformed or expired stamps before authorization succeeds. Since `valid_until` is inside the canonical unsigned record, changing the expiry invalidates the MAC.

Revocation and optional single-use replay protection are enforced by the authority object. Capability ids are uniqueness/indexing handles; they do not need an independent cryptographic digest because the complete record, including the id, is MAC-authenticated.

Wall-clock expiry assumes the service nodes used for issuance and verification have suitably synchronized clocks. It is not a replacement for replay protection, revocation or bounded service policy.

## Introspection and disclosure

Introspection is evidence, not authority. The base object chooses what goes into a disclosure profile, reinstalls its object-specific fixed state emitter immediately before registered-state capture, and seals the resulting payload. A caller cannot make a SECRET slot appear in CUSTOMER output merely by asking Clouseau to see it.

Clouseau deep inspection is separately delegated. `AlchemyInspectorBridge` avoids the legacy automatic ambient-root seeding path. Probe injection remains disabled unless the bridge is explicitly constructed with probes enabled.

## Execution trace disclosure

`sealedExecutionTrace()` is `PROTECTED` and requires an object/operation/purpose-bound capability. STACK and FULL are different authorization purposes:

- `TRACE:STACK` returns bounded frame and target descriptors without arguments;
- `TRACE:FULL` additionally returns argument descriptors and includes values for String arguments.

FULL is therefore a higher-disclosure capability. Neither profile invokes arbitrary target/argument `~string` methods merely to render evidence; non-String values are represented using bounded class/identity descriptors.

The base fixed stack emitter is not Clouseau probe authority. Deep trace/probe installation remains a separate policy/capability decision.

## Method telemetry must not erase access control

`instrumentMethod()` installs an object-specific wrapper only for eligible ordinary methods. It refuses PROTECTED, PRIVATE and PACKAGE-scope methods. This prevents instrumentation from replacing an interpreter-protected checkpoint with an unprotected wrapper or accidentally widening method visibility.

The retained original Method object is copied, made PRIVATE, and installed under an object-private alias. The public wrapper calls that alias and records telemetry. The wrapper preserves guarded/unguarded state.

The current wrapper records propagated SYNTAX failures. Other user/application condition styles are not universally intercepted; code relying on other condition classes should treat the telemetry as invocation/performance evidence rather than a complete exception ledger.

## Crypto-locked execution boundary

Locked methods are represented at rest in the object as authenticated encrypted records plus a small protected dispatch stub. Plaintext method source is materialized only inside the dispatch window. The operating Method is installed under a unique PRIVATE object alias and removed on both success and propagated failure. SOURCE/FULL base introspection is refused while any locked plaintext is materialized.

The key provider independently verifies and consumes the capability before decrypting. A hosted caller may therefore also pass through a non-consuming Security Manager capability rule first. These are independent gates: interpreter policy controls whether the attempt may reach the object; the vault controls whether the method key is released.

The included in-memory provider is an implementation/reference boundary only. Service deployments should be able to replace it with externally held key material. Deep Clouseau inspection is configured not to traverse evidence-sealer, capability-authority or locked-method-vault links, and a sentinel-key regression test verifies that the key does not appear in serialized inspection output.

### Envelope key wrapping

The preferred locked-method provider separates **content encryption** from **access-key revocation**. Each method source record is encrypted once under a per-record content key. One or more subkey envelopes independently wrap that content key. Revoking or consuming one subkey removes only its small key/envelope records; the authenticated method ciphertext remains byte-for-byte unchanged and other envelopes continue to work.

The capability does not contain the wrapping key. Its MAC-authenticated `locked_subkey_id` claim selects which provider-held envelope may be used. The capability authority first verifies object + operation + purpose + claims; the envelope provider then requires the selected subkey and authenticated envelope before releasing plaintext. A single-use envelope is retired when key release succeeds, not when the business method later succeeds.

The reference provisioner derives subkeys/content keys from a 256-bit provisioning master with domain-separated HMAC-SHA-512. The master is never stored as provider state. This is a deterministic KDF arrangement, not a claim that HMAC or ChaCha20 supplies key erasure. If raw subkey bytes escape the trusted provider, deleting the provider copy cannot revoke the escaped copy. Production therefore keeps unwrap keys behind the service/HSM/KMS boundary and gives tenant code only opaque identifiers/capabilities.

## Execution quotas

Execution quotas live in the Security Manager context, not in customer objects. Rules can account by context, method, class+method, object, or object+method. A tenant/customer object cannot increase its quota by mutating its own fields; quota decisions are recorded in the manager audit evidence.

## Method policy and relationships

Method contracts can declare disclosure, instrumentation eligibility, security sensitivity, side effects and authority effects. The structural surface checker rejects inconsistent authority-changing declarations that are not backed by a protected method boundary. Relationship evidence intentionally stores only target identity/class/Alchemy id facts and never the target reference, preventing the introspection layer from silently becoming object-lifetime authority.

## Requirement checks are explicit execution

A requirement declaration never means a check ran. Checker method names are hidden from PUBLIC/CUSTOMER evidence and `runRequirementChecks()` is `PROTECTED`, allowing the hosted Security Manager to gate potentially environment-touching probes. Requirements without a checker remain explicitly `UNCHECKED`; manual host/test assessments are recorded separately with status, time and evidence.

Instrumentation repeat collapse likewise does not erase the fact that activity occurred: counts are retained without retaining repeated payload copies. Disclosure policy applies to point definitions, events and suppression summaries.

## House-standard score

The author-claimed score and independently calculated score are data inside the sealed compliance report. The delta therefore cannot be altered without invalidating evidence. The calculated score is structural: it checks the declared Alchemy house facilities and descriptions, not the semantic correctness or business safety of application code.

## ooRexx 5.3.0 r13196 observations

Executable tests supplied with this package establish:

- a secured routine calling a protected method produces a `METHOD` checkpoint with `OBJECT`, `NAME`, and `ARGUMENTS`;
- on this build, returning `.false` from the Security Manager allows the original protected method to execute;
- returning `.true` matches the published handled-action convention: normal protected-method execution is suppressed and the manager must supply the handled result when the checkpoint expects one;
- attempts by secure code to call `setSecurityManager` can themselves be denied at a `METHOD` checkpoint;
- static `::REQUIRES` is not observed by the per-routine Security Manager in this build.

`AlchemySecurityManager` therefore defaults only to a runtime profile that has been **observed in the current process**. `AlchemySecurityRuntimeProfile~current` performs a two-branch protected-METHOD probe once per process and caches the result. `.false` must execute the real protected body and `.true` must return the manager-supplied handled result before the profile becomes executable. Version text is recorded as evidence but is not an authority decision. A reversed, ambiguous, missing, or failing probe remains unobserved and the manager refuses construction. This deliberately does not extrapolate a surprising METHOD result to CALL/COMMAND/STREAM/etc.

The profile also emits `alchemy.objects.security-runtime-profile/0.1` structured evidence containing the reference continuation/handled returns, the observed profile values, runtime version text, observation status and a `matches_reference` comparison. Alchemy object snapshots carry this record so normative and empirical platform behavior are not conflated.

## Static `::REQUIRES` boundary

The Security Manager must not be represented as a complete package-loading sandbox on the validated interpreter. Hosted LLM/customer packages require dependency-closure validation at an Alchemy-controlled loading/bundle boundary before execution begins. The service must not rely on a `REQUIRES` Security Manager callback that this runtime does not emit for static directives.

## Non-goals / current limits

- This is not a complete process/container sandbox. OS-level isolation remains a separate layer.
- Static dependency closure must be validated before entering hosted code.
- Capability expiry relies on sufficiently synchronized service wall clocks.
- Full Clouseau graph evidence can be large. SOURCE/FULL embeds the concrete receiver package source once and externalizes inherited dependency source by package identity; deep dependency-source collection is a separate forensic operation. Pure-ooRexx cryptography remains correspondingly expensive for very large graph payloads, so routine service introspection should use bounded disclosure profiles.
- Automatic telemetry deliberately does not wrap protected/private/package methods.
- Automatic telemetry currently traps propagated SYNTAX conditions; it is not a universal condition-history mechanism.
- FULL execution-trace evidence can disclose String arguments and must be authorized accordingly.
- Only explicitly registered object variables are exposed by the fixed state emitter; Clouseau inference/probing remains separately controlled.
