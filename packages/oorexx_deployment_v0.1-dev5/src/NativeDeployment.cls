/* Generic native-artifact deployment semantics.  A native object is accepted
 * because the declared load/use probe passes on the target, not because its
 * filename or build-host ABI looks plausible.
 */
::options numeric inherit

::class NativeArtifactDeclaration public
::method init
  expose artifactId binaryPath sourceRoot buildCommand probeCommand policy metadata
  use strict arg artifactId,binaryPath,sourceRoot='',buildCommand='',probeCommand='',policy='reuse-if-loadable-else-rebuild',metadata=.nil
  if metadata==.nil then metadata=.directory~new
::method artifactId; expose artifactId; return artifactId
::method binaryPath; expose binaryPath; return binaryPath
::method sourceRoot; expose sourceRoot; return sourceRoot
::method buildCommand; expose buildCommand; return buildCommand
::method probeCommand; expose probeCommand; return probeCommand
::method policy; expose policy; return policy
::method metadata; expose metadata; return metadata
::method validate
  expose artifactId binaryPath probeCommand policy sourceRoot buildCommand
  if artifactId='' then return 'artifactId missing'
  if binaryPath='' then return 'binaryPath missing'
  if probeCommand='' then return 'probeCommand missing'
  if policy='reuse-if-loadable-else-rebuild' & (sourceRoot='' | buildCommand='') then return 'rebuild source/command missing'
  return ''

::class NativeArtifactDeploymentRequirement public
::method init
  expose declaration required
  use strict arg declaration, required=.true
::method declaration; expose declaration; return declaration
::method required; expose required; return required
::method id; expose declaration; return 'native-artifact:'||declaration~artifactId
::method kind; return 'native-artifact-loadability'
::method expected; return 'LOADABLE'
::method metadata; expose declaration; return declaration~metadata
::method explain
  expose declaration
  return 'native artifact '||declaration~artifactId||' must pass its target load/use probe; rebuild is policy-controlled'

::class NativeArtifactEvidence public
::method init
  expose artifactId packagedHash selectedHash probeBefore probeAfter rebuilt compiler libc
  use strict arg artifactId
  packagedHash=''; selectedHash=''; probeBefore=.false; probeAfter=.false; rebuilt=.false; compiler=''; libc=''
::attribute packagedHash
::attribute selectedHash
::attribute probeBefore
::attribute probeAfter
::attribute rebuilt
::attribute compiler
::attribute libc
::method artifactId; expose artifactId; return artifactId
::method satisfied; expose probeAfter; return probeAfter
