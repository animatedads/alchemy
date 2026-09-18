# Storage Relation / `:?` Query Projection

> **“That is magnificently silly. And extremely powerful.”**

`storage.fabric.relation/0.1` makes structured information sources projectable
as Storage Fabric namespaces. A PostgreSQL table, NoSQL collection, ooRexx
object collection, EDI dataset, IMAP-derived collection, or another structured
provider can expose a relation without pretending that its native model is a
filesystem.

## Executable dev14 scope: read-only

A mounted relation can be queried through the bounded `:?` syntax:

```text
/customers:?country=GB
/customers:?country=GB&balance>=1000
/customers:?name~Dent
```

The query directory contains stable row identifiers. A row is a directory and
its fields are files:

```text
/customers:?country=GB/10001/name
/customers:?country=GB/10001/balance
```

Opening the row itself through the relation operation core returns a canonical
TAB-delimited representation. Providers receive a parsed `StorageRelationQuery`
AST, never raw SQL or the raw FUSE query text.

Supported predicates are `=`, `!=`, `>`, `>=`, `<`, `<=`, `~` (contains), `^`
(prefix), and trailing `?` (exists). Clauses joined by `&` are ANDed. Percent
escapes are decoded.

`StorageObjectRelationProvider` is the executable reference provider. It is
also directly useful for ooRexx object-backed relations. SQL/NoSQL/EDI adapters
implement the same provider contract and perform safe pushdown only for AST
operations they advertise.

## Snapshot semantics

Storage Fabric already owns snapshotting. Relation query code therefore does
not define an independent time-travel subsystem.

A relation result is an **immutable membership binding** carrying a provider /
Storage snapshot token. Both membership and row versions belong to that
binding. A frozen or explicit-generation namespace must retain the result set
that existed at that generation; it must not re-run a live predicate and then
pretend the changed membership is frozen.

The reference provider demonstrates this rule by retaining exact result
membership under its snapshot token. Real providers should bind that token to
the Storage Fabric snapshot/generation authority and, where supported, a
native database snapshot/transaction identifier.

## R/W design (not executable in dev14)

Write support is deliberately designed but disabled. `:?` query projections
return `EROFS` for write opens.

A future mutation is a **Storage mutation request**, not an SQL statement:

```text
echo 'Ford Prefect' > '/customers:?id=10001/10001/name'
```

means approximately:

1. Resolve mount, relation, row identity and field through the same query
   snapshot used for traversal.
2. Authorise the Storage namespace mutation under the mount's existing
   `StorageWritePolicy` (`READ_ONLY`, `COPY_ON_WRITE`, `TRACKED`, `VERSIONED`,
   etc.).
3. Bind the mutation to row identity, observed row/provider version, Storage
   generation, provider identity, relation identity and field/type metadata.
4. Reject ambiguous query membership, changed identity, stale versions, or an
   unsupported provider mutation capability.
5. Translate the typed Storage mutation into the provider-native operation
   using parameters/bind variables/native object methods; never concatenate
   path/query text into SQL.
6. Commit through the Storage policy/lifecycle path. Publish the resulting
   generation/version only after provider acknowledgement.
7. Emit provenance/audit evidence sufficient to identify the old generation,
   requested mutation, provider result and new generation.

### Planned mutation objects

The reserved provider capabilities in dev14 define the compatibility boundary:

- `MUTATE`
- `COMPARE_AND_SWAP`
- `TRANSACTION`

The intended request shape is:

```text
StorageRelationMutation
  providerId
  relationName
  rowId
  field / operation
  typedValue
  observedStorageGeneration
  observedSnapshotToken
  observedRowVersion
  writePolicy
  authority / provenance
```

Provider adapters may implement update/insert/delete only when their declared
capabilities and the namespace policy permit them. Multi-row mutation requires
an explicit transaction or versioned change-set contract; it must not emerge
implicitly from writing into a query directory.

## FUSE is a projection, not the architecture

`StorageRelationQuery`, providers, results and snapshot bindings are independent
of FUSE. `StorageRelationFuseReadOnlyCore` is one client and exists so a FUSE
RPC dispatcher can delegate `:?` paths without embedding database semantics in
libfuse or the native shim.

This preserves the same relation/query capability for native ooRexx callers,
WebDAV, IMAP-facing components, Queue Fabric services and future Storage Fabric
interfaces.