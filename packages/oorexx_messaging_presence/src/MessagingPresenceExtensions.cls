/* MessagingPresenceExtensions.cls
 * Registration boundary for optional messaging-related semantic services.
 *
 * This is deliberately NOT an XMPP extension catalogue.  Plugins register a
 * semantic service of their own.  They do not add methods or capabilities to
 * Messaging or Presence simply because an XMPP XEP exists.
 */

::class MessagingPresenceExtensionBuild public
::constant VERSION "0.1-dev3"
::constant API "messaging.presence.extension.registry/0.1"

::class MessagingPresenceExtensionPlugin public
::method pluginId abstract
::method semanticServiceId abstract
::method service abstract
::method available
  use strict arg context=.nil
  return .true
::method evidence
  use strict arg context=.nil
  return "registered semantic extension"
::method intentionDiscoveryProvider
  return .nil

::class MessagingPresenceExtensionRegistration public
::method init
  expose plugin semanticServiceId priority scope
  use strict arg plugin, priority=100, scope=""
  if plugin=.nil then raise syntax 88.900 array("extension registration requires plugin")
  plugin=plugin
  semanticServiceId=translate(strip(plugin~semanticServiceId))
  if semanticServiceId="" then raise syntax 88.900 array("extension semantic service id must not be empty")
  priority=priority+0
  scope=strip(scope)
::attribute plugin get
::attribute semanticServiceId get
::attribute priority get
::attribute scope get
::method pluginId
  expose plugin
  return plugin~pluginId
::method available
  expose plugin
  use strict arg context=.nil
  return plugin~available(context)
::method service
  expose plugin
  return plugin~service
::method evidence
  expose plugin
  use strict arg context=.nil
  return plugin~evidence(context)

::class MessagingPresenceExtensionRegistry public
::method init
  expose registrations order revision
  registrations=.directory~new
  order=.array~new
  revision=0
::attribute revision get
::method register
  expose registrations order revision
  use strict arg plugin, priority=100, scope=""
  id=translate(strip(plugin~pluginId))
  if id="" then raise syntax 88.900 array("extension pluginId must not be empty")
  registration=.MessagingPresenceExtensionRegistration~new(plugin,priority,scope)
  if \registrations~hasIndex(id) then order~append(id)
  registrations[id]=registration
  revision+=1
  return registration
::method unregister
  expose registrations revision
  use strict arg pluginId
  id=translate(strip(pluginId))
  if \registrations~hasIndex(id) then return .false
  registrations~remove(id)
  revision+=1
  return .true
::method plugin
  expose registrations
  use strict arg pluginId
  id=translate(strip(pluginId))
  if \registrations~hasIndex(id) then return .nil
  return registrations[id]~plugin
::method discover
  expose registrations order
  use strict arg semanticServiceId="", context=.nil
  wanted=translate(strip(semanticServiceId))
  out=.array~new
  do id over order
    if \registrations~hasIndex(id) then iterate
    registration=registrations[id]
    if wanted<>"" & registration~semanticServiceId<>wanted then iterate
    if registration~available(context) then out~append(registration)
  end
  return out
::method select
  use strict arg semanticServiceId, context=.nil
  best=.nil
  do registration over self~discover(semanticServiceId,context)
    if best=.nil then best=registration
    else if registration~priority<best~priority then best=registration
    else if registration~priority=best~priority then do
      if registration~pluginId<best~pluginId then best=registration
    end
  end
  return best
::method installIntentionDiscovery
  use strict arg intentionService
  installed=0
  do registration over self~discover("",intentionService)
    provider=registration~plugin~intentionDiscoveryProvider
    if provider=.nil then iterate
    intentionService~registerDiscoveryProvider(provider)
    installed+=1
  end
  return installed

::requires "MessagingPresence.cls"
