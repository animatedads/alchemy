/******************************************************************************/
/* Shared need/opt helpers for domain report adapters.                        */
/* Core AlchemyReport does not load any domain adapter.                       */
/******************************************************************************/
::class ReportAdapterBase public

::method need class
  use arg d, key
  if \d~hasIndex(key) | d[key] = "" | d[key] = .nil then
     raise syntax 40.900 array("evidence missing required field:" key)
  return .true

::method opt class
  use arg d, key, default
  if d~hasIndex(key), d[key] \= .nil then return d[key]
  return default

::method registerInto class
  use arg registry, transformId
  if registry \= .nil then ignore = registry~register(transformId)
  return .true

::requires "../AlchemyReport.cls"
