#!/usr/bin/env rexx
say 'SMTP -> INSTRUMENTATION ADAPTER TEST START'

identity=.InstrumentationCodec~identity('alchemy','smtp','smtp-a','ed209a','','SMTP')
sink=.SmtpInstrumentationEventSink~new(identity)
sink~ready
service=.SmtpService~new(.nil,.nil,.nil,.nil,.nil,.nil,.TestDelivery~new,sink)

session=.SmtpSession~new('session-1','192.0.2.10','person@example.invalid',.true,.true)
envelope=.SmtpEnvelope~new('sender@example.invalid')
envelope~addRecipient('local@example.invalid')
message=.SmtpMessage~new(envelope,'hello')
acceptance=service~acceptInbound(session,message)
call assertTrue acceptance~ok,'real SMTP semantic ingress accepted'

snap=sink~snapshot('2026-10-09T20:10:00Z')
call assertEq metric(snap,'smtp.ingress.accepted.total'),1,'accepted message counter'
call assertEq metric(snap,'smtp.ingress.bytes.total'),5,'ingress byte counter'
call assertEq metric(snap,.InstrumentationVocabulary~BYTES_IN_TOTAL),5,'common inbound byte counter'
call assertEq metric(snap,'smtp.recipients.total'),1,'recipient accounting counter'
call assertEq metric(snap,'smtp.events.tls.total'),1,'TLS event counter'
call assertEq metric(snap,'smtp.events.authenticated.total'),1,'authenticated event counter'
call assertNoSensitiveDimensions snap,'SMTP operational samples do not leak message/user addressing'

/* Exercise a service-owned denial through the same smtp.event/0.1 seam. */
config=.SmtpPolicyConfig~new
config~maxMessageBytes=2
service2=.SmtpService~new(config,.nil,.nil,.nil,.nil,.nil,.TestDelivery~new,sink)
message2=.SmtpMessage~new(envelope,'hello')
denied=service2~acceptInbound(session,message2)
call assertTrue \denied~ok,'oversize ingress denied'
snap2=sink~snapshot('2026-10-09T20:10:01Z')
call assertEq metric(snap2,'smtp.ingress.denied.total'),1,'denied message counter'

say 'PASS SMTP dev9 semantic event projection into Instrumentation Mesh'
exit 0

metric: procedure
  use arg snapshot,name
  do sample over snapshot['samples']
    if sample['name']=name then return sample['value']
  end
  return 'NOT_FOUND'

assertNoSensitiveDimensions: procedure
  use arg snapshot
  do sample over snapshot['samples']
    dims=sample['dimensions']
    do key over .array~of('remoteAddress','principalId','mailFrom','signerIdentity','certificateId')
      if dims[key]<>.nil then do
        say 'FAIL sensitive SMTP dimension leaked:' key
        exit 1
      end
    end
  end
  return

assertTrue: procedure
  use arg truth,label
  if truth then return
  say 'FAIL' label
  exit 1

assertEq: procedure
  use arg actual,expected,label
  if actual=expected then return
  say 'FAIL' label 'expected='expected 'actual='actual
  exit 1

::class TestDelivery subclass SmtpDeliveryProvider public
::method classifyRecipients
  use strict arg message
  d=.directory~new; d['local']=message~envelope~recipients; d['relay']=.array~new; return d
::method deliverLocal
  use strict arg session,message,recipients,mailbox='INBOX'
  return .SmtpResult~success(mailbox,'DELIVERED')

::requires 'src/InstrumentationMesh.cls'
::requires 'src/InstrumentationServiceAdapters.cls'
::requires 'SmtpCore.cls'
