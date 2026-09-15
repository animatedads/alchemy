say 'AUDIO FFMPEG FOREIGN RUNTIME START'
bridgeDir = '../foreign'

.RuntimeImplementationSwitch~reset
.AudioLibraryBuild~referenceSwitch = .nil

target = .AudioFFmpegForeignTarget~new(bridgeDir)
provider = .RuntimeObjectImplementationProvider~new('native.ffmpeg.foreign', target)
broker = .RuntimeImplementationBroker~new
broker~register(.AudioRuntimeOperation~FFMPEG_DESCRIBE, .RuntimeImplementationReference~new(provider, 200, .true, 1, 1))
broker~register(.AudioRuntimeOperation~SAMPLE_FORMAT_DESCRIBE, .RuntimeImplementationReference~new(provider, 200, .true, 1, 1))
broker~register(.AudioRuntimeOperation~CONTAINER_OPEN_PROBE, .RuntimeImplementationReference~new(provider, 200, .true, 1, 1))
broker~register(.AudioRuntimeOperation~PCM_RESAMPLE, .RuntimeImplementationReference~new(provider, 200, .true, 1, 1))
broker~register(.AudioRuntimeOperation~PCM_TRANSFORM, .RuntimeImplementationReference~new(provider, 200, .true, 1, 1))
.RuntimeImplementationSwitch~installBroker(broker)
.AudioLibraryBuild~referenceSwitch = .RuntimeImplementationSwitch

empty = .Directory~new
a = .AudioRuntimeWorker~tryFFmpegDescribe(empty)
call assertTrue a~handled, 'FFmpeg runtime describe handled'
call assertTrue a~value['ffmpeg_version_info']~string <> '', 'FFmpeg version info'
call assertTrue a~value['avutil_version'] > 0, 'libavutil version'
call assertTrue a~value['avcodec_version'] > 0, 'libavcodec version'
call assertTrue a~value['swresample_version'] > 0, 'libswresample version'
call assertEq 'native.ffmpeg.foreign', a~evidence~providerId, 'Runtime Reference provider identity'
call assertTrue a~evidence~implementationId~pos('ffmpeg:') = 1, 'implementation identity contains FFmpeg version'

r = .Directory~new; r['name'] = 's16'
s16 = .AudioRuntimeWorker~trySampleFormatDescribe(r)
call assertTrue s16~handled, 's16 handled'
call assertEq 's16', s16~value['name'], 's16 canonical name'
call assertEq 2, s16~value['bytes_per_sample'], 's16 bytes per sample'
call assertTrue \s16~value['planar'], 's16 interleaved'

r2 = .Directory~new; r2['name'] = 'fltp'
fltp = .AudioRuntimeWorker~trySampleFormatDescribe(r2)
call assertTrue fltp~handled, 'fltp handled'
call assertEq 'fltp', fltp~value['name'], 'fltp canonical name'
call assertEq 4, fltp~value['bytes_per_sample'], 'fltp bytes per sample'
call assertTrue fltp~value['planar'], 'fltp planar'

bad = .Directory~new; bad['name'] = 'definitely-not-an-ffmpeg-sample-format'
unsupported = .AudioRuntimeWorker~trySampleFormatDescribe(bad)
call assertTrue \unsupported~handled, 'unknown sample format rejected'
call assertEq 'UNSUPPORTED', unsupported~code, 'unknown sample format code'

call assertEq 'Invalid argument', target~errorText(-22), 'av_strerror via managed ForeignBuffer'
call assertEq '0.22.5', .foreign~runtimeInfo~runtimeVersion, 'Foreign Runtime v0.22.5 active'
call assertEq 0, .foreign~runtimeInfo~maxArity, 'Foreign Runtime libffi dynamic arity active'
call assertTrue .foreign~runtimeInfo~nativeDispatcher~pos('libffi') > 0, 'Foreign Runtime libffi dispatcher active'

probeReq = .Directory~new
probeReq['path'] = '../tests/fixture.wav'
probe = .AudioRuntimeWorker~tryContainerOpenProbe(probeReq)
call assertTrue probe~handled, 'container open probe handled'
call assertEq 0, probe~value['open_rc'], 'avformat_open_input success'
call assertTrue probe~value['stream_info_rc'] >= 0, 'avformat_find_stream_info success'
call assertTrue probe~value['opened'], 'managed AVFormatContext constructed'
call assertEq 'libavformat', probe~value['provider'], 'container provider'
call assertTrue probe~value['avformat_version'] > 0, 'libavformat version'


/* Real PCM conversion through libswresample.  480 mono s16 samples at 48 kHz
 * represent 10 ms.  A complete flush should produce exactly 160 samples at
 * 16 kHz.  Constant non-zero samples make accidental all-zero/silence output
 * immediately visible while avoiding dependence on a codec or container. */
resampleReq = .Directory~new
resampleReq['pcm_bytes'] = copies('1111'x, 480)
resampleReq['sample_format'] = 's16'
resampleReq['channels'] = 1
resampleReq['input_sample_rate'] = 48000
resampleReq['output_sample_rate'] = 16000
resampled = .AudioRuntimeWorker~tryPCMResample(resampleReq)
call assertTrue resampled~handled, 'native PCM resample handled'
call assertEq 'libswresample', resampled~value['provider'], 'resample provider'
call assertEq 's16', resampled~value['sample_format'], 'resample format'
call assertEq 480, resampled~value['input_samples'], 'resample input samples'
call assertEq 160, resampled~value['output_samples'], 'resample output samples after filter drain'
call assertEq 320, resampled~value['pcm_bytes']~length, 'resample output byte length'
call assertTrue resampled~value['pcm_bytes'] <> copies('00'x, 320), 'resample preserves non-zero signal'
call assertEq '1111111111111111', resampled~value['pcm_bytes']~c2x~left(16), 'constant s16 signal survives rate conversion'

/* Real planar conversion: two independent float32 planes.  The left plane is
 * +0.25 and the right plane -0.25.  This exercises v0.14 typed pointer arrays
 * as actual uint8_t ** audio planes, not merely a synthetic pointer-array test. */
planarReq = .Directory~new
planarReq['pcm_planes'] = .Array~of(copies('0000803E'x, 480), copies('000080BE'x, 480))
planarReq['sample_format'] = 'fltp'
planarReq['channels'] = 2
planarReq['input_sample_rate'] = 48000
planarReq['output_sample_rate'] = 16000
planarResult = .AudioRuntimeWorker~tryPCMResample(planarReq)
call assertTrue planarResult~handled, 'native planar PCM resample handled'
call assertEq 'fltp', planarResult~value['sample_format'], 'planar resample format'
call assertEq 2, planarResult~value['channels'], 'planar channel count'
call assertEq 480, planarResult~value['input_samples'], 'planar input samples per channel'
call assertEq 160, planarResult~value['output_samples'], 'planar output samples per channel'
call assertTrue planarResult~value~hasIndex('pcm_planes'), 'planar result carries pcm_planes'
call assertEq 2, planarResult~value['pcm_planes']~items, 'planar result plane count'
call assertEq 640, planarResult~value['pcm_planes'][1]~length, 'left plane output byte length'
call assertEq 640, planarResult~value['pcm_planes'][2]~length, 'right plane output byte length'
call assertTrue planarResult~value['pcm_planes'][1] <> copies('00'x, 640), 'left planar signal remains non-zero'
call assertTrue planarResult~value['pcm_planes'][2] <> copies('00'x, 640), 'right planar signal remains non-zero'
call assertEq '0000803E0000803E', planarResult~value['pcm_planes'][1]~c2x~left(16), 'left float plane survives rate conversion'
call assertEq '000080BE000080BE', planarResult~value['pcm_planes'][2]~c2x~left(16), 'right float plane survives rate conversion'

/* General transform: packed s16 0.25 -> packed float32 at the same rate. */
transformReq = .Directory~new
transformReq['pcm_bytes'] = copies('0020'x, 480)
transformReq['input_sample_format'] = 's16'
transformReq['output_sample_format'] = 'flt'
transformReq['input_channels'] = 1
transformReq['output_channels'] = 1
transformReq['input_sample_rate'] = 48000
transformReq['output_sample_rate'] = 48000
transformed = .AudioRuntimeWorker~tryPCMTransform(transformReq)
call assertTrue transformed~handled, 'native PCM transform handled'
call assertEq 's16', transformed~value['input_sample_format'], 'transform input format'
call assertEq 'flt', transformed~value['output_sample_format'], 'transform output format'
call assertEq 480, transformed~value['input_samples'], 'transform input samples'
call assertEq 480, transformed~value['output_samples'], 'transform output samples'
call assertTrue \transformed~value['output_planar'], 'packed float output remains packed'
call assertEq 1920, transformed~value['pcm_bytes']~length, 'float output byte length'
call assertEq '0000803E0000803E', transformed~value['pcm_bytes']~c2x~left(16), 's16 quarter-scale converts to float quarter-scale'

/* Channel + representation conversion: packed mono s16 -> planar stereo fltp.
 * This exercises independent input/output formats, layouts and pointer counts. */
remixReq = .Directory~new
remixReq['pcm_bytes'] = copies('0020'x, 480)
remixReq['input_sample_format'] = 's16'
remixReq['output_sample_format'] = 'fltp'
remixReq['input_channels'] = 1
remixReq['output_channels'] = 2
remixReq['input_sample_rate'] = 48000
remixReq['output_sample_rate'] = 16000
remixed = .AudioRuntimeWorker~tryPCMTransform(remixReq)
call assertTrue remixed~handled, 'native PCM channel/format/rate transform handled'
call assertTrue remixed~value['output_planar'], 'stereo float output is planar'
call assertEq 2, remixed~value['pcm_planes']~items, 'remix output plane count'
call assertEq 160, remixed~value['output_samples'], 'remix output samples per channel'
call assertEq 640, remixed~value['pcm_planes'][1]~length, 'remix left plane bytes'
call assertEq 640, remixed~value['pcm_planes'][2]~length, 'remix right plane bytes'
call assertTrue remixed~value['pcm_planes'][1] <> copies('00'x,640), 'remix left plane non-zero'
call assertEq remixed~value['pcm_planes'][1], remixed~value['pcm_planes'][2], 'default mono-to-stereo remix produces equal planes'

target~close
.AudioLibraryBuild~referenceSwitch = .nil
.RuntimeImplementationSwitch~reset
say 'AUDIO FFMPEG FOREIGN RUNTIME: OK'
exit 0

::routine assertTrue
  use strict arg value, label
  if \value then raise syntax 88.900 array('FAILED ' || label)
  return
::routine assertEq
  use strict arg expected, actual, label
  if expected \= actual then raise syntax 88.900 array('FAILED ' || label || ' expected=' || expected || ' actual=' || actual)
  return

::requires '../AudioFFmpegForeignProvider.cls'
