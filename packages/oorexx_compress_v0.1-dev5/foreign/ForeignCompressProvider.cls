/*----------------------------------------------------------------------------*/
/* ForeignCompressProvider.cls                                                */
/* Optional accelerated provider using libzstd through ooRexx Foreign Runtime.*/
/* The native provider remains the bootstrap/reference implementation.         */
/*----------------------------------------------------------------------------*/
::class ForeignCompressProvider public

::method init
  expose library fallback maxOutputBytes
  use strict arg bridgePath, maxOutputBytes = 536870912
  if maxOutputBytes < 1 then raise syntax 88.900 array('maxOutputBytes must be positive')
  library = .foreign~load(bridgePath)
  fallback = .NativeCompressProvider~new

::method name
  return 'foreign-runtime-libzstd'

::method capabilities
  return .array~of('checksum.crc32', 'checksum.xxh64', -
                   'compress.gzip.fixed', 'compress.gzip.stored', -
                   'decompress.gzip.fixed', 'decompress.gzip.stored', -
                   'compress.deflate.fixed', 'compress.deflate.stored', -
                   'decompress.deflate.fixed', 'decompress.deflate.stored', -
                   'compress.zstd.raw', 'compress.zstd.rle', -
                   'compress.zstd.compressed', 'decompress.zstd.compressed', -
                   'provider.foreign-runtime', 'provider.libzstd')

::method gzip
  expose fallback
  use strict arg bytes, mode = 'FIXED'
  return fallback~gzip(bytes,mode)

::method gunzip
  expose fallback
  use strict arg bytes
  return fallback~gunzip(bytes)

::method deflateFixed
  expose fallback
  use strict arg bytes
  return fallback~deflateFixed(bytes)

::method deflateStored
  expose fallback
  use strict arg bytes
  return fallback~deflateStored(bytes)

::method inflate
  expose fallback
  use strict arg bytes
  return fallback~inflate(bytes)

::method crc32
  expose fallback
  use strict arg bytes
  return fallback~crc32(bytes)

::method xxh64
  expose fallback
  use strict arg bytes, seed = 0
  return fallback~xxh64(bytes,seed)

::method zstd
  expose library fallback
  use strict arg bytes, mode = 'AUTO', checksum = .true
  mode = translate(mode)
  if mode == 'RAW' | mode == 'RLE' then return fallback~zstd(bytes,mode,checksum)
  if mode \== 'AUTO' & mode \== 'FOREIGN' & mode \== 'COMPRESSED' then -
    raise syntax 88.900 array('Unsupported ForeignCompressProvider Zstandard mode: ' || mode)
  checksumFlag = 0
  if checksum == .true | checksum == 1 then checksumFlag = 1
  else if checksum \== .false & checksum \== 0 then raise syntax 88.900 array('Zstandard checksum option must be boolean')

  context = library~createCCtx
  code = library~setParameter(context,100,3)       /* ZSTD_c_compressionLevel */
  if library~isError(code) then do
    message = library~getErrorName(code)
    context~close
    raise syntax 88.900 array('libzstd compression-level setup failed: ' || message)
  end
  code = library~setParameter(context,201,checksumFlag) /* ZSTD_c_checksumFlag */
  if library~isError(code) then do
    message = library~getErrorName(code)
    context~close
    raise syntax 88.900 array('libzstd checksum setup failed: ' || message)
  end

  capacity = library~compressBound(length(bytes))
  outBuffer = .foreign~buffer(capacity)
  written = library~compress2(context,outBuffer,capacity,bytes,length(bytes))
  if library~isError(written) then do
    message = library~getErrorName(written)
    outBuffer~close
    context~close
    raise syntax 88.900 array('libzstd compression failed: ' || message)
  end
  compressedBytes = outBuffer~getBytes(0,written)
  outBuffer~close
  context~close
  return compressedBytes

::method unzstd
  expose library maxOutputBytes
  use strict arg bytes
  numeric digits 80
  bound = library~decompressBound(bytes,length(bytes))
  if bound == 18446744073709551614 then raise syntax 88.900 array('libzstd rejected the frame stream while calculating decompression bound')
  if bound > maxOutputBytes then raise syntax 88.900 array('libzstd decompression bound ' || bound || ' exceeds configured output limit ' || maxOutputBytes)
  capacity = bound
  if capacity < 1 then capacity = 1
  outBuffer = .foreign~buffer(capacity)
  decodedSize = library~decompress(outBuffer,capacity,bytes,length(bytes))
  if library~isError(decodedSize) then do
    message = library~getErrorName(decodedSize)
    outBuffer~close
    raise syntax 88.900 array('libzstd decompression failed: ' || message)
  end
  decodedBytes = outBuffer~getBytes(0,decodedSize)
  outBuffer~close
  return decodedBytes

::method close
  expose library
  if library \== .nil then do
    library~close
    library = .nil
  end
  return self

::requires 'NativeCompressProvider.cls'
::requires 'foreign.cls'
