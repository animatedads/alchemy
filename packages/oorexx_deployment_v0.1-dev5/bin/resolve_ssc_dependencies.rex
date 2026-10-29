/* Internal CLI for resolve_ssc_dependencies.sh. Inputs are environment paths
 * to newline-delimited entry/provider files so shell quoting never becomes
 * dependency semantics. */
consumer=value('DEPLOY_CONSUMER_ROOT',,'ENVIRONMENT')
entryFile=value('DEPLOY_ENTRY_FILE',,'ENVIRONMENT')
providerFile=value('DEPLOY_PROVIDER_FILE',,'ENVIRONMENT')
outFile=value('DEPLOY_DEPENDENCY_OUT',,'ENVIRONMENT')
if consumer='' | entryFile='' | providerFile='' | outFile='' then do
  say 'FAIL dependency resolver environment incomplete'
  exit 2
end
entries=readLines(entryFile)
providers=readLines(providerFile)
r=.SscDeploymentDependencyResolver~new~resolve(consumer,entries,providers)
lines=r~asTsv
call writeLines outFile,lines
if r~satisfied then do
  say 'RESOLVED dependency-closure components='r~componentArtifacts~items 'component-requirements='r~componentRequirements~items 'package-requires='r~packageRequirements~items
  exit 0
end
say 'FAIL dependency-closure' r~failureReason
exit 4

readLines: procedure
  use strict arg path
  a=.array~new
  s=.stream~new(path)
  dummy=s~open('read')
  do while s~lines>0
    v=s~lineIn~strip
    if v<>'' then a~append(v)
  end
  dummy=s~close
  return a
writeLines: procedure
  use strict arg path, lines
  s=.stream~new(path)
  dummy=s~open('write replace')
  do v over lines; dummy=s~lineOut(v); end
  dummy=s~close
  return
::requires 'SscDeploymentDependencies.cls'
