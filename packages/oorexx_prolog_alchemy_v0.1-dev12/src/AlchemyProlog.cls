/* ooRexx Prolog Alchemy v0.1-dev12
 * Public ooRexx projection of the native SWI-Prolog bridge.
 *
 * Design rule: Rexx objects describe terms first; native Prolog terms are
 * materialised only when a query is opened.  This preserves late conversion,
 * Rexx object identity, and Prolog variable identity.
 */

::class AlchemyPrologRuntime public
/* Initialise the process-wide native Prolog runtime. */
::method init
  expose nativeRuntime
  nativeRuntime = prolog_native_runtime_new()
/* Create an independently owned Prolog engine for query execution. */
::method engine
  expose nativeRuntime
  return .AlchemyPrologEngine~new(nativeRuntime, prolog_native_engine_new(nativeRuntime))
/* Create a logical-variable specification.  Identity is the Rexx object. */
::method variable
  use strict arg name = "_"
  return .AlchemyPrologVariable~new(name)
/* Create an atom specification without eagerly invoking STRING on value. */
::method atom
  use strict arg value
  return .AlchemyPrologAtom~new(value)
/* Create an integer specification; numeric conversion remains native/late. */
::method integer
  use strict arg value
  return .AlchemyPrologInteger~new(value)
/* Project a live Rexx object into Prolog as an opaque retained identity. */
::method rexxObject
  use strict arg object
  return .AlchemyPrologRexxObject~new(object)
/* Explicitly request atom projection for a Rexx callback result. */
::method callbackAtom
  use strict arg object
  return .AlchemyPrologAtom~new(object)
/* Explicitly request integer projection for a Rexx callback result. */
::method callbackInteger
  use strict arg object
  return .AlchemyPrologInteger~new(object)
/* Describe a structured Prolog term while retaining its Rexx argument graph. */
::method compound
  use strict arg functor, arguments
  return .AlchemyPrologCompound~new(functor, arguments)
/* Describe a proper Prolog list while retaining its Rexx item graph. */
::method list
  use strict arg items
  return .AlchemyPrologList~new(items)
/* Return the version reported by the linked SWI-Prolog runtime. */
::method version
  return prolog_native_version()

::class AlchemyPrologEngine public
/* Bind this Rexx wrapper to one native engine.  Engines own logical state. */
::method init
  expose runtime nativeEngine closed
  use strict arg runtime, nativeEngine
  closed = .false
/* Open a query, materialising the supplied Rexx term specifications late. */
::method query
  expose nativeEngine closed
  use strict arg module = "user", predicate, arguments
  if closed then raise syntax 93.900 array("Prolog engine is closed")
  specs = .array~new
  do a over arguments
    if a~hasMethod("PROLOGSPEC") then specs~append(a~prologSpec)
    else specs~append(.AlchemyPrologAtom~new(a)~prologSpec)
  end
  opened = prolog_native_query_open(nativeEngine, module, predicate, specs)
  return .AlchemyPrologQuery~new(self, opened[1], arguments, opened[2], opened[3], specs)
/* Destroy the engine.  Native code rejects closure while queries remain live. */
::method close
  expose nativeEngine closed
  if \closed then prolog_native_engine_close(nativeEngine)
  closed = .true
  return self
::attribute nativeEngine get
/* Report native shutdown state for lifecycle/mobility qualification. */
::method isClosed
  expose nativeEngine closed
  if closed then return .true
  return prolog_native_engine_is_closed(nativeEngine)
/* Revoke future query use while retaining SWI state for orderly query cleanup. */
::method revoke
  expose nativeEngine closed
  if closed then raise syntax 93.900 array("Prolog engine is closed")
  return prolog_native_engine_revoke(nativeEngine)
/* Return the lifecycle generation used to reject stale query handles. */
::method generation
  expose nativeEngine
  return prolog_native_engine_generation(nativeEngine)
/* Report whether this engine has been administratively revoked. */
::method isRevoked
  expose nativeEngine
  return prolog_native_engine_is_revoked(nativeEngine)
/* Passive evidence: semantic entries currently pinned after serialization. */
::method activeInvocations
  expose nativeEngine
  return prolog_native_engine_active_invocations(nativeEngine)
/* Passive evidence: unreleased queries currently owned by this engine. */
::method liveQueryCount
  expose nativeEngine
  return prolog_native_engine_live_query_count(nativeEngine)

::class AlchemyPrologTerm public
/* Initialise a term projection; zero means it is not yet query-materialised. */
::method init
  expose nativeTerm
  use strict arg nativeTerm = 0
/* Return the bridge-local native term handle. */
::method nativeId
  expose nativeTerm
  return nativeTerm
/* Report whether a materialised term still belongs to a live query. */
::method isLive
  expose nativeTerm
  return nativeTerm <> 0 & prolog_native_term_live(nativeTerm)
/* Render a live native term; unmaterialised terms fall back to their spec. */
::method text
  expose nativeTerm
  if nativeTerm = 0 then return self~prologSpec[2]
  return prolog_native_term_text(nativeTerm)

::class AlchemyPrologVariable public subclass AlchemyPrologTerm
/* Create a logical-variable specification with an optional display name. */
::method init
  expose name nativeTerm
  use strict arg name = "_", nativeTerm = 0
  self~init:super(nativeTerm)
/* Return a spec keyed by this exact Rexx object to preserve repeated identity. */
::method prologSpec
  expose name
  return .array~of("VAR", self, name)
::method name
  expose name
  return name
/* Report whether the live Prolog variable has acquired a binding. */
::method bound
  expose nativeTerm
  if nativeTerm = 0 then return .false
  return \prolog_native_term_is_variable(nativeTerm)
/* Associate this projection with the engine-owned term created for its query. */
::method bindNative
  expose nativeTerm
  use strict arg nativeTerm
  self~nativeTerm = nativeTerm
  return self

::class AlchemyPrologAtom public subclass AlchemyPrologTerm
/* Retain the source object; do not call STRING until native materialisation. */
::method init
  expose value nativeTerm
  use strict arg value, nativeTerm = 0
  self~init:super(nativeTerm)
/* Return the source object itself so native code performs late atom conversion. */
::method prologSpec
  expose value
  return .array~of("ATOM", value)
/* Return the retained source pre-materialisation, or native text afterwards. */
::method value
  expose value nativeTerm
  if nativeTerm = 0 then return value
  return prolog_native_term_text(nativeTerm)

::class AlchemyPrologRexxObject public subclass AlchemyPrologTerm
/* Retain a Rexx object for opaque identity-preserving projection into Prolog. */
::method init
  expose object nativeTerm
  use strict arg object, nativeTerm = 0
  self~init:super(nativeTerm)
::method prologSpec
  expose object
  return .array~of("REXX_OBJECT", object)
::method object
  expose object
  return object

::class AlchemyPrologInteger public subclass AlchemyPrologTerm
/* Retain the Rexx numeric source until native integer materialisation. */
::method init
  expose value nativeTerm
  use strict arg value, nativeTerm = 0
  self~init:super(nativeTerm)
::method prologSpec
  expose value
  return .array~of("INTEGER", value)
/* Return source value before materialisation and the native integer afterwards. */
::method value
  expose value nativeTerm
  if nativeTerm = 0 then return value
  return prolog_native_term_integer(nativeTerm)

::class AlchemyPrologCompound public subclass AlchemyPrologTerm
/* Retain a functor and argument graph for recursive late materialisation. */
::method init
  expose functor arguments nativeTerm
  use strict arg functor, arguments, nativeTerm = 0
  self~init:super(nativeTerm)
/* Recursively convert child projections to specs without flattening identity. */
::method prologSpec
  expose functor arguments
  specs = .array~new
  do a over arguments
    if a~hasMethod("PROLOGSPEC") then specs~append(a~prologSpec)
    else specs~append(.AlchemyPrologAtom~new(a)~prologSpec)
  end
  return .array~of("COMPOUND", functor, specs)
::method functor
  expose functor
  return functor
::method arguments
  expose arguments
  return arguments
::method arity
  expose arguments
  return arguments~items

::class AlchemyPrologList public subclass AlchemyPrologTerm
/* Retain list items for recursive construction of a proper Prolog list. */
::method init
  expose items nativeTerm
  use strict arg items, nativeTerm = 0
  self~init:super(nativeTerm)
/* Recursively build item specs while preserving nested variable identity. */
::method prologSpec
  expose items
  specs = .array~new
  do a over items
    if a~hasMethod("PROLOGSPEC") then specs~append(a~prologSpec)
    else specs~append(.AlchemyPrologAtom~new(a)~prologSpec)
  end
  return .array~of("LIST", specs)
::method items
  expose items
  return items

::class AlchemyPrologQuery public
/* Bind query lifetime to its engine, arguments, terms and materialisation roots. */
::method init
  expose engine nativeQuery arguments termIds closed materializationRoots
  use strict arg engine, nativeQuery, arguments, termIds, variableBindings, materializationRoots
  closed = .false
  /* Keep the complete spec graph alive until query release.  This is what
   * makes late atom STRING conversion and source-object retention reliable. */
  do i = 1 to arguments~items
    a = arguments[i]
    if a~hasMethod("BINDNATIVE") then a~bindNative(termIds[i])
  end
  do binding over variableBindings
    variableObject = binding[1]
    variableObject~bindNative(binding[2])
  end
/* Advance the same native query to its next solution; close on exhaustion. */
::method nextSolution
  expose nativeQuery closed
  if closed then return .false
  answer = prolog_native_query_next(nativeQuery)
  if answer == .nil then do
    self~close
    return .false
  end
  return .true
/* Return the original Rexx-side argument projection by one-based position. */
::method argument
  expose arguments
  use strict arg index
  return arguments[index]
/* Prune remaining choice points, release native query state, and mark closed. */
::method cut
  expose nativeQuery closed
  if \closed then prolog_native_query_cut(nativeQuery)
  closed = .true
  return self
/* Release native query state without requesting an explicit Prolog cut. */
::method close
  expose nativeQuery closed
  if \closed then prolog_native_query_close(nativeQuery)
  closed = .true
  return self
::attribute engine get
/* Return the native engine id that permanently owns this query. */
::method ownerEngineId
  expose nativeQuery
  return prolog_native_query_engine_id(nativeQuery)
/* Return the engine generation captured when this query was opened. */
::method ownerGeneration
  expose nativeQuery
  return prolog_native_query_generation(nativeQuery)
/* Passive evidence: retained Rexx identities still rooted by this query. */
::method retainedObjectCount
  expose nativeQuery closed
  if closed then return 0
  return prolog_native_query_retained_count(nativeQuery)

/* Foreign object projection remains separate from logical term/query state. */
::class AlchemyPrologObject public subclass AlchemyForeignObject
/* Wrap an already-existing foreign Prolog object projection. */
::method init
  expose engine nativeTerm
  use strict arg engine, nativeTerm
  self~init:super
::method foreignRuntime
  return "PROLOG"
::attribute engine get
::attribute nativeTerm get

::requires 'AlchemyForeignObject.cls'
::requires 'prolog_alchemy_native' LIBRARY

::class AlchemyPrologSolutionSource public
/* Adapt an ooRexx Supplier to the explicit productive-backtracking protocol. */
::method init
  expose supplier
  use strict arg supplier
/* Return [hasSolution,value]; SWI REDO invokes this repeatedly until exhausted. */
::method prologNext
  expose supplier
  if \supplier~available then return .array~of(.false, .nil)
  return .array~of(.true, supplier~next)
