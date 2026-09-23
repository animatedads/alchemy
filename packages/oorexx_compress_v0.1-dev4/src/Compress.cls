/*----------------------------------------------------------------------------*/
/* ooRexx Compress v0.1-dev3                                                  */
/* Bootstrap-safe compression facade. Pure ooRexx native provider is default. */
/*----------------------------------------------------------------------------*/

::class CompressBuild public
::constant VERSION '0.1-dev4'
::constant API 'oorexx.compress/0.1'

::class Compress public
::method init
  expose provider
  use strict arg providerArg = .nil
  if providerArg == .nil then provider = .NativeCompressProvider~new
  else provider = providerArg

::method provider
  expose provider
  return provider~name

::method capabilities
  expose provider
  return provider~capabilities

::method gzip
  expose provider
  use strict arg bytes, mode = 'FIXED'
  return provider~gzip(bytes, mode)

::method gunzip
  expose provider
  use strict arg bytes
  return provider~gunzip(bytes)

::method deflateFixed
  expose provider
  use strict arg bytes
  return provider~deflateFixed(bytes)

::method deflateStored
  expose provider
  use strict arg bytes
  return provider~deflateStored(bytes)

::method inflate
  expose provider
  use strict arg bytes, maxOutputBytes = .nil
  return provider~inflate(bytes, maxOutputBytes)

::method crc32
  expose provider
  use strict arg bytes
  return provider~crc32(bytes)

::method zstd
  expose provider
  use strict arg bytes, mode = 'AUTO', checksum = .true
  return provider~zstd(bytes, mode, checksum)

::method unzstd
  expose provider
  use strict arg bytes
  return provider~unzstd(bytes)

::method xxh64
  expose provider
  use strict arg bytes, seed = 0
  return provider~xxh64(bytes, seed)

::requires 'NativeCompressProvider.cls'
