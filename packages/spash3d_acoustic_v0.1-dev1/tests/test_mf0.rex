/* test_mf0.rex -- multiF0 against a synthetic mix with known voices.  Claude (Opus 5.5), 6 Nov 2026 */
parse arg f out
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
n=prov~multiF0(f,out,8000,1024,80,75,500,15,4,2.0,0.25)
say n 'frames'
::requires 'AudioV9SpatialNativeProvider.cls'
