/* ooRexx MPEG-TS PES -> H.264 access unit -> native RGB24 frame provider.
 * TS packet parsing, PTS, packet budgets and seek are ooRexx-owned.
 * Explicit frameAt uses source-bound IDR seek candidate and capped transfer;
 * codec alone handles H.264 compressed reference pictures and B frames.
 * No ffmpeg invocation, ffmpeg input demux, Python, or source-wide read.
 */
::options digits 30

::class MediaTsVideoFrames public
::attribute file get
::attribute decoderClass get
::method init
  expose file decoderClass
  use strict arg tsFile,decoderType=.MediaH264Decoder
  if tsFile~videoCodec<>'H264_ANNEXB' then -
    raise syntax 88.900 array('TS video codec is not H264 Annex B')
  file=tsFile; decoderClass=decoderType
::method frameAt
  expose file decoderClass
  use strict arg wantedTicks,budgetBytes=4194304,maxFrames=240
  if \datatype(wantedTicks,'W') | wantedTicks<0 then -
    raise syntax 88.900 array('target PTS must be nonnegative 90kHz ticks')
  if \datatype(budgetBytes,'W') | budgetBytes<188 | -
     budgetBytes>16777216 | \datatype(maxFrames,'W') | -
     maxFrames<1 | maxFrames>900 then -
    raise syntax 88.900 array('invalid video seek budget')
  range=file~planBoundedRange(wantedTicks,budgetBytes)
  if range==.nil then return .nil
  /* Require an IDR on the signed immutable index, not sequential origin scan. */
  offset=range['offset']; remaining=range['bytes']; remaining=remaining-(remaining//188)
  if remaining<188 then return .nil
  source=file~source; pid=file~videoPid
  codec=decoderClass~new
  currentEs=''; currentPts=-1; valid=.false
  framesSeen=0
  found=.nil
  do while remaining>=188 & found==.nil
    n=min(48128,remaining)
    n=n-(n//188)
    bytes=source~readAt(offset,n)
    if bytes~length<>n then raise syntax 88.900 array('short bounded TS payload read')
    do at=1 to n by 188
      packet=.MediaTsWire~packet(substr(bytes,at,188))
      if packet['pid']<>pid then iterate
      data=packet['payload']; if data='' then iterate
      if packet['pusi']=1 then do
        if valid & currentEs<>'' then do
          decoded=codec~feed(currentEs,currentPts)
          do frame over decoded
            framesSeen+=1
            if frame~presentationTicks>=wantedTicks then do
              found=frame
              leave
            end
            if framesSeen>=maxFrames then leave
          end
        end
        if found<>.nil | framesSeen>=maxFrames then leave
        pes=.MediaTsWire~pesInfo(data)
        currentPts=pes['pts']; currentEs=pes['es']; valid=.true
      end
      else if valid then currentEs=currentEs||data
    end
    offset+=n;remaining-=n
    if framesSeen>=maxFrames then leave
  end
  if found==.nil & valid & currentEs<>'' then do
    decoded=codec~feed(currentEs,currentPts)
    do frame over decoded
      framesSeen+=1
      if frame~presentationTicks>=wantedTicks then do
        found=frame
        leave
      end
    end
  end
  if found==.nil then do
    flushed=codec~flush
    do frame over flushed
      framesSeen+=1
      if frame~presentationTicks>=wantedTicks then do
        found=frame
        leave
      end
    end
  end
  ignore=codec~close
  return found
::requires 'MediaH264Frames.cls'
::requires 'MediaTsFile.cls'