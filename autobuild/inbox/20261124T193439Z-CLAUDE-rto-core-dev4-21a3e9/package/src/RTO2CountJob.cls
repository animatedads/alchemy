/* RTO2 qualification job: state is the committed integer counter. */
::class RTO2CountJob subclass AlchemyClusteredApp public
::attribute value get
::attribute committedValue get

::method init
  expose value committedValue
  value = 0
  committedValue = 0
  forward class (super)

::method rtoExportState public
  expose value committedValue
  d=.Directory~new
  d["value"]=value
  d["committedValue"]=committedValue
  return d

::method stateFor
  expose committedValue
  use strict arg proposed
  d=.Directory~new
  d["value"]=proposed
  d["committedValue"]=committedValue
  return d

::method rtoImportState public
  expose value committedValue
  use strict arg d
  value=d["value"]+0
  committedValue=d["committedValue"]+0

::method rtoCommitReplayState public
  expose value committedValue
  committedValue=value

::method rtoRollbackToCommitted public
  expose value committedValue
  value=committedValue

::method nextValue
  expose value
  return value+1

::method commitMirroredValue
  expose value
  use strict arg proposed, sequence
  value=proposed
  return self~commitMirroredState("COUNT-"||proposed,sequence)

::method commitLocalValue
  expose value
  use strict arg proposed
  value=proposed
  return self~commitState("COUNT-"||proposed)

::method rtoCommitLocalState public
  expose value committedValue
  committedValue=value

::method rtoBind public
  return .true

::method rtoActivate public
  use arg epoch
  return .true

::requires "AlchemyClusteredApp.cls"
