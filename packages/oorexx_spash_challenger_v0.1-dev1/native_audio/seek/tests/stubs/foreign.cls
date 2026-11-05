/* TEST-ONLY Foreign Runtime stub. Never put this file on the deployed REXX_PATH. */
::class foreign public
::method load class
  use strict arg path
  return .FakeNative~new
::class FakeNative public
::method catalogue
  use strict arg file,out,budget
  return 0
::method seek_decode
  use strict arg file,out,meta,stream,channel,start,duration,rate,budget
  return 0
::method last_error
  return ''
