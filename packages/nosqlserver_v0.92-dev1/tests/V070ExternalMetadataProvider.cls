/*
 * External-package compatibility probe for v0.70.
 *
 * This deliberately models the pre-v0.69 external adapter assumption: it can
 * expose a relation object but its own package cannot instantiate a NoSQLServer
 * DatabaseTableMetadata class.  Federation must own neutral metadata creation
 * and therefore must not call tableMetadata here.
 */
::class V070ExternalMetadataProvider public
::attribute relation
::attribute metadataCalls

::method init
  use arg relation
  self~relation = relation
  self~metadataCalls = 0

::method table
  use arg tableName
  if self~relation == .nil then return .nil
  if self~relation~definition~name~caselessEquals(tableName) then return self~relation
  return .nil

::method tableMetadata
  use arg tableName
  self~metadataCalls += 1
  t = self~table(tableName)
  if t == .nil then return .nil
  /* Intentionally unresolved in this independent package. */
  return .DatabaseTableMetadata~new(t~definition)
