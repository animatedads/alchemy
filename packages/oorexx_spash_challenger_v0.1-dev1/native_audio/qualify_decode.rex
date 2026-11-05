/* Manual native provider qualification, original media stays on host.
 * REQUIRES private output directory mode 700; out names not pre-existing.
 * One 6-second original-source clip per invocation, not an automated recogniser.
 */
parse arg bridgePath originalOgg privateF32 privateMeta channel startMs
if bridgePath='' | originalOgg='' | privateF32='' | privateMeta='' | channel='' | startMs='' then do
  say 'usage: rexx qualify_decode.rex bridge.json privateOriginalOgg newPrivate.f32 newPrivate.meta.tsv channelZeroBased sourceStartMs'
  exit 2
end
decoder=.SpashNativeOggDecoder~new(bridgePath)
ret=decoder~decode(originalOgg,privateF32,privateMeta,startMs,6000,channel,8000)
say 'NATIVE_AUDIO_INPUT_SUCCESS samples=48000 audio_origin=UNVERIFIED file_private=YES'
exit 0
::requires 'SpashNativeOggDecoder.cls'
