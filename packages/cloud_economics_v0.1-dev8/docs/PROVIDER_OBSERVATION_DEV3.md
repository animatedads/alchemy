# Cloud Economics dev3 — read-only provider market adapters

The economic manager consumes provider-specific observation facts while remaining
`PAPER_ONLY`. It does not provision, reserve, cancel or purchase resources.
No one can turn on live buying by setting an environment variable.

## The separate meanings of an observed tariff

1. **Advertised price** — the public or account-viewable price of a meter or
   chargeable SKU, with its unit and original price-effective time.
2. **Hardware shape** — vCPU/RAM/GPU capabilities from the provider catalogue.
3. **Available capacity** — current quota, capacity and account authority,
   including entitlement to that exact zone and specific time window.
4. **Total executable-job cost** — all machine, storage, transfer, fabric,
   interruption, currency and lifecycle costs that apply to the job.

The new AWS/GCP collectors can provide the first two only in specific cases.
They NEVER provide steps (3) or (4), and NEVER mark `approved`, `capacity` or
`fabric_ok` true. `CloudEconomicsAuthority.cls` remains the independent
object-rich path to genuine intention, allocator and fabric proofs.

## AWS Spot market observation

Configure a curated read-only EC2 API identity through the standard AWS CLI
credential provider chain (instance role, SSO, etc.); **do not paste credentials
into Cloud Economics files**. CLI must implement EC2 `DescribeInstanceTypes`
and `DescribeSpotPriceHistory`. Each API call is read-only and limited to
configured instance types and regions.

`fixtures/aws_watch.tsv` contains `region` and `instance_type`. Default examples
are London's `eu-west-2` r6i.xlarge and r6i.2xlarge; this is a query allowlist,
NOT a promise that any capacity exists or a declaration of current prices.

```bash
export CLOUD_ECONOMICS_AWS_ENABLE=1
export AWS_WATCH_FILE=/absolute/path/to/aws_watch.tsv
./tools/cloud-cost poll
./tools/cloud-cost providers
./tools/cloud-cost evidence AWS
./tools/cloud-cost trends
```

The collector filters exactly `Linux/UNIX (Amazon VPC)`, chooses the most recent
history event for each returned AZ, and retrieves the actual EC2 instance shape.
The feed is **not** on-demand pricing and is **not** availability evidence. The
Spot `Timestamp` is the time the price changed, which may be older than the
read. `offers.tsv` has the latest retrieval epoch in `ts`, and
`sources/AWS.evidence.tsv` records the original price-effective epoch and a
SHA-256 fingerprint of the two API responses. The API JSON responses themselves
are not retained: this digest supports correlation, not independent third-party
forensic reconstruction.

`startup`, `network`, `fabric` and `risk` are *unknown*, not certified zero:
those fields are placeholders, and the quote carries `approved=0`,
`capacity=0`, `fabric_ok=0`. This makes it ineligible for paper booking until a
**separate trusted** provider-level cost and capacity authority supplies a
complete admissible quote and proofs. Even then this module cannot do live
purchasing. Spot historical prices do not predict uninterrupted capacity.

## Google Cloud component catalogue

Cloud Billing's public v1 Catalog API requires an API key and enabled API.
Set an API key **via your approved secret delivery mechanism** in
`CLOUD_ECONOMICS_GCP_API_KEY`; never write it to source, ledger or job files.
This adapter passes the key to curl via a stdin configuration header to avoid
placing it in curl command-line arguments. Environment visibility and secret
brokers remain the deployment owner's responsibility.

`fixtures/gcp_skus.tsv` is **deliberately empty** except for its header. Add
real, verified Compute Engine SKU IDs with the billing region and semantic role:

```text
sku_id<TAB>region<TAB>purpose
<exact real SKU ID><TAB>europe-west2<TAB>CORE
<exact real RAM SKU ID><TAB>europe-west2<TAB>RAM
```

Allowed purposes: `CORE`, `RAM`, `OTHER`. Enable the collector:

```bash
export CLOUD_ECONOMICS_GCP_ENABLE=1
export CLOUD_ECONOMICS_GCP_API_KEY='(obtain from approved secret broker)'
export GCP_SKU_ALLOWLIST=/absolute/path/to/sku_allowlist.tsv
./tools/cloud-cost poll
./tools/cloud-cost components GCP
./tools/cloud-cost trends
```

The actual API service is Compute Engine `6F81-5844-456A`, with bounded
pagination, exact SKU and region matching, USD and only a *single zero-start*
price tier. A missing SKU, unsupported tier, malformed price or interrupted
page request fails the entire snapshot. It does **not** guess a rate by
combining regionally similar but non-identical SKU descriptions.

GCP outputs `components/GCP.tsv` with its original usage unit (for example `h`
or `GiBy.h`) and `components/history.tsv` for trend observations. Those do not
become `offers.tsv` rows. The suite therefore **cannot** accidentally compare
$0.01/GiB-hour with $0.80/VM-hour or purchase a VM on the strength of a CPU
component price. A separate, externally verified assembly/billing contract is
required to price complete shapes, storage and network.

## Continuous polling, history and prediction

`./tools/cloud-cost watch 60` performs periodic polling and paper scheduling.
Read-only provider API calls are cached by default rather than repeated on every
60-second cycle: AWS 600s, Azure 1800s, GCP catalogue 3600s. Tunable variables:

- `CLOUD_ECONOMICS_AWS_MIN_POLL_SECONDS`
- `CLOUD_ECONOMICS_AZURE_MIN_POLL_SECONDS`
- `CLOUD_ECONOMICS_GCP_MIN_POLL_SECONDS`

`providers` distinguishes `OBSERVED`, `CATALOG_ONLY`, `CATALOG_CACHED`,
`NO_OFFERS`, `UNCONFIGURED`, `STALE`, `ERROR`, `INVALID_DATA` and `INVALID_SCHEMA`.
If a configured poll fails, the previous quote is **not** quietly reused as
current. `components GCP` and `evidence AWS` refuse access through their
current-view interface after error status; previous historical files can still
be inspected separately for audit.

`trends` reports raw billing units, latest observed rate, sample count,
EWMA/slope forecast (one hour ahead only after four historical samples) and
confidence. This is a statistical estimate, **not a validated trained ML model**,
not a price promise, and not a purchase trigger. The existing planner already
keeps the forecast below deadline, budget, runtime and authority gates.

Collection uses a single local flock to avoid colliding with paper accounting.
For estate-wide HA leadership the original Queue Fabric/RTO2 ownership boundary
must be used. Archive retention, account reconciliation, authenticated quota and
live capacity adapters are subsequent explicit engineering work.

## No-cost and security boundary

All cloud-provider adapters default **off**. The package makes no provisioning
API calls. A read-only API request may still consume provider quotas or, subject
to cloud account terms, incur metering charges; check each account's API pricing
before enabling. API keys or credentials are never part of the delivered ZIP.

Qualification uses local fixture responses, **not** claims of live cloud access.
Fixture prices and SKU IDs in `fixtures/gcp_catalog.json` and
`fixtures/aws_observed*.json` are invented test input.
