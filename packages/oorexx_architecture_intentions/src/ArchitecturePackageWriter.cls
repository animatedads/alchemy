/* A non-executable, reviewable build-request handoff. This writer does not
 * resolve ::requires, select binary artifacts or mutate a deployment target.
 * Input directory must exist; production durability should use FileSystem /
 * journaled publication provided by the estate deployment authority.
 */
::requires 'ArchitecturePlanner.cls'
::class ArchitecturePackageWriter public
::method write
  use strict arg plan, targetDirectory
  if plan['schema'] \== 'alchemy.architecture.plan/0.1' then -
    raise syntax 93.900 array('ARCH_WRITER_SCHEMA_MISMATCH')
  if SysIsFileDirectory(targetDirectory) == 0 then -
    raise syntax 93.900 array('ARCH_WRITER_DIRECTORY_MISSING', targetDirectory)
  if targetDirectory~right(1) == '/' then targetDirectory = targetDirectory~left(targetDirectory~length-1)
  paths = .Directory~new
  paths['architecture-plan.json'] = plan
  paths['questions.json'] = plan['openQuestions']
  paths['decisions.json'] = plan['decisionRegister']
  paths['features.json'] = plan['featureRegister']
  paths['issues.json'] = plan['issues']
  paths['build-request.json'] = plan['buildRequest']
  paths['cost.json'] = plan['cost']
  paths['scope.json'] = plan['scope']
  paths['business-capabilities.json'] = plan['businessCapabilities']
  paths['capability-relationships.json'] = plan['capabilityRelationships']
  paths['ground-rules.json'] = plan['groundRules']
  paths['interconnects.json'] = plan['interconnects']
  paths['connector-reviews.json'] = plan['connectSelectorReviews']
  paths['interconnect-alternatives.json'] = plan['interconnectAlternatives']
  /* Refuse known overwrites before writing any file. No hidden file rotation. */
  do name over paths~allIndexes
    path = targetDirectory'/'name
    if stream(path, 'C', 'QUERY EXISTS') \== '' then -
      raise syntax 93.900 array('ARCH_WRITER_ALREADY_EXISTS', path)
  end
  exportedPaths = .Array~new
  do name over paths~allIndexes
    path = targetDirectory'/'name
    call lineout path, .JSON~toJSON(paths[name])
    call lineout path
    call stream path, 'C', 'CLOSE'
    exportedPaths~append(path)
  end
  return exportedPaths
