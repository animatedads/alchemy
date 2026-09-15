# Rating-engine research notes for AJI v0.6

These sources are architectural references, not AJI production rules or rates.

## Cost-level quote construction and overrides

Guidewire PolicyCenter documents rating as producing a series of `Cost` objects which are used to
calculate a quote, with controlled override of individual cost attributes. This supports AJI retaining a
component worksheet rather than only a final premium.

https://docs.guidewire.com/cloud/pc/202507/cloudapibf/cloudAPI/topics/124-PCsupport/00-quoting/c_rating_overrides.html

## Tables, factors and term proration

Guidewire's product-model glossary describes rate-scalable risks as looking up a rate using dimensions
such as vehicle type, coverage terms, date and state, often through a table; other factors then adjust
the rate, and the final term cost is prorated to the portion of the policy for which it applies. AJI v0.5
therefore separates exact factor-table selection from explicit proration evidence.

https://docs.guidewire.com/cloud/apd/qusar/create/topics/c_glossary.html

## Rate modifiers / IRPM-style controls

Guidewire documents scheduled rate modifiers with multiple factors, min/max ranges and optional
justification, and notes their use for commercial-line Individual Risk Premium Modification. AJI v0.5
models a small kernel version of this: bounded factor selection plus justification/authorising principal.

https://docs.guidewire.com/cloud/apd/qusar/create/topics/c_rate-modifiers.html
https://docs.guidewire.com/cloud/is/202603/cloudapibf/cloudAPI/PolicyCenter/job-policies/modifiers/c_modifier_validation.html

## Rating lifecycle governance

Duck Creek describes rating as configurable rating logic with reusable structures, lifecycle management,
audit controls and what-if analysis. AJI's immutable plan/function identities and separate publication
step are consistent with that class of rating-governance architecture.

https://www.duckcreek.com/product/insurance-rating-system/

## Effective dating

Guidewire APIs expose effective-dated resources using an as-of date, illustrating the broader policy-
administration requirement to distinguish current system state from the state applicable at a particular
effective date.

https://docs.guidewire.com/cloud/is/202603/cloudapibf/cloudAPI/Basic-REST-operations/query-parameters/c_the-asOfDate-query-parameter.html

## Existing v0.2 tax principle

HMRC IPT material demonstrates why tax needs an explicit taxable basis rather than a universal assumed
subtotal. AJI continues to model tax bases explicitly and does not copy any jurisdictional rate into the
engine as a production default.

https://www.gov.uk/hmrc-internal-manuals/insurance-premium-tax/ipt05150
