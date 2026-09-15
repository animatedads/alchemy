# Security Effect v0.10 deployment topology

Deployment topology answers **where may this exact reviewed Security policy execute?** It does not answer whether a customer is trustworthy.

## Dimensions

A deployment point contains explicit operational dimensions:

- service
- region
- channel
- tenant
- cohort

A sealed scope may wildcard any dimension. Matching bindings are selected deterministically by greatest specificity and then newest effective start. Equal-specificity/equal-time collisions fail as ambiguous.

## Modes

- `ACTIVE`: operative.
- `CANARY`: operative, explicitly labelled as canary evidence; requires a bounded scope.
- `STAGED`: deployed/prepared but non-operative.
- `SUSPENDED`: locally non-operative.
- no matching binding: `NOT_DEPLOYED`.

Global lifecycle suspension/withdrawal remains a veto.

## No bypass by omitted context

A topology-aware Security catalogue with bindings requires a deployment point. Runtime or replay callers cannot omit context to fall back to global policy resolution. A catalogue with no topology bindings still behaves as the v0.6 global catalogue.

## Example

```text
GLOBAL                                      ACTIVE
service=COMMERCE region=KZ channel=WEB      STAGED
service=COMMERCE region=KZ channel=WEB
  cohort=PILOT                              CANARY
```

A normal Kazakhstan web request receives `POLICY_STAGED`; the pilot cohort runs the exact same immutable policy as a canary; an unrelated Shannon channel may continue to inherit the global active binding.
