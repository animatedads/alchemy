/* Hosted-module deployment contract. MCP, Wire and future server modules use
 * the same lifecycle.  Module semantics remain in application adapters.
 */
::options numeric inherit

::class HostedModuleDeclaration public
::method init
  expose moduleId hostKind hostVersion packageRequire adapterClass bindMethod probePath probeMethod activationMode metadata
  use strict arg moduleId,hostKind='oorexx-https',hostVersion='',packageRequire='',adapterClass='',bindMethod='bind',probePath='',probeMethod='GET',activationMode='compose-before-start',metadata=.nil
  if metadata==.nil then metadata=.directory~new
::method moduleId; expose moduleId; return moduleId
::method hostKind; expose hostKind; return hostKind
::method hostVersion; expose hostVersion; return hostVersion
::method packageRequire; expose packageRequire; return packageRequire
::method adapterClass; expose adapterClass; return adapterClass
::method bindMethod; expose bindMethod; return bindMethod
::method probePath; expose probePath; return probePath
::method probeMethod; expose probeMethod; return probeMethod
::method activationMode; expose activationMode; return activationMode
::method metadata; expose metadata; return metadata
::method validate
  expose moduleId hostKind packageRequire adapterClass bindMethod activationMode
  if moduleId='' then return 'moduleId missing'
  if hostKind='' then return 'hostKind missing'
  if packageRequire='' then return 'packageRequire missing'
  if adapterClass='' then return 'adapterClass missing'
  if bindMethod='' then return 'bindMethod missing'
  if activationMode='' then return 'activationMode missing'
  return ''

::class HostedModuleDeploymentRequirement public
::method init
  expose declaration required
  use strict arg declaration, required=.true
::method declaration; expose declaration; return declaration
::method required; expose required; return required
::method id; expose declaration; return 'hosted-module:'||declaration~moduleId
::method kind; expose declaration; return 'hosted-module:'||declaration~hostKind
::method expected; return 'PROBED_ACTIVE'
::method metadata; expose declaration; return declaration~metadata
::method explain
  expose declaration
  return 'hosted module '||declaration~moduleId||' must be staged, package-loadable, composed, activated and live-probed on '||declaration~hostKind

::class HostedModuleEvidence public
::method init
  expose moduleId staged packageLoadable composed activated probed hostVersion hostGeneration probePath probeStatus requestId
  use strict arg moduleId
  staged=.false; packageLoadable=.false; composed=.false; activated=.false; probed=.false
  hostVersion=''; hostGeneration=''; probePath=''; probeStatus=''; requestId=''
::attribute staged
::attribute packageLoadable
::attribute composed
::attribute activated
::attribute probed
::attribute hostVersion
::attribute hostGeneration
::attribute probePath
::attribute probeStatus
::attribute requestId
::method moduleId; expose moduleId; return moduleId
::method state
  expose staged packageLoadable composed activated probed
  if \staged then return 'ABSENT'
  if \packageLoadable then return 'STAGED'
  if \composed then return 'LOADABLE'
  if \activated then return 'COMPOSED'
  if \probed then return 'ACTIVE_UNPROBED'
  return 'PROBED_ACTIVE'
::method satisfied
  expose staged packageLoadable composed activated probed
  return staged & packageLoadable & composed & activated & probed
