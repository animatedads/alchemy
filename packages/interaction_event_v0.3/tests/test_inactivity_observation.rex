lib = .InteractionCaptureLibrary~new
e = .InteractionEvent~new('idle1','ENGAGEMENT_ABSENCE',.nil,'WEB_UI','UI.INACTIVITY_WINDOW','OBSERVED')
e~addCorrelation('session-99')
e~addContent(.InteractionContentElement~new('m1','MOUSE_ACTIVITY','NONE','DERIVED_NONCUSTOMER','','RETAIN','TELEMETRY'))
e~addContent(.InteractionContentElement~new('m2','SCROLL_ACTIVITY','NONE','DERIVED_NONCUSTOMER','','RETAIN','TELEMETRY'))
e~addContent(.InteractionContentElement~new('m3','NAVIGATION_ACTIVITY','NONE','DERIVED_NONCUSTOMER','','RETAIN','TELEMETRY'))
e~addContent(.InteractionContentElement~new('m4','DATA_PULL_ACTIVITY','NONE','DERIVED_NONCUSTOMER','','RETAIN','TELEMETRY'))
e~addContent(.InteractionContentElement~new('m5','SESSION_KEEPALIVE','PRESENT','DERIVED_NONCUSTOMER','','RETAIN','TELEMETRY'))
e~addContent(.InteractionContentElement~new('m6','DURATION_SECONDS','1800','DERIVED_NONCUSTOMER','','RETAIN','TELEMETRY'))
e~seal
call assertTrue lib~captureEvent(e)~ok, 'inactivity observation captured'
a = .InteractionAssessmentFactory~engagement('ea1','idle1','POSSIBLE_DISENGAGEMENT','engagement-llm','eng-v1',67)
a~addDimension('INFERENCE_STRENGTH',67)
a~seal
call assertTrue lib~attachAssessment(a)~ok, 'assessment attached'
call assertEqual 'POSSIBLE_DISENGAGEMENT', lib~assessmentsFor('idle1')[1]~value, 'observation not converted into certainty'
say 'PASS test_inactivity_observation'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'InteractionEvent.cls'
