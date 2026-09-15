# QueueRexx domain constants and dispatch doctrine

## 1. Rule

A fixed value belongs to the class that owns its meaning.

QueueRexx should not reproduce Bash-style logic by replacing shell tests with ooRexx string tests. Internal code should use class-owned constants, and differing behaviour should normally be expressed through message dispatch.

```rexx
::class QueueState
::constant RUNNING 3

if job~state == .QueueState~RUNNING then ...
```

not:

```rexx
if job~state == "running" then ...
```

## 2. Boundary tokens versus internal values

QueueBash compatibility requires exact external spellings. QueueRexx therefore owns those spellings as boundary constants beside the internal typed value:

```rexx
::class QueueState
::constant RUNNING 3
::constant NAME_RUNNING "running"
```

`QueueState~fromName()` converts a filesystem/CLI token to an internal constant once. `QueueState~name()` converts back only for paths, compatibility JSON, CLI output or persistence.

Business logic compares `RUNNING`, never the raw spelling.

This gives QueueRexx both requirements at once:

```text
external compatibility:  "running"
internal meaning:         .QueueState~RUNNING
```

## 3. Current owning classes

Examples in the current design include:

```text
QueueState              queue lifecycle values + QueueBash names
QueueJobObservation     LIVE / DEAD / UNKNOWN / LAUNCH_PENDING
QueueRunnerKind         auto / direct / systemd boundary identities
QueueProviderCategory   provider-family identities
QueueCommandName        CLI command names
QueueOption             CLI option names
QueueSchema             JSON schema identifiers
QueueRecord             QueueBash field names
QueueSystemdState       ActiveState/SubState values
QueueSystemdProperty    systemctl property names
QueueEvent              event names
QueueObservationKind    Observation stream kinds
```

The mutation kernel adds `QueueMutationStatus`, `QueueTransitionPhase`, `QueueLockActor`, `QueueMutationPath`, and transition schema constants. Dev7 extends the same doctrine to `QueueWLUMode`, `QueueWLUProjectionState`, `QueueWLULifecyclePhase`, `QueueWLUTerminalKind`, `QueueWLUCloseAction`, `QueueWLULifecycleStatus`, and status-projection relation values. Future constants likewise belong on their natural owner rather than in a global constants bag.
`QueueWLUProjectionState` lives in the dependency-neutral core because status rendering needs the vocabulary even when the external WLU authority package is not loaded; only conversion from external `.WLUReservationState` lives in the WLU integration adapter.

## 4. Constants do not replace polymorphism

A constant is appropriate when code genuinely needs to represent or compare a domain value. It is not a substitute for OO dispatch.

Bad shape:

```rexx
if provider~id == .QueueRunnerKind~SYSTEMD then callSystemd
else if provider~id == .QueueRunnerKind~DIRECT then callDirect
```

Preferred shape:

```rexx
observation = provider~observe(job)
provider~terminate(job)
```

The provider registry/selector chooses an object. After selection, its messages provide the implementation-specific behaviour.

## 5. No accidental cascade comparisons

ooRexx `~~` is a message cascade and returns the receiver. Value-returning comparisons therefore use ordinary `~` message sends:

```rexx
if job~state == .QueueState~RUNNING then ...
```

not:

```rexx
if job~~state == .QueueState~~RUNNING then ...
```

## 6. Serialized values

JSON, CSV/TSV and YAML renderers may emit external string labels, but serialization itself remains exclusively owned by the stock ooRexx JSON, CSVStream and YAML classes. Constants define domain vocabulary; they do not justify manual format construction.
