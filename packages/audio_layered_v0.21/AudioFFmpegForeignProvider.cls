/* AudioFFmpegForeignProvider.cls - native FFmpeg provider via Foreign Runtime v0.22.2; packed and planar PCM */

::class AudioFFmpegForeignTarget public
::attribute providerId get

::method init
  expose providerId avutil avcodec swresample avformat libc decodeFormat decodeCodec decodeUtil bridgeDir
  use strict arg bridgeDir
  providerId = 'native.ffmpeg.foreign'
  avutil = .foreign~load(bridgeDir || '/ffmpeg-avutil.bridge.json')
  avcodec = .foreign~load(bridgeDir || '/ffmpeg-avcodec.bridge.json')
  swresample = .foreign~load(bridgeDir || '/ffmpeg-swresample.bridge.json')
  avformat = .foreign~load(bridgeDir || '/ffmpeg-avformat.bridge.json')
  libc = .foreign~load(bridgeDir || '/libc-memory.bridge.json')
  decodeFormat = .foreign~load(bridgeDir || '/ffmpeg-audio-decode-avformat.bridge.json')
  decodeCodec = .foreign~load(bridgeDir || '/ffmpeg-audio-decode-avcodec.bridge.json')
  decodeUtil = .foreign~load(bridgeDir || '/ffmpeg-audio-decode-avutil.bridge.json')

::method runtimeImplementationInvoke
  expose providerId avutil avcodec swresample avformat libc
  use strict arg operationId, request, contract
  signal on syntax name providerFault
  if \request~isa(.Directory) then return .RuntimeProviderResult~failure('MALFORMED_REQUEST', 'request must be a Directory', providerId)

  select
    when operationId = .AudioRuntimeOperation~FFMPEG_DESCRIBE then do
      result = self~describeRuntime
      return .RuntimeProviderResult~success(result, providerId, self~implementationId)
    end
    when operationId = .AudioRuntimeOperation~SAMPLE_FORMAT_DESCRIBE then do
      if \request~hasIndex('name') then return .RuntimeProviderResult~failure('MALFORMED_REQUEST', 'sample format request requires name', providerId)
      name = request['name']~string~lower~strip
      if name = '' then return .RuntimeProviderResult~failure('MALFORMED_REQUEST', 'sample format name must not be empty', providerId)
      result = self~describeSampleFormat(name)
      if result == .nil then return .RuntimeProviderResult~failure('UNSUPPORTED', 'FFmpeg does not recognise sample format ' || name, providerId, self~implementationId)
      return .RuntimeProviderResult~success(result, providerId, self~implementationId)
    end
    when operationId = .AudioRuntimeOperation~CONTAINER_OPEN_PROBE then do
      if \request~hasIndex('path') then return .RuntimeProviderResult~failure('MALFORMED_REQUEST', 'container probe requires path', providerId)
      path = request['path']~string~strip
      if path = '' then return .RuntimeProviderResult~failure('MALFORMED_REQUEST', 'container path must not be empty', providerId)
      result = self~probeContainer(path)
      return .RuntimeProviderResult~success(result, providerId, self~implementationId)
    end
    when operationId = .AudioRuntimeOperation~PCM_RESAMPLE then do
      result = self~resamplePCM(request)
      if result~hasIndex('_error_code') then return .RuntimeProviderResult~failure(result['_error_code'], result['_error_detail'], providerId, self~implementationId)
      return .RuntimeProviderResult~success(result, providerId, self~implementationId)
    end
    when operationId = .AudioRuntimeOperation~PCM_TRANSFORM then do
      result = self~transformPCM(request)
      if result~hasIndex('_error_code') then return .RuntimeProviderResult~failure(result['_error_code'], result['_error_detail'], providerId, self~implementationId)
      return .RuntimeProviderResult~success(result, providerId, self~implementationId)
    end
    when operationId = .AudioRuntimeOperation~MEDIA_AUDIO_DECODE then do
      result = self~decodeAudio(request)
      if result~hasIndex('_error_code') then return .RuntimeProviderResult~failure(result['_error_code'], result['_error_detail'], providerId, self~implementationId)
      return .RuntimeProviderResult~success(result, providerId, self~implementationId)
    end
    otherwise return .RuntimeProviderResult~failure('UNSUPPORTED', 'operation not implemented by native FFmpeg provider', providerId, self~implementationId)
  end

providerFault:
  c = condition('O')
  detail = 'Foreign Runtime / FFmpeg invocation failed'
  if c \== .nil then if c~hasIndex('DESCRIPTION') then detail = c['DESCRIPTION']
  return .RuntimeProviderResult~failure('REMOTE_FAULT', detail, providerId)

::method describeRuntime
  expose avutil avcodec swresample
  d = .Directory~new
  d['provider'] = 'foreign-runtime/native'
  d['foreign_runtime_version'] = .foreign~runtimeInfo~runtimeVersion
  d['ffmpeg_version_info'] = avutil~version_info
  d['avutil_version'] = avutil~version
  d['avcodec_version'] = avcodec~version
  d['swresample_version'] = swresample~version
  d['avutil_path'] = avutil~providerPath
  d['avcodec_path'] = avcodec~providerPath
  d['swresample_path'] = swresample~providerPath
  d['avutil_license'] = avutil~license
  d['avcodec_license'] = avcodec~license
  d['swresample_license'] = swresample~license
  return d

::method describeSampleFormat
  expose avutil
  use strict arg name
  fmt = avutil~sample_format_from_name(name)
  if fmt < 0 then return .nil
  d = .Directory~new
  d['requested_name'] = name
  d['name'] = avutil~sample_format_name(fmt)
  d['format_id'] = fmt
  d['bytes_per_sample'] = avutil~sample_format_bytes(fmt)
  d['planar'] = (avutil~sample_format_planar(fmt) \= 0)
  d['provider'] = 'libavutil'
  d['avutil_version'] = avutil~version
  return d


::method probeContainer
  expose avformat
  use strict arg path
  d = .Directory~new
  d['path'] = path
  d['provider'] = 'libavformat'
  d['avformat_version'] = avformat~version
  d['open_rc'] = -1
  d['stream_info_rc'] = -1
  d['opened'] = .false
  r = avformat~open_input(.foreign~out, path, .nil, .nil)
  d['open_rc'] = r~returnValue
  if r~returnValue <> 0 then return d
  ctx = r~out('context')
  d['opened'] = .true
  signal on syntax name probeFault
  d['stream_info_rc'] = avformat~find_stream_info(ctx, .nil)
  ctx~close
  return d
probeFault:
  if symbol('ctx') = 'VAR' then if ctx \== .nil then if \ctx~closed then ctx~close
  raise syntax 88.900 array('FFmpeg container probe failed')


::method decodeAudio
  expose avutil decodeFormat decodeCodec decodeUtil
  use strict arg request
  do key over .Array~of('path','channels','sample_rate')
    if \request~hasIndex(key) then return self~resampleFailure('MALFORMED_REQUEST','audio decode requires ' || key)
  end
  path=request['path']~string~strip
  channels=request['channels']; sampleRate=request['sample_rate']
  if path='' then return self~resampleFailure('MALFORMED_REQUEST','audio decode path must not be empty')
  if \datatype(channels,'W') | channels < 1 then return self~resampleFailure('MALFORMED_REQUEST','channels must be a positive integer')
  if channels \= 1 then return self~resampleFailure('UNSUPPORTED','v0.15 direct decoder currently qualifies mono capture material only')
  if \datatype(sampleRate,'W') | sampleRate < 1 then return self~resampleFailure('MALFORMED_REQUEST','sample_rate must be a positive integer')
  maximumFrames=0
  if request~hasIndex('maximum_frames') then maximumFrames=request['maximum_frames']
  if \datatype(maximumFrames,'W') | maximumFrames < 0 then return self~resampleFailure('MALFORMED_REQUEST','maximum_frames must be a non-negative integer')

  ctx=.nil; decoder=.nil; formatView=.nil; streamView=.nil; codecParameters=.nil; codecContext=.nil
  packet=.nil; packetView=.nil; frame=.nil; frameView=.nil
  signal on syntax name decodeFault
  openResult=decodeFormat~open_input(.foreign~out,path,.nil,.nil)
  if openResult~returnValue \= 0 then return self~resampleFailure('DECODE_OPEN_FAILED', self~errorText(openResult~returnValue))
  ctx=openResult~out('context')
  infoRc=decodeFormat~find_stream_info(ctx,.nil)
  if infoRc < 0 then do
    detail=self~errorText(infoRc); ignoredCleanup=self~decodeCleanup(ctx,decoder,formatView,streamView,codecParameters,codecContext,packet,packetView,frame,frameView)
    return self~resampleFailure('DECODE_STREAM_INFO_FAILED',detail)
  end
  best=decodeFormat~find_best_stream_decoder(ctx,1,-1,-1,.foreign~out,0)
  if \best~isa(.ForeignResult) then do
    ignoredCleanup=self~decodeCleanup(ctx,decoder,formatView,streamView,codecParameters,codecContext,packet,packetView,frame,frameView)
    return self~resampleFailure('DECODE_STREAM_SELECT_FAILED','av_find_best_stream did not return ForeignResult')
  end
  selected=best~returnValue
  if selected < 0 then do
    detail=self~errorText(selected); ignoredCleanup=self~decodeCleanup(ctx,decoder,formatView,streamView,codecParameters,codecContext,packet,packetView,frame,frameView)
    return self~resampleFailure('DECODE_NO_AUDIO_STREAM',detail)
  end
  decoder=best~out('decoder')
  formatView=decodeFormat~structView('AVFormatContext',ctx)
  streamsAddress=formatView~get('streams')
  streamAddress=.foreign~pointerAt(streamsAddress,selected)
  streamView=decodeFormat~structView('AVStream',streamAddress)
  codecParameters=decodeCodec~structView('AVCodecParameters',streamView~get('codecpar'))
  codecContext=decodeCodec~alloc_context(decoder)
  rc=decodeCodec~parameters_to_context(codecContext,codecParameters)
  if rc < 0 then do
    detail=self~errorText(rc); ignoredCleanup=self~decodeCleanup(ctx,decoder,formatView,streamView,codecParameters,codecContext,packet,packetView,frame,frameView)
    return self~resampleFailure('DECODE_PARAMETERS_FAILED',detail)
  end
  rc=decodeCodec~open_codec(codecContext,decoder,.nil)
  if rc < 0 then do
    detail=self~errorText(rc); ignoredCleanup=self~decodeCleanup(ctx,decoder,formatView,streamView,codecParameters,codecContext,packet,packetView,frame,frameView)
    return self~resampleFailure('DECODE_CODEC_OPEN_FAILED',detail)
  end
  packet=decodeCodec~packet_alloc
  packetView=decodeCodec~structView('AVPacket',packet)
  frame=decodeUtil~frame_alloc
  frameView=decodeUtil~structView('AVFrame',frame)
  totalSamples=0; frameCount=0; packetCount=0; audioPacketCount=0
  sourceFmt=-1; sourceFmtName=''; sourcePlanar=.false; bps=0
  packed=''; plane=''; terminalRc=0; done=.false
  do while \done
    readRc=decodeFormat~read_frame(ctx,packet)
    if readRc < 0 then do
      terminalRc=readRc
      leave
    end
    packetCount=packetCount+1
    if packetView~get('stream_index') = selected then do
      audioPacketCount=audioPacketCount+1
      sendRc=decodeCodec~send_packet(codecContext,packet)
      if sendRc >= 0 then do forever
        receiveRc=decodeCodec~receive_frame(codecContext,frame)
        if receiveRc < 0 then leave
        frameCount=frameCount+1
        nb=frameView~get('nb_samples'); fmt=frameView~get('format')
        if sourceFmt < 0 then do
          sourceFmt=fmt
          sourceFmtName=avutil~sample_format_name(fmt)
          bps=avutil~sample_format_bytes(fmt)
          sourcePlanar=(avutil~sample_format_planar(fmt) \= 0)
        end
        else if fmt \= sourceFmt then do
          ignoredFrameUnref=decodeUtil~frame_unref(frame)
          ignoredPacketUnref=decodeCodec~packet_unref(packet)
          ignoredCleanup=self~decodeCleanup(ctx,decoder,formatView,streamView,codecParameters,codecContext,packet,packetView,frame,frameView)
          return self~resampleFailure('UNSUPPORTED','decoded audio sample format changed within requested material')
        end
        if nb > 0 & bps > 0 then do
          addr=frameView~get('data0')
          if addr \= 0 then do
            bytes=.foreign~peekBytes(addr,nb*bps)
            if sourcePlanar then plane=plane || bytes
            else packed=packed || bytes
            totalSamples=totalSamples+nb
          end
        end
        ignoredFrameUnref=decodeUtil~frame_unref(frame)
        if maximumFrames > 0 & frameCount >= maximumFrames then do; done=.true; leave; end
      end
    end
    ignoredPacketUnref=decodeCodec~packet_unref(packet)
  end
  if \done then do
    sendRc=decodeCodec~send_packet(codecContext,.nil)
    if sendRc >= 0 then do forever
      receiveRc=decodeCodec~receive_frame(codecContext,frame)
      if receiveRc < 0 then leave
      frameCount=frameCount+1
      nb=frameView~get('nb_samples'); fmt=frameView~get('format')
      if sourceFmt < 0 then do
        sourceFmt=fmt; sourceFmtName=avutil~sample_format_name(fmt); bps=avutil~sample_format_bytes(fmt); sourcePlanar=(avutil~sample_format_planar(fmt) \= 0)
      end
      if nb > 0 & bps > 0 then do
        addr=frameView~get('data0')
        if addr \= 0 then do
          bytes=.foreign~peekBytes(addr,nb*bps)
          if sourcePlanar then plane=plane || bytes
          else packed=packed || bytes
          totalSamples=totalSamples+nb
        end
      end
      ignoredFrameUnref=decodeUtil~frame_unref(frame)
      if maximumFrames > 0 & frameCount >= maximumFrames then leave
    end
  end
  d=.Directory~new
  d['path']=path; d['selected_stream']=selected; d['sample_format']=sourceFmtName; d['format_id']=sourceFmt
  d['sample_rate']=sampleRate; d['channels']=channels; d['frame_count']=frameCount; d['sample_count']=totalSamples
  d['packet_count']=packetCount; d['audio_packet_count']=audioPacketCount; d['terminal_rc']=terminalRc
  d['source_planar']=sourcePlanar; d['bytes_per_sample']=bps; d['provider']='libavformat/libavcodec'
  d['avcodec_version']=decodeCodec~version; d['avutil_version']=decodeUtil~version
  if sourcePlanar then d['pcm_planes']=.Array~of(plane)
  else d['pcm_bytes']=packed
  ignoredCleanup=self~decodeCleanup(ctx,decoder,formatView,streamView,codecParameters,codecContext,packet,packetView,frame,frameView)
  return d

decodeFault:
  c=condition('O'); detail='native audio decode failed'
  if c \== .nil then if c~hasIndex('DESCRIPTION') then detail=c['DESCRIPTION']
  ignoredCleanup=self~decodeCleanup(ctx,decoder,formatView,streamView,codecParameters,codecContext,packet,packetView,frame,frameView)
  return self~resampleFailure('DECODE_FAULT',detail)

::method decodeCleanup private
  use strict arg ctx,decoder,formatView,streamView,codecParameters,codecContext,packet,packetView,frame,frameView
  if frameView \== .nil then frameView~close
  if frame \== .nil then frame~close
  if packetView \== .nil then packetView~close
  if packet \== .nil then packet~close
  if codecContext \== .nil then codecContext~close
  if codecParameters \== .nil then codecParameters~close
  if streamView \== .nil then streamView~close
  if formatView \== .nil then formatView~close
  if decoder \== .nil then decoder~close
  if ctx \== .nil then ctx~close
  return .true

::method transformPCM
  expose avutil swresample libc
  use strict arg request
  do key over .Array~of('input_sample_format','output_sample_format','input_channels','output_channels','input_sample_rate','output_sample_rate')
    if \request~hasIndex(key) then return self~resampleFailure('MALFORMED_REQUEST', 'PCM transform requires ' || key)
  end
  inFmtName = request['input_sample_format']~string~lower~strip
  outFmtName = request['output_sample_format']~string~lower~strip
  inChannels = request['input_channels']; outChannels = request['output_channels']
  inRate = request['input_sample_rate']; outRate = request['output_sample_rate']
  if \datatype(inChannels,'W') | inChannels < 1 | inChannels > 64 then return self~resampleFailure('MALFORMED_REQUEST','input_channels must be an integer from 1 to 64')
  if \datatype(outChannels,'W') | outChannels < 1 | outChannels > 64 then return self~resampleFailure('MALFORMED_REQUEST','output_channels must be an integer from 1 to 64')
  if \datatype(inRate,'W') | inRate < 1 then return self~resampleFailure('MALFORMED_REQUEST','input_sample_rate must be a positive integer')
  if \datatype(outRate,'W') | outRate < 1 then return self~resampleFailure('MALFORMED_REQUEST','output_sample_rate must be a positive integer')
  inFmt = avutil~sample_format_from_name(inFmtName); outFmt = avutil~sample_format_from_name(outFmtName)
  if inFmt < 0 then return self~resampleFailure('UNSUPPORTED','FFmpeg does not recognise input sample format ' || inFmtName)
  if outFmt < 0 then return self~resampleFailure('UNSUPPORTED','FFmpeg does not recognise output sample format ' || outFmtName)
  inPlanar = (avutil~sample_format_planar(inFmt) <> 0); outPlanar = (avutil~sample_format_planar(outFmt) <> 0)
  inBps = avutil~sample_format_bytes(inFmt); outBps = avutil~sample_format_bytes(outFmt)
  if inBps < 1 | outBps < 1 then return self~resampleFailure('UNSUPPORTED','sample format has no fixed bytes-per-sample width')

  if inPlanar then do
    if \request~hasIndex('pcm_planes') then return self~resampleFailure('MALFORMED_REQUEST','planar input requires pcm_planes')
    srcPlanes = request['pcm_planes']
    if \srcPlanes~isa(.Array) then return self~resampleFailure('MALFORMED_REQUEST','pcm_planes must be an Array')
    if srcPlanes~items \= inChannels then return self~resampleFailure('MALFORMED_REQUEST','pcm_planes count must equal input_channels')
    inSamples = -1
    do i = 1 to inChannels
      raw = srcPlanes[i]
      if raw~length // inBps <> 0 then return self~resampleFailure('MALFORMED_REQUEST','input plane length is not an integral number of samples')
      n = raw~length % inBps
      if inSamples < 0 then inSamples = n
      else if n \= inSamples then return self~resampleFailure('MALFORMED_REQUEST','all input planes must contain the same sample count')
    end
  end
  else do
    if \request~hasIndex('pcm_bytes') then return self~resampleFailure('MALFORMED_REQUEST','packed input requires pcm_bytes')
    srcBytes = request['pcm_bytes']
    frameBytes = inBps * inChannels
    if srcBytes~length // frameBytes <> 0 then return self~resampleFailure('MALFORMED_REQUEST','pcm_bytes length is not an integral number of input frames')
    inSamples = srcBytes~length % frameBytes
  end

  if inSamples = 0 then do
    d = .Directory~new
    if outPlanar then do
      out = .Array~new; do i = 1 to outChannels; out~append(''); end
      d['pcm_planes'] = out
    end
    else d['pcm_bytes'] = ''
    d['input_sample_format'] = avutil~sample_format_name(inFmt); d['output_sample_format'] = avutil~sample_format_name(outFmt)
    d['input_channels'] = inChannels; d['output_channels'] = outChannels
    d['input_sample_rate'] = inRate; d['output_sample_rate'] = outRate
    d['input_samples'] = 0; d['output_samples'] = 0; d['output_planar'] = outPlanar
    d['bytes_per_output_sample'] = outBps; d['provider'] = 'libswresample'; d['swresample_version'] = swresample~version
    return d
  end

  inLayout=.nil; outLayout=.nil; ctx=.nil; inPtrs=.nil; outPtrs=.nil
  inBuffers=.Array~new; outBuffers=.Array~new
  signal on syntax name transformFault
  inLayout=avutil~struct('AVChannelLayout'); outLayout=avutil~struct('AVChannelLayout')
  avutil~layout_default(inLayout,inChannels); avutil~layout_default(outLayout,outChannels)
  allocated=swresample~alloc_set_opts2(.foreign~out,outLayout,outFmt,outRate,inLayout,inFmt,inRate,0,.nil)
  if allocated~returnValue < 0 then do
    code=allocated~returnValue; ignored=self~transformCleanup(inLayout,outLayout,ctx,inBuffers,inPtrs,outBuffers,outPtrs)
    return self~resampleFailure('FFMPEG_ERROR','swr_alloc_set_opts2 failed: ' || self~errorText(code))
  end
  ctx=allocated~out('context'); rc=swresample~swr_init_call(ctx)
  if rc < 0 then do
    ignored=self~transformCleanup(inLayout,outLayout,ctx,inBuffers,inPtrs,outBuffers,outPtrs)
    return self~resampleFailure('FFMPEG_ERROR','swr_init failed: ' || self~errorText(rc))
  end

  inPtrCount = 1; if inPlanar then inPtrCount = inChannels
  inPtrs=.foreign~pointerArray(inPtrCount,'u8')
  if inPlanar then do i=1 to inChannels
    b=.foreign~buffer(srcPlanes[i]~length); ignored=libc~memcpy_call(b,srcPlanes[i],srcPlanes[i]~length); inBuffers~append(b); inPtrs~put(b,i)
  end
  else do
    b=.foreign~buffer(srcBytes~length); ignored=libc~memcpy_call(b,srcBytes,srcBytes~length); inBuffers~append(b); inPtrs~put(b,1)
  end

  capacity=((inSamples*outRate+inRate-1)%inRate)+256; if capacity < 256 then capacity=256
  outPtrCount=1; if outPlanar then outPtrCount=outChannels
  outPtrs=.foreign~pointerArray(outPtrCount,'u8')
  if outPlanar then do i=1 to outChannels
    b=.foreign~buffer(capacity*outBps); outBuffers~append(b); outPtrs~put(b,i)
  end
  else do
    b=.foreign~buffer(capacity*outBps*outChannels); outBuffers~append(b); outPtrs~put(b,1)
  end
  made=swresample~swr_convert_call(ctx,outPtrs,capacity,inPtrs,inSamples)
  if made < 0 then do
    ignored=self~transformCleanup(inLayout,outLayout,ctx,inBuffers,inPtrs,outBuffers,outPtrs)
    return self~resampleFailure('FFMPEG_ERROR','swr_convert failed: ' || self~errorText(made))
  end
  if outPlanar then do
    outputPlanes=.Array~new; do i=1 to outChannels; outputPlanes~append(outBuffers[i]~bytes~left(made*outBps)); end
  end
  else outputBytes=outBuffers[1]~bytes~left(made*outBps*outChannels)
  total=made

  do flushCount=1 to 16
    flushBuffers=.Array~new; flushPtrs=.foreign~pointerArray(outPtrCount,'u8')
    if outPlanar then do i=1 to outChannels
      b=.foreign~buffer(capacity*outBps); flushBuffers~append(b); flushPtrs~put(b,i)
    end
    else do
      b=.foreign~buffer(capacity*outBps*outChannels); flushBuffers~append(b); flushPtrs~put(b,1)
    end
    flushed=swresample~swr_convert_call(ctx,flushPtrs,capacity,.nil,0)
    if flushed < 0 then do
      flushPtrs~close; do b over flushBuffers; b~close; end
      ignored=self~transformCleanup(inLayout,outLayout,ctx,inBuffers,inPtrs,outBuffers,outPtrs)
      return self~resampleFailure('FFMPEG_ERROR','swr_convert flush failed: ' || self~errorText(flushed))
    end
    if flushed > 0 then do
      if outPlanar then do i=1 to outChannels; outputPlanes[i]=outputPlanes[i] || flushBuffers[i]~bytes~left(flushed*outBps); end
      else outputBytes=outputBytes || flushBuffers[1]~bytes~left(flushed*outBps*outChannels)
      total=total+flushed
    end
    flushPtrs~close; do b over flushBuffers; b~close; end
    if flushed=0 then leave
  end

  d=.Directory~new
  if outPlanar then d['pcm_planes']=outputPlanes; else d['pcm_bytes']=outputBytes
  d['input_sample_format']=avutil~sample_format_name(inFmt); d['output_sample_format']=avutil~sample_format_name(outFmt)
  d['input_channels']=inChannels; d['output_channels']=outChannels
  d['input_sample_rate']=inRate; d['output_sample_rate']=outRate
  d['input_samples']=inSamples; d['output_samples']=total; d['output_planar']=outPlanar
  d['bytes_per_output_sample']=outBps; d['provider']='libswresample'; d['swresample_version']=swresample~version
  ignored=self~transformCleanup(inLayout,outLayout,ctx,inBuffers,inPtrs,outBuffers,outPtrs)
  return d
transformFault:
  ignored=self~transformCleanup(inLayout,outLayout,ctx,inBuffers,inPtrs,outBuffers,outPtrs)
  raise syntax 88.900 array('FFmpeg PCM transform foreign invocation failed')

::method transformCleanup private
  expose avutil
  use strict arg inLayout,outLayout,ctx,inBuffers,inPtrs,outBuffers,outPtrs
  if outPtrs \== .nil then outPtrs~close
  if inPtrs \== .nil then inPtrs~close
  if outBuffers \== .nil then do b over outBuffers; if b \== .nil then b~close; end
  if inBuffers \== .nil then do b over inBuffers; if b \== .nil then b~close; end
  if ctx \== .nil then ctx~close
  if inLayout \== .nil then do; avutil~layout_uninit(inLayout); inLayout~close; end
  if outLayout \== .nil then do; avutil~layout_uninit(outLayout); outLayout~close; end
  return .true

::method resamplePCM
  expose avutil swresample libc
  use strict arg request
  fail = .Directory~new
  if \request~hasIndex('sample_format') then return self~resampleFailure('MALFORMED_REQUEST', 'PCM resample requires sample_format')
  if \request~hasIndex('channels') then return self~resampleFailure('MALFORMED_REQUEST', 'PCM resample requires channels')
  if \request~hasIndex('input_sample_rate') then return self~resampleFailure('MALFORMED_REQUEST', 'PCM resample requires input_sample_rate')
  if \request~hasIndex('output_sample_rate') then return self~resampleFailure('MALFORMED_REQUEST', 'PCM resample requires output_sample_rate')

  fmtName = request['sample_format']~string~lower~strip
  channels = request['channels']
  inRate = request['input_sample_rate']
  outRate = request['output_sample_rate']
  if \datatype(channels, 'W') | channels < 1 | channels > 64 then return self~resampleFailure('MALFORMED_REQUEST', 'channels must be an integer from 1 to 64')
  if \datatype(inRate, 'W') | inRate < 1 then return self~resampleFailure('MALFORMED_REQUEST', 'input_sample_rate must be a positive integer')
  if \datatype(outRate, 'W') | outRate < 1 then return self~resampleFailure('MALFORMED_REQUEST', 'output_sample_rate must be a positive integer')
  fmt = avutil~sample_format_from_name(fmtName)
  if fmt < 0 then return self~resampleFailure('UNSUPPORTED', 'FFmpeg does not recognise sample format ' || fmtName)
  planar = (avutil~sample_format_planar(fmt) <> 0)
  bps = avutil~sample_format_bytes(fmt)
  if bps < 1 then return self~resampleFailure('UNSUPPORTED', 'sample format has no fixed bytes-per-sample width')
  if planar then return self~resamplePlanar(request, fmtName, fmt, bps, channels, inRate, outRate)
  if \request~hasIndex('pcm_bytes') then return self~resampleFailure('MALFORMED_REQUEST', 'packed PCM resample requires pcm_bytes')
  raw = request['pcm_bytes']
  frameBytes = bps * channels
  if raw~length // frameBytes <> 0 then return self~resampleFailure('MALFORMED_REQUEST', 'pcm_bytes length is not an integral number of interleaved sample frames')
  inSamples = raw~length % frameBytes
  if inSamples = 0 then do
    d = .Directory~new
    d['pcm_bytes'] = ''
    d['sample_format'] = fmtName
    d['channels'] = channels
    d['input_sample_rate'] = inRate
    d['output_sample_rate'] = outRate
    d['input_samples'] = 0
    d['output_samples'] = 0
    d['provider'] = 'libswresample'
    d['swresample_version'] = swresample~version
    return d
  end

  inLayout = .nil; outLayout = .nil; ctx = .nil; inBuf = .nil; inPlanes = .nil; outPlanes = .nil; outBuf = .nil
  signal on syntax name resampleFault
  inLayout = avutil~struct('AVChannelLayout')
  outLayout = avutil~struct('AVChannelLayout')
  avutil~layout_default(inLayout, channels)
  avutil~layout_default(outLayout, channels)
  allocated = swresample~alloc_set_opts2(.foreign~out, outLayout, fmt, outRate, inLayout, fmt, inRate, 0, .nil)
  if allocated~returnValue < 0 then do
    code = allocated~returnValue
    ignoredCleanup = self~resampleCleanup(inLayout, outLayout, ctx, inBuf, inPlanes, outPlanes, outBuf)
    return self~resampleFailure('FFMPEG_ERROR', 'swr_alloc_set_opts2 failed: ' || self~errorText(code))
  end
  ctx = allocated~out('context')
  rc = swresample~swr_init_call(ctx)
  if rc < 0 then do
    ignoredCleanup = self~resampleCleanup(inLayout, outLayout, ctx, inBuf, inPlanes, outPlanes, outBuf)
    return self~resampleFailure('FFMPEG_ERROR', 'swr_init failed: ' || self~errorText(rc))
  end

  inBuf = .foreign~buffer(raw~length)
  ignored = libc~memcpy_call(inBuf, raw, raw~length)
  inPlanes = .foreign~pointerArray(1, 'u8')
  inPlanes~put(inBuf, 1)

  capacity = ((inSamples * outRate + inRate - 1) % inRate) + 256
  if capacity < 256 then capacity = 256
  outBuf = .foreign~buffer(capacity * frameBytes)
  outPlanes = .foreign~pointerArray(1, 'u8')
  outPlanes~put(outBuf, 1)
  made = swresample~swr_convert_call(ctx, outPlanes, capacity, inPlanes, inSamples)
  if made < 0 then do
    ignoredCleanup = self~resampleCleanup(inLayout, outLayout, ctx, inBuf, inPlanes, outPlanes, outBuf)
    return self~resampleFailure('FFMPEG_ERROR', 'swr_convert failed: ' || self~errorText(made))
  end
  output = outBuf~bytes~left(made * frameBytes)
  total = made

  /* Drain filter delay into fresh buffers.  Each ForeignBuffer starts at offset zero,
   * so separate flush buffers avoid unsafe pointer arithmetic. */
  do flushCount = 1 to 16
    flushBuf = .foreign~buffer(capacity * frameBytes)
    flushPlanes = .foreign~pointerArray(1, 'u8')
    flushPlanes~put(flushBuf, 1)
    flushed = swresample~swr_convert_call(ctx, flushPlanes, capacity, .nil, 0)
    if flushed < 0 then do
      flushPlanes~close; flushBuf~close
      ignoredCleanup = self~resampleCleanup(inLayout, outLayout, ctx, inBuf, inPlanes, outPlanes, outBuf)
      return self~resampleFailure('FFMPEG_ERROR', 'swr_convert flush failed: ' || self~errorText(flushed))
    end
    if flushed > 0 then do
      output = output || flushBuf~bytes~left(flushed * frameBytes)
      total = total + flushed
    end
    flushPlanes~close; flushBuf~close
    if flushed = 0 then leave
  end

  d = .Directory~new
  d['pcm_bytes'] = output
  d['sample_format'] = avutil~sample_format_name(fmt)
  d['channels'] = channels
  d['input_sample_rate'] = inRate
  d['output_sample_rate'] = outRate
  d['input_samples'] = inSamples
  d['output_samples'] = total
  d['bytes_per_sample'] = bps
  d['provider'] = 'libswresample'
  d['swresample_version'] = swresample~version
  ignoredCleanup = self~resampleCleanup(inLayout, outLayout, ctx, inBuf, inPlanes, outPlanes, outBuf)
  return d

resampleFault:
  ignoredCleanup = self~resampleCleanup(inLayout, outLayout, ctx, inBuf, inPlanes, outPlanes, outBuf)
  raise syntax 88.900 array('FFmpeg PCM resample foreign invocation failed')


::method resamplePlanar private
  expose avutil swresample libc
  use strict arg request, fmtName, fmt, bps, channels, inRate, outRate
  if \request~hasIndex('pcm_planes') then return self~resampleFailure('MALFORMED_REQUEST', 'planar PCM resample requires pcm_planes')
  planes = request['pcm_planes']
  if \planes~isa(.Array) then return self~resampleFailure('MALFORMED_REQUEST', 'pcm_planes must be an Array')
  if planes~items \= channels then return self~resampleFailure('MALFORMED_REQUEST', 'pcm_planes count must equal channels')
  inSamples = -1
  do i = 1 to channels
    plane = planes[i]
    if plane~length // bps \= 0 then return self~resampleFailure('MALFORMED_REQUEST', 'each planar PCM plane length must be an integral number of samples')
    n = plane~length % bps
    if inSamples < 0 then inSamples = n
    else if n \= inSamples then return self~resampleFailure('MALFORMED_REQUEST', 'all planar PCM planes must contain the same sample count')
  end
  if inSamples = 0 then do
    d = .Directory~new
    d['pcm_planes'] = .Array~new
    do i = 1 to channels; d['pcm_planes']~append(''); end
    d['sample_format'] = fmtName
    d['channels'] = channels
    d['input_sample_rate'] = inRate
    d['output_sample_rate'] = outRate
    d['input_samples'] = 0
    d['output_samples'] = 0
    d['bytes_per_sample'] = bps
    d['planar'] = .true
    d['provider'] = 'libswresample'
    d['swresample_version'] = swresample~version
    return d
  end

  inLayout = .nil; outLayout = .nil; ctx = .nil; inPlanes = .nil; outPlanes = .nil
  inBuffers = .Array~new; outBuffers = .Array~new
  signal on syntax name planarFault
  inLayout = avutil~struct('AVChannelLayout')
  outLayout = avutil~struct('AVChannelLayout')
  avutil~layout_default(inLayout, channels)
  avutil~layout_default(outLayout, channels)
  allocated = swresample~alloc_set_opts2(.foreign~out, outLayout, fmt, outRate, inLayout, fmt, inRate, 0, .nil)
  if allocated~returnValue < 0 then do
    code = allocated~returnValue
    ignoredCleanup = self~resamplePlanarCleanup(inLayout, outLayout, ctx, inBuffers, inPlanes, outBuffers, outPlanes)
    return self~resampleFailure('FFMPEG_ERROR', 'swr_alloc_set_opts2 failed: ' || self~errorText(code))
  end
  ctx = allocated~out('context')
  rc = swresample~swr_init_call(ctx)
  if rc < 0 then do
    ignoredCleanup = self~resamplePlanarCleanup(inLayout, outLayout, ctx, inBuffers, inPlanes, outBuffers, outPlanes)
    return self~resampleFailure('FFMPEG_ERROR', 'swr_init failed: ' || self~errorText(rc))
  end

  inPlanes = .foreign~pointerArray(channels, 'u8')
  do i = 1 to channels
    b = .foreign~buffer(planes[i]~length)
    ignored = libc~memcpy_call(b, planes[i], planes[i]~length)
    inBuffers~append(b)
    inPlanes~put(b, i)
  end

  capacity = ((inSamples * outRate + inRate - 1) % inRate) + 256
  if capacity < 256 then capacity = 256
  outPlanes = .foreign~pointerArray(channels, 'u8')
  do i = 1 to channels
    b = .foreign~buffer(capacity * bps)
    outBuffers~append(b)
    outPlanes~put(b, i)
  end
  made = swresample~swr_convert_call(ctx, outPlanes, capacity, inPlanes, inSamples)
  if made < 0 then do
    ignoredCleanup = self~resamplePlanarCleanup(inLayout, outLayout, ctx, inBuffers, inPlanes, outBuffers, outPlanes)
    return self~resampleFailure('FFMPEG_ERROR', 'swr_convert failed: ' || self~errorText(made))
  end
  outputPlanes = .Array~new
  do i = 1 to channels
    outputPlanes~append(outBuffers[i]~bytes~left(made * bps))
  end
  total = made

  do flushCount = 1 to 16
    flushBuffers = .Array~new
    flushPlanes = .foreign~pointerArray(channels, 'u8')
    do i = 1 to channels
      b = .foreign~buffer(capacity * bps)
      flushBuffers~append(b)
      flushPlanes~put(b, i)
    end
    flushed = swresample~swr_convert_call(ctx, flushPlanes, capacity, .nil, 0)
    if flushed < 0 then do
      flushPlanes~close
      do b over flushBuffers; b~close; end
      ignoredCleanup = self~resamplePlanarCleanup(inLayout, outLayout, ctx, inBuffers, inPlanes, outBuffers, outPlanes)
      return self~resampleFailure('FFMPEG_ERROR', 'swr_convert planar flush failed: ' || self~errorText(flushed))
    end
    if flushed > 0 then do
      do i = 1 to channels
        outputPlanes[i] = outputPlanes[i] || flushBuffers[i]~bytes~left(flushed * bps)
      end
      total = total + flushed
    end
    flushPlanes~close
    do b over flushBuffers; b~close; end
    if flushed = 0 then leave
  end

  d = .Directory~new
  d['pcm_planes'] = outputPlanes
  d['sample_format'] = avutil~sample_format_name(fmt)
  d['channels'] = channels
  d['input_sample_rate'] = inRate
  d['output_sample_rate'] = outRate
  d['input_samples'] = inSamples
  d['output_samples'] = total
  d['bytes_per_sample'] = bps
  d['planar'] = .true
  d['provider'] = 'libswresample'
  d['swresample_version'] = swresample~version
  ignoredCleanup = self~resamplePlanarCleanup(inLayout, outLayout, ctx, inBuffers, inPlanes, outBuffers, outPlanes)
  return d

planarFault:
  ignoredCleanup = self~resamplePlanarCleanup(inLayout, outLayout, ctx, inBuffers, inPlanes, outBuffers, outPlanes)
  raise syntax 88.900 array('FFmpeg planar PCM resample foreign invocation failed')

::method resamplePlanarCleanup private
  expose avutil
  use strict arg inLayout, outLayout, ctx, inBuffers, inPlanes, outBuffers, outPlanes
  if outPlanes \== .nil then outPlanes~close
  if inPlanes \== .nil then inPlanes~close
  if outBuffers \== .nil then do b over outBuffers; if b \== .nil then b~close; end
  if inBuffers \== .nil then do b over inBuffers; if b \== .nil then b~close; end
  if ctx \== .nil then ctx~close
  if inLayout \== .nil then do
    avutil~layout_uninit(inLayout)
    inLayout~close
  end
  if outLayout \== .nil then do
    avutil~layout_uninit(outLayout)
    outLayout~close
  end
  return .true

::method resampleFailure private
  use strict arg code, detail
  d = .Directory~new
  d['_error_code'] = code
  d['_error_detail'] = detail
  return d

::method resampleCleanup private
  expose avutil
  use strict arg inLayout, outLayout, ctx, inBuf, inPlanes, outPlanes, outBuf
  if outPlanes \== .nil then outPlanes~close
  if inPlanes \== .nil then inPlanes~close
  if outBuf \== .nil then outBuf~close
  if inBuf \== .nil then inBuf~close
  if ctx \== .nil then ctx~close
  if inLayout \== .nil then do
    avutil~layout_uninit(inLayout)
    inLayout~close
  end
  if outLayout \== .nil then do
    avutil~layout_uninit(outLayout)
    outLayout~close
  end
  return .true

::method errorText
  expose avutil
  use strict arg errorCode
  b = .foreign~buffer(256)
  signal on syntax name errorTextFault
  rc = avutil~error_text(errorCode, b, 256)
  if rc < 0 then do
    b~close
    return ''
  end
  raw = b~bytes
  b~close
  nul = raw~pos('00'x)
  if nul > 0 then return raw~substr(1, nul - 1)
  return raw
errorTextFault:
  if symbol('b') = 'VAR' then if b \== .nil then if \b~closed then b~close
  raise syntax 88.900 array('av_strerror foreign invocation failed')

::method implementationId
  expose avutil avcodec swresample avformat
  return 'ffmpeg:' || avutil~version_info || ';avutil=' || avutil~version || ';avcodec=' || avcodec~version || ';swresample=' || swresample~version || ';avformat=' || avformat~version

::method close
  expose avutil avcodec swresample avformat libc decodeFormat decodeCodec decodeUtil
  if avutil \== .nil then avutil~close
  if avcodec \== .nil then avcodec~close
  if swresample \== .nil then swresample~close
  if avformat \== .nil then avformat~close
  if libc \== .nil then libc~close
  if decodeFormat \== .nil then decodeFormat~close
  if decodeCodec \== .nil then decodeCodec~close
  if decodeUtil \== .nil then decodeUtil~close

::requires 'foreign.cls'
::requires 'RuntimeImplementationReference.cls'
::requires 'AudioRuntimeWorkers.cls'
