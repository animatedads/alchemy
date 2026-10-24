::class Pcm16WavWriter public
::method writeMono class
  use strict arg fileName,samples,sampleRate
  peak=0
  do x over samples
    a=abs(x)
    if a>peak then peak=a
  end
  if peak=0 then peak=1
  scale=.94/peak
  dataSize=samples~items*2
  header='RIFF'||self~u32(36+dataSize)||'WAVE'||'fmt '||self~u32(16)||self~u16(1)||self~u16(1)||self~u32(sampleRate)||self~u32(sampleRate*2)||self~u16(2)||self~u16(16)||'data'||self~u32(dataSize)
  call charout fileName, header
  chunk=''; chunkSamples=0
  do x over samples
    y=x*scale
    if y>1 then y=1
    if y< -1 then y=-1
    n=(y*32767)~trunc
    if n<0 then n=n+65536
    chunk=chunk||self~u16(n)
    chunkSamples+=1
    if chunkSamples>=2048 then do
      call charout fileName, chunk
      chunk=''; chunkSamples=0
    end
  end
  if chunk~length>0 then call charout fileName, chunk
  call charout fileName
  return fileName
::method u16 class
  use strict arg n
  return d2c(n//256,1)||d2c((n%256)//256,1)
::method u32 class
  use strict arg n
  b0=n//256; n=n%256
  b1=n//256; n=n%256
  b2=n//256; n=n%256
  b3=n//256
  return d2c(b0,1)||d2c(b1,1)||d2c(b2,1)||d2c(b3,1)
