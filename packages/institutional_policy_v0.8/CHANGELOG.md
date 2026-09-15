# Changelog

## v0.8

- Added deterministic post-promotion rollback gates with explicit `ANY`/`ALL` trigger semantics.
- Added immutable rollback assessments: `ROLLBACK_ELIGIBLE`, `ROLLBACK_NOT_REQUIRED`, and `ROLLBACK_INSUFFICIENT_EVIDENCE`.
- Added `assessRollback`, `rollbackAssessments`, and `applyAutomatedRollback` catalogue operations.
- Automatic rollback re-evaluates evidence internally and binds the exact assessment to the rollback deployment; callers cannot submit a forged eligibility object.
- Preserved ordinary authorized manual rollback as an independent incident-response path.
- Fixed rollout evidence freshness so age is measured from each observation's actual `recordedAt`; delayed re-evaluation cannot refresh stale evidence.
- Revalidated against Alchemy Objects v0.8, Legal Effect v0.14, ooRexx Crypto v0.1, and ooRexx 5.3.0 r13196.

## v0.7

- Added sealed `InstitutionalPolicyRolloutCriterion` and `InstitutionalPolicyRolloutGate` fixed acceptance-policy objects.
- Added immutable rollout observations bound to the exact authorized successor policy identity and rollout id.
- Added deterministic rollout assessment with `PROMOTION_ELIGIBLE`, `PROMOTION_BLOCKED`, and `INSUFFICIENT_EVIDENCE`.
- Added minimum sample-size, minimum evidence-window, numeric-threshold and evidence-freshness enforcement.
- Promotion assessment is computed inside `InstitutionalPolicyCatalog~applyDeployment`; callers cannot inject a predeclared PASS result.
- Successful deployment bindings retain the exact assessment; authorized failed promotion assessments remain queryable with `rolloutAssessments`.
- Rollback to the exact prior reviewed artefact remains independent of successor health evidence.
- Rebased Alchemy adoption metadata and validation on Alchemy Objects v0.8.
- Retained Legal Effect v0.14 integration and the fixed-artifact/no-runtime-LLM invariant.


## v0.6

- Adds bounded, authority-backed progressive overlap for exact reviewed successor versions.
- Keeps ordinary overlapping publication forbidden unless an `InstitutionalPolicyProgressiveRequest` is authorized.
- Reuses immutable topology bindings for cross-version canary, cutover and rollback rather than introducing a second routing language.
- Requires deployment context while overlapping versions are operative.
- Fails closed when bounded progressive authorization expires while both versions remain operative.
- Fixes historical topology so future bindings do not rewrite pre-binding periods as `NOT_DEPLOYED`.
- Preserves global lifecycle vetoes and all v0.5 single-version topology behaviour.


## v0.5

- Added explicit immutable deployment topology for exact published policy versions.
- Added `InstitutionalPolicyDeploymentPoint` and sealed service/region/channel/tenant/cohort scopes.
- Added authorized `DEPLOY` requests, decisions and bindings with exact governance-profile/grant provenance.
- Added `ACTIVE`, `STAGED`, `CANARY`, scoped `SUSPENDED`, and `NOT_DEPLOYED` topology states.
- Added deterministic scope precedence (specificity, then effective time) and ambiguity rejection.
- Added topology-aware `resolveForContext` / `executionContextForContext` while retaining legacy global behavior when no topology exists.
- Global suspend/withdraw lifecycle remains a veto over every scoped deployment.
- Rejected retroactive deployment evidence and unbounded/global canary declarations.

## v0.4

- Added immutable effective-dated deployment lifecycle evidence around exact published policy identities.
- Added authorized `SUSPEND`, `RESUME`, `WITHDRAW`, and `RATIFY` lifecycle actions.
- Added `InstitutionalPolicyLifecycleAuthorityEvaluator`; lifecycle actions resolve the authority profile operative at the event time and retain its exact semantic identity and selected grant.
- Added deterministic `InstitutionalPolicyDeploymentState` replay. Suspension blocks operative resolution, resume restores the same immutable artefact, and withdrawal is terminal.
- Kept original publication evidence immutable; lifecycle events do not rewrite author/approver/publisher evidence.
- Publication records now preserve emergency reason and emergency expiry as explicit operational evidence.
- Added emergency ratification evidence without allowing ratification to extend the policy's fixed effective window.
- Added catalogue execution contexts carrying deployment-state identity for historical audit/replay.
- Added tests proving lifecycle authority succession, historical profile identity retention, withdrawal non-reversibility, and ratification semantics.
- Revalidated against Legal Effect v0.14, Alchemy Objects v0.7 and ooRexx 5.3.0 r13196.

## v0.3

- Added deterministic multi-party approval requirements with authority classes, minimum counts, cross-requirement distinct principals, and per-requirement optional/required external evidence.
- Added `InstitutionalPolicyAuthorityProfileCatalog` and `InstitutionalPolicyAuthorityBinding` for effective-dated governance succession and historical resolution.
- Added scoped delegation with parent-grant validation, cycle protection and transitive revocation.
- Added immutable `InstitutionalPolicyAuthorityRevocation` records.
- Added explicit bounded emergency publication using `EMERGENCY_PUBLISHER` authority; emergency policy cannot be retroactive/unbounded and emergency authority does not imply ordinary publisher authority.
- Canonicalized multi-party approval selection independently of request arrival order.
- Added `InstitutionalPolicyApprovalSelection` evidence to publication authority decisions.
- Preserved v0.2 single-approver and identifier-only compatibility paths.
- Extended Alchemy STANDARD verification to the authority-profile catalogue.
- Revalidated against Legal Effect v0.14 and ooRexx 5.3.0 r13196.

## v0.2

- Added fixed, versioned `InstitutionalPolicyAuthorityProfile` governance artefacts.
- Added scoped/effective-dated AUTHOR, APPROVER and PUBLISHER grants.
- Added policy-family authority rules with optional separation of author/approver and optional/required approval evidence.
- Added exact-policy `InstitutionalPolicyApprovalAttestation` and `InstitutionalPolicyPublicationRequest`.
- Added host-pluggable approval evidence verification; cryptographic signing is supported as a possible host proof mechanism but is not mandatory.
- Added immutable `InstitutionalPolicyAuthorityDecision` evidence and enriched publication records with publisher, assurance mode, profile identity and selected grant IDs.
- Added explicit assurance modes `IDENTIFIER_ONLY`, `ROLE_AUTHORITY`, and `VERIFIED_APPROVAL_EVIDENCE`.
- Preserved v0.1 identifier-only catalogue publication when no authority evaluator is configured.
- Made authority-profile semantic identity independent of grant/rule insertion order.
- Updated validation baseline to Alchemy Objects v0.7 and Legal Effect v0.14.

## v0.1

- Initial shared fixed/versioned policy lifecycle, publication catalogue, effective-time resolution, replay guard and operative/counterfactual distinction.
