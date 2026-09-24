/* Boundary object linking catalogue origin to an external physical/manufacturing instance.
 * stateRef is deliberately opaque: Physical Manufacturing / Physics owns the state.
 */
::class ManufacturedPartProjection public
::attribute instanceId get
::attribute definition get
::attribute stateRef get
::attribute revision get
::attribute provenance get

::method init
  expose instanceId definition stateRef revision provenance
  use strict arg instanceIdArg,definitionArg,stateRefArg=.nil
  instanceId=instanceIdArg~string
  definition=definitionArg
  definition~validate
  stateRef=stateRefArg
  revision=0
  provenance=.directory~new
  provenance['PART_DEFINITION_ID']=definition~id

::method advanceState
  expose stateRef revision
  use strict arg newStateRef
  stateRef=newStateRef
  revision+=1
  return revision

::method definitionId
  expose definition
  return definition~id

::requires 'PartsCatalog.cls'
