# Initial decision map (30 questions)

```text
PROJECT PURPOSE / REQUIRED FEATURES
  workload type
  deployment model  ─── local / RexxOS MU-MI / cloud / hybrid / edge
  frontend          ├── web ── HTTPS / WebSocket / both
                    ├── native Wire renderer
                    ├── CLI / NewShell
                    └── headless
  scale profile     ─── single / horizontal / scheduled / elastic
  placement policy  ─── fixed / measured / cost guarded

NETWORK / INTERCONNECT
  local/cloud/hybrid/edge ─── in-process / provider-selected socket / API / XTP
                                  └── if XTP: L2 / native IP36 / UDP outer
  RexxOS MU-MI ────────── XTP only
                           ├── carrier: EtherType 0x817D / IP36 / UDP outer (blocked by default)
                           ├── network scope: L2 / routed / external
                           └── trust: private / authenticated / regulated
  semantic multicast ───── none / XTP group / standards-based IP SSM

CAPACITY / MEMORY
  process local / Memory Fabric / native shared blocks
  if MU-MI fabric: native fenced block bag + XTP control only / not needed

STORAGE AND DATA
  filesystem / Storage Fabric / cloud object / hybrid
  access pattern ────────── transactional / large-random / cold / media
  redundancy ────────────── none / local / multi-site / provider
  durability ────────────── ephemeral / backup / journal + checkpoint
  restore proof ─────────── manual / periodic test / checkpoint qualification
  information model ─────── none / relational / document / graph / object
     if relational ──────── PostgreSQL / MariaDB / DB2 / qualify later

GOVERNANCE / DEPLOYMENT / COST
  security envelope ─────── internal / regulated / public
  identity source ───────── host / directory / federated / isolated
  observability ─────────── basic / Instrumentation Mesh
  target ────────────────── Linux / Windows / Android / RexxOS
  if cloud: OCI / IBM / AWS / Azure / GCP / multi-cloud
  if cloud: purchasing ──── on-demand / committed / interruptible / mixed
  optimization ──────────── monthly / price-performance / sovereignty / availability
  spending governance ───── monthly budget / prior approval / review-only
  if cloud/edge: residency - unrestricted / UK / EU-EEA / explicit approved jurisdictions

OUTPUT
  selected features + rationale + accountable parties
  contextual pending questions + rejected/incompatible choices
  semantic component placement + dependency requirement closure
  cost evidence/comparisons + unexplained financial assumptions
  UNRESOLVED build request -> SSC -> Deployment target qualification/lock
```

Every choice can change later. Hidden answers survive as historical decisions but do **not** contaminate the current effective build request. This enables scenario comparison without suggesting that the site should silently commission infrastructure.
