/* Skeleton showing four simultaneous channels. Replace test providers with
 * Macrospace adapters wrapping one resident Python provider object per channel.
 */
call directory '../src'
tracker = .SpeechTestConcurrencyTracker~new
channels = .Array~new
channels~append(.SpeechTTSChannel~new('call-a-tts', .SpeechTestTTSProvider~new('local', tracker, .2), .nil))
channels~append(.SpeechTTSChannel~new('call-b-tts', .SpeechTestTTSProvider~new('cloud', tracker, .2), .nil))
channels~append(.SpeechSTTChannel~new('call-a-stt', .SpeechTestSTTProvider~new('local', tracker, .2)))
channels~append(.SpeechSTTChannel~new('call-b-stt', .SpeechTestSTTProvider~new('cloud', tracker, .2)))
say 'Configured' channels~items 'independent speech channels.'
exit 0
::requires 'SpeechChannels.cls'
::requires 'SpeechProviders.cls'
