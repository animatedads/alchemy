/* Immutable-by-default scenario report and build-request export.
 * The output is advisory and cannot deploy or mutate infrastructure.
 */
::requires 'ArchitectureScenarios.cls'
::class ArchitectureScenarioWriter public
::method write
  use strict arg comparison, directory
  if comparison['schema'] \== 'alchemy.architecture.scenario-comparison/0.1' then -
    raise syntax 93.900 array('ARCH_COMPARISON_SCHEMA_MISMATCH')
  if SysIsFileDirectory(directory) == 0 then -
    raise syntax 93.900 array('ARCH_COMPARISON_DIRECTORY_MISSING')
  if directory~right(1) == '/' then directory = directory~left(directory~length-1)
  documents = .Directory~new
  documents['scenario-comparison.json'] = comparison
  do scenario over comparison['scenarios']
    id = scenario['id']
    permitted = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-'
    if id~strip == '' | verify(id,permitted) \== 0 then -
      raise syntax 93.900 array('ARCH_COMPARISON_SCENARIO_ID_INVALID')
    prefix = 'scenario-'id
    documents[prefix'-plan.json'] = scenario['plan']
    documents[prefix'-build-request.json'] = scenario['plan']['buildRequest']
  end
  /* Preflight all targets before any write. Not an atomic publication claim. */
  do name over documents~allIndexes
    filename = directory'/'name
    if stream(filename,'C','QUERY EXISTS') \== '' then -
      raise syntax 93.900 array('ARCH_COMPARISON_FILE_EXISTS',filename)
  end
  output = .Array~new
  do name over documents~allIndexes
    filename = directory'/'name
    call lineout filename, .JSON~toJSON(documents[name])
    call lineout filename
    call stream filename,'C','CLOSE'
    output~append(filename)
  end
  return output
