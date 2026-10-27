#!/usr/bin/env rexx
/* Minimal service-side pattern. Existing SMTP/LDAP/IMAP/HTTPS/Fabric services
 * retain their own semantics and simply publish through a local emitter. */
identity=.InstrumentationCodec~identity('alchemy','smtp','smtp-ed209a','ed209a','','SMTP')
metrics=.InstrumentationEmitter~new(identity)
metrics~setHealth(.InstrumentationHealth~HEALTHY)
metrics~requestAccepted
metrics~bytesIn(2048)
metrics~bytesOut(512)
metrics~requestCompleted
snapshot=metrics~snapshot('2026-10-07T20:00:00Z')
say snapshot['identity']['service_id'] snapshot['health'] snapshot['samples']~items
::requires 'src/InstrumentationMesh.cls'
