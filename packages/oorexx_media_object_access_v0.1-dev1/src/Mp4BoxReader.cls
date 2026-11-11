/* Shared bounded MP4 atom metadata reader. No sample-table or edit-list
 * imports: both modules depend directly on this neutral ooRexx class.
 * Absolute reads stay bounded to 8192 bytes within one atom.
 */
::options digits 30

/* Metadata-only bounded reader. Reuses a single <=8192 byte block per box.
 * Several small field reads do not cause one remote Storage GET each. */
::class Mp4BoxReader public
::method init
  expose atom cachedStart cached payloadBytes
  use strict arg mp4Atom
  atom=mp4Atom; cachedStart=-1; cached=''
  payloadBytes=atom~length-atom~headerBytes
::method payloadBytes
  expose payloadBytes
  return payloadBytes
::method bytes
  expose atom cachedStart cached payloadBytes
  use strict arg offset,n
  if datatype(offset,'W')=0 | datatype(n,'W')=0 | offset<0 | n<0 | -
     offset+n>payloadBytes | n>8192 then -
    raise syntax 88.900 array('MP4 metadata read out of bounds',offset,n)
  if n=0 then return ''
  if cachedStart>=0 then do
    if offset>=cachedStart & offset+n<=cachedStart+cached~length then -
      return substr(cached,offset-cachedStart+1,n)
  end
  cachedStart=offset
  wanted=payloadBytes-offset
  if wanted>8192 then wanted=8192
  cached=atom~exactBytes(offset,wanted)
  return substr(cached,1,n)
::method unsigned
  use strict arg offset,n
  if n<>1 & n<>2 & n<>4 & n<>8 then -
    raise syntax 88.900 array('unsupported MP4 integer width',n)
  return x2d(c2x(self~bytes(offset,n)))
::method signed16
  use strict arg offset
  n=self~unsigned(offset,2)
  if n>=32768 then n=n-65536
  return n
::method signed32
  use strict arg offset
  n=self~unsigned(offset,4)
  if n>=2147483648 then n=n-4294967296
  return n
::method signed64
  use strict arg offset
  n=self~unsigned(offset,8)
  if n>=9223372036854775808 then n=n-18446744073709551616
  return n
::method version
  return self~unsigned(0,1)
::method requireBytes
  expose payloadBytes
  use strict arg n
  if datatype(n,'W')=0 | n>payloadBytes then -
    raise syntax 88.900 array('truncated MP4 sample table',n,payloadBytes)
