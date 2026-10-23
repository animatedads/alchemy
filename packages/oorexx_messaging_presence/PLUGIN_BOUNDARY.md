# Registered extension/plugin boundary

Messaging & Presence is deliberately small. Optional XMPP ecosystem facilities must not enlarge the core service just because an XEP exists for them.

`src/MessagingPresenceExtensions.cls` provides the registration seam. An extension plugin declares a unique `pluginId`, a semantic service identity (`semanticServiceId`), the actual semantic service object, current availability/evidence, and optionally its own dynamic Intention discovery provider.

The extension service owns its own domain objects and operations. The core `Messaging` and `Presence` access classes remain unchanged. The plugin registry selects only among providers of that separate semantic service.

A plugin should therefore be named for what it does, not for the XMPP XEP it happens to use. For example a future group-conversation service is a group conversation service; XMPP MUC would merely be one possible provider behind it.

No MUC, PubSub, file-transfer, avatar or federation-policy operation is defined by this package.
