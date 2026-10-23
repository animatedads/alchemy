#!/usr/bin/env rexx
identity=.InstrumentationCodec~identity('alchemy','rtp','rtp-test','node-test','','RTP')
metrics=.RtpInstrumentationSink~new(identity)
call emit metrics,'RTP.ENDPOINT.OPENED'
call emit metrics,'RTP.RECEIVER.STARTED'
call emit metrics,'RTP.RECEIVER.FRAME',.array~of('samples',160)
call emit metrics,'RTP.SENDER.STARTED'
call emit metrics,'RTP.SENDER.FRAME',.array~of('samples',160,'bytes',172)
snap=metrics~snapshot('2026-10-08T10:00:00Z')
call assertMetric snap,.RtpInstrumentationVocabulary~RTP_ENDPOINTS_OPEN,1
call assertMetric snap,.RtpInstrumentationVocabulary~RTP_RX_FRAMES_TOTAL,1
call assertMetric snap,.RtpInstrumentationVocabulary~RTP_TX_FRAMES_TOTAL,1
call assertMetric snap,.RtpInstrumentationVocabulary~RTP_RX_SAMPLES_TOTAL,160
call assertMetric snap,.RtpInstrumentationVocabulary~RTP_TX_SAMPLES_TOTAL,160
call assertMetric snap,.RtpInstrumentationVocabulary~RTP_TX_BYTES_TOTAL,172
events=metrics~events
if events~items<3 then do; say 'FAIL RTP instrumentation event timeline' events~items; exit 6; end
if events[1]['schema']<>.InstrumentationContract~EVENT_SCHEMA then do; say 'FAIL RTP event schema'; exit 7; end
say 'EVENTS' events~items events[1]['kind']
say 'PASS RTP instrumentation.mesh/0.1 dev7 adapter + event timeline'
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
::requires 'rtp_instrumentation.cls'