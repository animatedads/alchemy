# Adversarial review — v0.15 Rich Evidence / HardWorld boundary

Treat this as a hostile review of an information-preserving safety/evidence
contract.  Do not praise the design unless the claims survive attack.

## Architectural claim

Native XML/EDI/X12/etc. source objects may remain rich and reachable inside an
Algorithm Relation / HardWorld pipeline.  Deterministic identity is supplied by
an explicit canonical evidence contract.  SQL scalar presentation is an
explicit lossy projection boundary.

Librarian/Camera/source evidence remains evidence.  It never becomes HardWorld
authority by type, score, provenance, source format, or confidence alone.

## Claims to attack

C1. `RICH_OBJECT` input hashing never invokes the native object's `STRING`.

C2. `RichEvidenceValue` freezes every field that can affect deterministic output
while still preserving native-object reachability.

C3. Mutating the native source object after evidence capture cannot change the
same frozen Algorithm Input Relation's identity or projected evidence.

C4. Two semantically identical rich wrappers over different native object
instances produce the same canonical identity.

C5. Same visible scalar value with materially different source identity/path
produces a different canonical evidence identity.

C6. Multiple native sources remain multiple source references/rows rather than
being comma-flattened.

C7. `CARDINALITY_ERROR`, `SCALAR_REFUSED`, and invalid source states cannot
silently create a SQL scalar.

C8. Source consistency and enclosing input consistency remain distinct claims.

C9. `RYTAFact~evidence` preserves an evidence object without allowing evidence
to become rule truth automatically.

C10. RYTA canonical materialisation identity changes when evidence provenance
changes even when the explicit Boolean fact value does not.

C11. Equivalent evidence from distinct runtime object instances can reuse the
same materialisation.

C12. Direct SQL/NoSQL exposure of a `RICH_OBJECT` relation fails before provider
execution.

C13. `RichBusinessFactAlgorithmProvider` is an explicit scalar projection and
never emits authority beyond `EVIDENCE_ONLY`.

C14. SQL mutation of the scalar evidence projection through stock NoSQLServer
v0.71 is `SQLUNSUPPORTED` and cannot mutate the rich source.

C15. Metadata, DB Core describe, MySQL PREPARE and cursor FETCH remain outside
provider execution semantics after the new rich type is added.

C16. The native source object can safely be large, cyclic, or non-stringable
because deterministic identity does not recursively walk it implicitly.

C17. `algorithmCanonicalText()` itself is a sufficiently strict contract and
cannot hide mutable resources or dishonest/incomplete provenance.

C18. A source adapter cannot forge `SCALAR_AVAILABLE` after detecting multiple
values without the projection layer being able to detect the lie.

C19. A rich evidence wrapper copied across activities cannot acquire observable
race-dependent semantics through its native object reference.

C20. Explicit promotion policy remains the only legitimate path from evidence
to HardWorld epistemic/authority meaning.

## Attacks specifically requested

- native object `STRING` raises, blocks, mutates state, or has side effects;
- native object has cycles / enormous graph / recursive `STRING`;
- native object mutates after wrapper construction;
- source-ref lexical or typed object mutates after wrapper construction;
- canonical evidence text changes with locale/time/environment;
- same canonical identity supplied for different provenance maliciously;
- duplicate source refs;
- same source node listed twice with different lexical values;
- source paths differing only by namespace alias spelling;
- document replacement reusing an old document ID;
- line/column changes with identical semantic node;
- transformed fact with missing parent/transform identity;
- XML node and EDIFACT component claiming the same source identity;
- source consistency stronger than enclosing input consistency;
- input consistency stronger than source evidence consistency;
- empty source list with `PRESENT` evidence;
- `SCALAR_AVAILABLE` with `.nil` presentation;
- `SCALAR_REFUSED` with non-nil presentation;
- `CARDINALITY_ERROR` with sourceCount 0/1;
- typed value whose `STRING` is lossy;
- typed value is itself a nested rich object;
- native object destruction/lifetime after materialisation;
- evidence object shared by two world facts;
- same evidence attached to opposite fact values;
- fact evidence without `algorithmCanonicalText`;
- direct `RICH_OBJECT` NoSQL mapping added accidentally;
- MySQL protocol attempts to infer a string type for rich objects;
- generic display/render code invokes native `STRING`;
- cache replay after native source mutation;
- materialisation replay under new audit invocation;
- source provenance change with same scalar value;
- same source provenance with changed validation state;
- same source provenance with changed transformation history;
- sourceCount large/pathological;
- malicious control characters in path/identity;
- Unicode source paths/identities;
- canonical length-framing collision attacks;
- source order changes under BAG_UNORDERED versus ORDERED;
- conflicting source order influencing which scalar is chosen;
- SQL projection accidentally becoming the only retained evidence copy;
- explicit projection then later code attempting to reconstruct the native object.

Minimum: 45 adversarial cases.

## Mutation catalogue requested

Produce at least 30 mutations, including:

- replace `algorithmCanonicalText` with `~string`;
- omit source path from canonical identity;
- omit validation state;
- omit processing history;
- omit source consistency hash;
- collapse source/input consistency;
- allow RICH_OBJECT -> VARCHAR mapping;
- make `scalarValue` return presentation for SCALAR_REFUSED;
- choose first source on CARDINALITY_ERROR;
- comma-join source paths;
- drop second source row;
- copy native object string into canonical text;
- re-read native object at provider evaluate time;
- let evidence change rule truth implicitly;
- omit evidence from RYTA canonical input;
- use object identity/address in canonical input;
- permit evidence lacking canonical contract;
- allow SQL UPDATE into rich source;
- promote EVIDENCE_ONLY to PERMITTED;
- equate validation VALID with authority;
- equate source format with authority;
- equate confidence with authority;
- strip source document identity;
- strip transformation identity;
- treat FROZEN_OBSERVATION as COORDINATED_SNAPSHOT;
- use only scalar value for content hash;
- deduplicate duplicate source refs silently;
- sort ordered evidence when order is semantic;
- preserve incidental runtime ordering when order is not semantic;
- allow metadata discovery to execute provider.

## Questions that should remain uncomfortable

1. Is a hand-authored `algorithmCanonicalText()` contract sufficient, or should
   rich evidence have a structural canonical encoder owned by Algorithm Relation?
2. How should canonical identity represent nested typed objects without
   stringifying them?
3. Should native source lifetimes be managed by explicit source-document leases?
4. Should a rich fact expose validation findings as another relation/object
   rather than one `validationState` string?
5. Should HardWorld rules ever inspect provenance directly, or should provenance
   always be promoted into explicit typed facts by a separate policy layer?
6. How should source consistency and relation consistency combine for a rule
   requiring a minimum evidence grade?
7. What prevents a dishonest adapter from claiming `SCALAR_AVAILABLE` after
   flattening an ambiguous source upstream?
8. What source/component signature is required before a rich adapter is trusted
   to create evidence for safety-critical HardWorld policies?

## Required answer

Return:

A. Executive verdict
B. Claim table C1-C20
C. Canonical identity attacks
D. Native object lifetime/mutation attacks
E. SQL flattening attacks
F. Evidence -> authority boundary attacks
G. At least 45 adversarial cases
H. At least 30 mutants
I. BLOCKER / SHOULD_DO_NEXT / DEFER / REJECT
J. Machine-testable contract changes
