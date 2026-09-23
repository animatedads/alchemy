/* Wire3DApplication.cls -- renderer-neutral application projection into 3D space.
   A 3D-space application does not fork application truth or behaviour.  It binds
   spatial affordances back to the same semantic actions and ooRexx behaviour. */

::class Wire3DApplicationEvent public
::attribute app get
::attribute action get
::attribute subject get
::attribute source get
::attribute payload get
::attribute ui get
::method init
  expose app action subject source payload ui
  use strict arg app, action, subject=.nil, source=.nil, payload=.nil, ui=.nil
  if payload == .nil then payload=.directory~new

::class Wire3DApplicationBinding public
::attribute action get
::attribute receiver get
::attribute methodName get
::attribute capability get
::method init
  expose action receiver methodName capability
  use strict arg action, receiver, methodName, capability='USE'
  if action='' then raise syntax 93.900 array ('3D application binding requires a semantic action')
  if receiver==.nil then raise syntax 93.900 array ('3D application binding requires a receiver')
  methodName=methodName~upper
::method fire
  expose receiver methodName
  use strict arg event
  return receiver~send(methodName,event)
::method asDirectory
  expose action methodName capability
  d=.directory~new; d['action']=action; d['method']=methodName; d['capability']=capability; return d

/* A spatial application is a mount/projection boundary around an existing
   application.  It owns neither the application's domain objects nor its truth. */
::class Wire3DApplicationEntryPoint public
::attribute name get
::attribute targetName get
::attribute action get
::method init
  expose name targetName action
  use strict arg name, targetName='', action=''
  if name='' then raise syntax 93.900 array ('3D application entry point requires a name')
::method asDirectory
  expose name targetName action
  d=.directory~new; d['name']=name; d['target']=targetName; d['action']=action; return d

::class Wire3DInteractionMapping public
::attribute interaction get
::attribute action get
::method init
  expose interaction action
  use strict arg interaction, action
  if interaction='' | action='' then raise syntax 93.900 array ('3D interaction mapping requires interaction and semantic action')
::method asDirectory
  expose interaction action
  d=.directory~new; d['interaction']=interaction; d['action']=action; return d

::class Wire3DSpaceApp subclass Wire3DSpatialContainer public
::attribute appId get
::attribute applicationRef get
::attribute definitionVersion get
::method init
  expose appId applicationRef definitionVersion bindings exposed entryPoints interactions mounts
  use strict arg appId, applicationRef='', definitionVersion='0.1'
  if appId='' then raise syntax 93.900 array ('3D space application requires an id')
  self~init:super('app-'appId, applicationRef, .Wire3DRepresentation~new('application',appId,'application'))
  bindings=.directory~new
  exposed=.directory~new
  entryPoints=.directory~new
  interactions=.directory~new
  mounts=.directory~new
  self~describe('projectionKind','3D_SPACE_APP')
  self~describe('semanticEquivalence','SAME_APPLICATION')
  self~describe('rendererOwnsPresentation','TRUE')

/* Expose is capability metadata, not authority escalation.  The caller supplies
   the already-authorised object/capability it is willing to project. */
::method expose
  expose exposed
  use strict arg name, object, capability='OBSERVE'
  if name='' then raise syntax 93.900 array ('Exposed application object requires a stable name')
  entry=.directory~new; entry['object']=object; entry['capability']=capability~upper
  exposed[name]=entry
  return object
::method exposedObject
  expose exposed
  use strict arg name
  if exposed~hasIndex(name)==.false then return .nil
  return exposed[name]['object']
::method exposedCapability
  expose exposed
  use strict arg name
  if exposed~hasIndex(name)==.false then return ''
  return exposed[name]['capability']

/* Bind a spatial interaction to the application's existing semantic action and
   ordinary ooRexx behaviour.  There is deliberately no vrFoo/threeDFoo method. */
::method bind
  expose bindings
  use strict arg action, receiver, methodName, capability='USE'
  key=action~upper
  bindings[key]=.Wire3DApplicationBinding~new(action,receiver,methodName,capability)
  return bindings[key]
::method hasBinding
  expose bindings
  use strict arg action
  return bindings~hasIndex(action~upper)
::method activate
  expose bindings
  use strict arg action, subject=.nil, source=.nil, payload=.nil, ui=.nil
  key=action~upper
  if bindings~hasIndex(key)==.false then raise syntax 93.900 array ('No semantic application binding for 'action)
  event=.Wire3DApplicationEvent~new(self,action,subject,source,payload,ui)
  return bindings[key]~fire(event)

/* Renderer/native gestures map to semantic application actions.  Mapping is
   presentation vocabulary only; the resulting action is the same application action. */
::method mapInteraction
  expose interactions
  use strict arg interaction, action
  interactions[interaction~upper]=.Wire3DInteractionMapping~new(interaction,action)
  return interactions[interaction~upper]
::method activateInteraction
  expose interactions
  use strict arg interaction, subject=.nil, source=.nil, payload=.nil, ui=.nil
  key=interaction~upper
  if interactions~hasIndex(key)==.false then raise syntax 93.900 array ('No 3D interaction mapping for 'interaction)
  return self~activate(interactions[key]~action,subject,source,payload,ui)

/* Entry points name meaningful places/actions in an application without
   prescribing camera motion, windows, rooms, portals, or any renderer mechanic. */
::method entryPoint
  expose entryPoints
  use strict arg name, targetName='', action=''
  entryPoints[name~upper]=.Wire3DApplicationEntryPoint~new(name,targetName,action)
  return entryPoints[name~upper]
::method findEntryPoint
  expose entryPoints
  use strict arg name
  if entryPoints~hasIndex(name~upper)==.false then return .nil
  return entryPoints[name~upper]

/* Mounting composes applications as semantic spatial containers.  It does not
   launch a browser/window/process and grants no authority beyond the child app. */
::method mount
  expose mounts
  use strict arg childApp
  if childApp~isA(.Wire3DSpaceApp)==.false then raise syntax 93.900 array ('3D application mount requires a Wire3DSpaceApp')
  if childApp == self then raise syntax 93.900 array ('3D application cannot mount itself')
  key=childApp~appId~upper
  if mounts~hasIndex(key) then raise syntax 93.900 array ('3D application already mounted: 'childApp~appId)
  mounts[key]=childApp
  self~add(childApp)
  return childApp
::method mountedApp
  expose mounts
  use strict arg appId
  if mounts~hasIndex(appId~upper)==.false then return .nil
  return mounts[appId~upper]

/* Project is presentation metadata around an already-exposed semantic object.
   The representation may differ radically between renderers without changing
   the semantic identity, action or behaviour binding. */
::method project
  use strict arg name, spatialId, representation=.nil
  target=self~exposedObject(name)
  if target==.nil then raise syntax 93.900 array ('Cannot project unexposed application object 'name)
  semanticRef=self~applicationRef'#'name
  p=.Wire3DObjectProjection~new(spatialId,target,semanticRef,representation)
  p~describe('applicationId',self~appId)
  p~describe('applicationObject',name)
  p~describe('capability',self~exposedCapability(name))
  self~add(p)
  return p
::method asDirectory
  expose appId applicationRef definitionVersion bindings exposed entryPoints interactions mounts
  d=self~asDirectory:super
  d['appId']=appId; d['applicationRef']=applicationRef; d['definitionVersion']=definitionVersion
  ba=.array~new; do key over bindings; ba~append(bindings[key]~asDirectory); end; d['bindings']=ba
  xa=.array~new
  do name over exposed
    x=.directory~new; x['name']=name; x['capability']=exposed[name]['capability']; xa~append(x)
  end
  d['exposed']=xa
  ea=.array~new; do key over entryPoints; ea~append(entryPoints[key]~asDirectory); end; d['entryPoints']=ea
  ia=.array~new; do key over interactions; ia~append(interactions[key]~asDirectory); end; d['interactions']=ia
  ma=.array~new; do key over mounts; m=.directory~new; m['appId']=mounts[key]~appId; m['spatialId']=mounts[key]~spatialId; ma~append(m); end; d['mounts']=ma
  return d
::requires 'Wire3DCore.cls'
