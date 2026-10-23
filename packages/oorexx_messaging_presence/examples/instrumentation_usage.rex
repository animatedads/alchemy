#!/usr/bin/env rexx
identity=.InstrumentationCodec~identity("estate-a","messaging-presence","mp-1","node-a","","MESSAGING_PRESENCE")
telemetry=.MessagingPresenceInstrumentation~new(identity)
telemetry~setHealth(.InstrumentationHealth~HEALTHY)
meshRegistry=.InstrumentationRegistry~new
meshRegistry~register("messaging-presence",telemetry)
meshService=.InstrumentationService~new(meshRegistry)
snapshot=meshService~sampleAll("2026-10-08T09:00:00Z")[1]
say snapshot["semantic_ref"] snapshot["health"] snapshot["samples"]~items
::requires "MessagingPresence.cls"
::requires "XmppMessagingPresenceProvider.cls"
::requires "MessagingPresenceInstrumentation.cls"
::requires "InstrumentationMesh.cls"
