# Changelog

## v0.14
- Require origin execution-evidence identity before opening a continuation; Security validation alone is not proof that work started.
- Combined continuation/invocation consumption now fails closed on a consumption race and never restores replayability.

- Added sealed/versioned `SecurityContinuationPolicy` (`security.continuation.policy/0.1`) for long-lived operation and irreversible-commit freshness.
- Added `SecurityContinuationEvidence` linking a validated exact invocation to a stable operation/business-intent identity without granting authority.
- Added `SecurityCommitEvidence` for exact staged-state identity, live context and observation time immediately before publication.
- Added `SecurityCommitActionFactory` so COMMIT is itself a fresh exact `METHOD_INVOCATION` and can be evaluated against the current Security snapshot.
- Added `SecurityContinuationGuard` with continuation expiry, commit-evidence expiry, state/context substitution protection, current-snapshot enforcement and single-use commit replay protection.
- Added optional `SecurityContinuationAccessPermissionsBridge`; successful Permission ALLOW consumes both commit-invocation and continuation validations while Permission DENY consumes neither.
- Added canonical TOCTOU regression: initially safe transfer is held at COMMIT after new account-takeover evidence; changed staged amount/state cannot reuse the old commit assessment.
- Component API advances to `security.effect/0.14`; canonical decision policy remains `security.policy/0.5`.

## v0.13

- Added sealed `SecurityInvocationEvidence` for exact invocation id, deterministic argument identity, invocation-context identity and observation time.
- Added sealed/versioned `SecurityInvocationPolicy` and stateful `SecurityInvocationGuard` with expiry, future-skew, argument/context substitution and single-use replay protection.
- `SecurityDecisionTrace` now retains full Security action and snapshot identities; `SecurityPermissionBinding` canonical form advances to binding/2 and carries those identities plus exact invocation evidence identity.
- Added `SecurityMethodActionFactory~createInvocation` and `SecurityPermissionBindingFactory~fromInvocationAssessment`.
- Extended the optional Access Permissions bridge with invocation validation and consume-after-ALLOW semantics; Permission denial does not burn otherwise fresh Security evidence.
- Added invocation-aware Alchemy Security Manager adapter that derives identity from the live METHOD checkpoint and blocks stale Security assessments before a second Permission decision can be produced.
- Added downstream compatibility qualification for unchanged ooRexx Access Permissions v0.1 and FederationBank Staff Method Permissions v0.1.
- Component API advances to `security.effect/0.13`; canonical Security decision-policy schema remains `security.policy/0.5`.

## v0.12
- adds exact method/object `SecurityMethodActionFactory` and immutable `SecurityPermissionBinding`;
- adds optional deterministic adapter into ooRexx Access Permissions v0.1 without making Permissions a core Security Effect dependency;
- proves Security `ALLOW` is evidence only and remains denied until an exact Permission policy authorizes the subject/object/class/method tuple;
- proves a Permission `ALLOW` cannot erase Security `HOLD` or `REVIEW_REQUIRED`;
- proves exact method authority does not float across object identity;
- combines `REVIEW_REQUIRED` permission denial with durable Relationship Case referral while preserving unrelated method authority;
- qualifies against current ooRexx Crypto v0.5, Alchemy Objects v0.8, Institutional Policy v0.8, Interaction Event v0.3, Relationship Case v0.2, and Access Permissions v0.1;
- retains Security rule schema `security.policy/0.5`.

## v0.11
- adds optional deterministic Security -> Relationship Case review referral bridge;
- adds sealed/versioned `security.review.referral/0.1` policy with deterministic rule selection;
- uses stable assessment-derived case and command ids for exact retry idempotency;
- attaches opaque subject, Security assessment, and referral-policy references only;
- never creates Relationship Case `DECISION` or `ACCOUNT_CONTROL` authority;
- proves referral alone cannot satisfy `MARK_ACTION_REQUIRED`;
- retains Institutional Policy v0.8 and Security rule schema `security.policy/0.5`.

## v0.10

- Rebased on Institutional Policy v0.8 and retained Alchemy Objects v0.8 / Interaction Event v0.3 compatibility.
- Added executable Bouncer integration for fixed post-promotion health monitoring and evidence-backed automatic rollback eligibility.
- Demonstrates healthy production evidence leaving v2 operative and degraded false-positive metrics routing the same customer evidence back through exact reviewed v1.
- Deployment health metrics remain outside `SecuritySnapshot`; automatic rollback changes policy selection, not customer evidence.
- Manual authorized rollback remains an independent incident-response path.
- Retains canonical Security policy schema `security.policy/0.5`; component API advances to `security.effect/0.10`.

## v0.9

- Rebased on Institutional Policy v0.7 and Alchemy Objects v0.8.
- Added executable evidence-gated Bouncer progressive rollout acceptance.
- Proves insufficient sample sizes, threshold breaches, fresh passing evidence, evidence-backed cutover and ungated rollback to the exact prior reviewed policy.
- Proves rollout metrics/assessments remain deployment-governance evidence and never enter the customer's Security snapshot.
- Revalidated the cross-domain rich-object bridge against Interaction Event v0.3.
- Retains canonical Security policy schema `security.policy/0.5`; component API advances to `security.effect/0.9`.


## v0.8

- Consumes Institutional Policy v0.6 progressive rollout.
- Allows bounded coexistence of exact reviewed Security policy versions with explicit deploy authority.
- Demonstrates v1 ordinary cohort, v2 canary cohort, broad v2 cutover, and exact v1 rollback.
- Historical replay remains version/topology correct after later cutover or rollback bindings.
- Keeps canonical policy schema `security.policy/0.5`; component API advances to `security.effect/0.8`.


## v0.7

- Integrated Institutional Policy v0.5 scoped deployment topology.
- Added deployment-aware runtime and historical replay using explicit service/region/channel/tenant/cohort context.
- Added executable ACTIVE/STAGED/CANARY topology behavior with more-specific scope precedence.
- Closed a topology-bypass path: once bindings exist, omitting deployment context returns `DEPLOYMENT_POINT_REQUIRED` instead of falling back to global resolution.
- Kept customer/security evidence strictly independent from deployment/governance evidence.
- Deliberately retained canonical Security policy schema `security.policy/0.5`; deployment location changed, not the Security rule language.

## v0.6

- Integrated Institutional Policy v0.4 deployment lifecycle evidence.
- `SecurityPolicyCatalog` now accepts a separate lifecycle-authority evaluator in addition to publication authority.
- Catalog-backed Bouncer runtime assessments stop with explicit `POLICY_SUSPENDED` or `POLICY_WITHDRAWN` rather than silently evaluating a policy no longer operative in deployment.
- Resume restores the exact same immutable security policy artefact; it does not create or mutate customer/security evidence.
- Added emergency-policy ratification evidence while preserving the original bounded expiry.
- Added `SecurityPolicyReplayEngine~replayPublished` for deployment-aware historical replay through a published catalogue.
- Deliberately retained canonical policy schema `security.policy/0.5`; v0.6 changes deployment governance/API mechanics, not the policy rule canonical format, so semantic identities do not churn merely because the component release advanced.
- Preserved all Kazakhstan/gold, Barbie, exploit-probe, cross-domain mapping, capability-envelope and deterministic decision behaviour.

## v0.5

- Updated to Institutional Policy v0.3 governance mechanics.
- Added executable Security payment-policy publication requiring independent `SECURITY` and `FINANCE` approvals.
- Added Security authority-profile succession test proving historical publication evidence remains bound to the old governance identity after a successor profile becomes operative.
- Added bounded emergency Security-policy publication test using explicit `EMERGENCY_PUBLISHER` authority.
- Preserved all Bouncer action/evidence semantics and existing Kazakhstan/gold, Barbie, exploit-probe, capability-envelope and replay behavior.
- Policy schema/API advanced to `security.policy/0.5` / `security.effect/0.5`.

## v0.4

- Integrated Institutional Policy v0.2 publication-authority enforcement.
- `SecurityPolicyCatalog` can receive an `InstitutionalPolicyAuthorityEvaluator` while retaining the legacy constructor/publication path when host governance does not configure one.
- Added executable Security-policy publication tests for separately scoped AUTHOR, APPROVER and PUBLISHER authority.
- Fixed Security canonical field separators to use a real LF byte (`'0a'x`) instead of literal `\\n`; semantic identities intentionally changed at the v0.4 policy-schema boundary.

## v0.3

- Extracted common institutional policy lifecycle into `institutional_policy_v0.1`.
- `SecurityPolicyCatalog` inherited shared catalogue and replay mechanics while preserving Security-specific semantics and `SecurityResult` compatibility.

## v0.2

- Added policy lifecycle/replay, capability-envelope merging, cross-domain mapping policy and corrected scenario time semantics.

## v0.1

- Initial Security Effect / Bouncer implementation.
