#!/usr/bin/env rexx
sipIdentity=.InstrumentationCodec~identity('alchemy','sip','sip-test','node-test','','SIP')
rtpIdentity=.InstrumentationCodec~identity('alchemy','rtp','rtp-test','node-test','','RTP')
sipMetrics=.SipInstrumentationSink~new(sipIdentity)
rtpMetrics=.RtpInstrumentationSink~new(rtpIdentity)
fanout=.SipEventFanoutSink~new
fanout~add(.BrokenObserver~new)~add(sipMetrics)~add(rtpMetrics)
call emit fanout,'SIP.SERVER.STARTED'
call emit fanout,'SIP.WIRE.RX',.array~of('bytes',400)
call emit fanout,'SIP.AUTH.CHALLENGE'
call emit fanout,'SIP.AUTH.ACCEPTED'
call emit fanout,'SIP.REGISTRATION.BOUND'
call emit fanout,'SIP.CALL.CREATED'
call emit fanout,'RTP.ENDPOINT.OPENED'
call emit fanout,'RTP.RECEIVER.STARTED'
call emit fanout,'RTP.RECEIVER.FRAME',.array~of('samples',160)
call emit fanout,'RTP.SENDER.STARTED'
call emit fanout,'RTP.SENDER.FRAME',.array~of('samples',160,'bytes',172)
sipSnap=sipMetrics~snapshot('2026-10-08T10:00:00Z')
rtpSnap=rtpMetrics~snapshot('2026-10-08T10:00:00Z')
call assertMetric sipSnap,.InstrumentationVocabulary~BYTES_IN_TOTAL,400
call assertMetric sipSnap,.SipInstrumentationVocabulary~SIP_REGISTRATIONS_ACTIVE,1
call assertMetric sipSnap,.SipInstrumentationVocabulary~SIP_CALLS_ACTIVE,1
call assertMetric rtpSnap,.RtpInstrumentationVocabulary~RTP_ENDPOINTS_OPEN,1
call assertMetric rtpSnap,.RtpInstrumentationVocabulary~RTP_RX_FRAMES_TOTAL,1
call assertMetric rtpSnap,.RtpInstrumentationVocabulary~RTP_TX_FRAMES_TOTAL,1
sipEvents=sipMetrics~events; rtpEvents=rtpMetrics~events
if sipEvents~items<5 then do; say 'FAIL SIP event timeline' sipEvents~items; exit 6; end
if rtpEvents~items<3 then do; say 'FAIL RTP event timeline' rtpEvents~items; exit 7; end
if sipEvents[1]['authority']<>'SIP_SERVICE' then do; say 'FAIL SIP event authority'; exit 8; end
if rtpEvents[1]['authority']<>'RTP_SERVICE' then do; say 'FAIL RTP event authority'; exit 9; end
say 'EVENTS' sipEvents~items rtpEvents~items
if fanout~error(1)==.nil then do; say 'FAIL broken observer was not isolated'; exit 5; end
say 'PASS SIP + independent shared RTP instrumentation adapters + observer isolation'
exit 0
emit: procedure
  use arg sink,eventType,pairs=.nil
  e=.directory~new; e['eventType']=eventType
  if pairs<>.nil then do i=1 to pairs~items by 2; e[pairs[i]]=pairs[i+1]; end
  sink~recordEvent(e); return
assertMetric: procedure
  use arg snap,name,expected
  do sample over snap['samples']
    if sample['name']=name then do
      if sample['value']<>expected then do; say 'FAIL' name sample['value'] expected; exit 3; end
      return
    end
  end
  say 'FAIL missing metric' name; exit 4
::requires 'sip_instrumentation.cls'
::requires 'rtp_instrumentation.cls'

::class BrokenObserver
::method recordEvent
  use strict arg event
  raise syntax 88.900 array('intentional observer failure')