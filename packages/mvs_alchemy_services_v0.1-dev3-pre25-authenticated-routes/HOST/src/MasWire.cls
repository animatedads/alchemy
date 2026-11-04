/* MasWire.cls - executable mvs.alchemy/1 frame + typed-value codec.
 * pre9 live-guest cut.  All multi-byte integers are big-endian.
 */

::class MasWire public
::constant MAJOR 1
::constant MINOR 0
::constant HEADER_LENGTH 48
::constant MAX_FRAME 32768

::constant OP_HELLO 1
::constant OP_ACCEPT 2
::constant OP_PING 3
::constant OP_OPEN 16
::constant OP_CALL 17
::constant OP_CLOSE 18
::constant OP_DISCONNECT 19

::constant OP_QOPEN 4096
::constant OP_QPUT 4097
::constant OP_QGET 4098
::constant OP_QDEPTH 4099
::constant OP_QCLOSE 4100

::constant OP_DBOPEN 4352
::constant OP_DBGET 4353
::constant OP_DBPUT 4354
::constant OP_DBDELETE 4355
::constant OP_DBSCAN 4356
::constant OP_DBCLOSE 4357

::constant OP_MAILINIT 5120
::constant OP_MAILBOX 5121
::constant OP_MAILLIST 5122
::constant OP_MAILOPEN 5123
::constant OP_MAILENV 5124
::constant OP_MAILHEAD 5125
::constant OP_MAILBODY 5126
::constant OP_MAILPART 5127
::constant OP_MAILNEXT 5128
::constant OP_MAILSEEN 5129
::constant OP_MAILCLOS 5130
::constant OP_MAILTERM 5131
::constant OP_MAILNEW 5152
::constant OP_MAILFROM 5153
::constant OP_MAILTO 5154
::constant OP_MAILTEXT 5155
::constant OP_MAILSIGN 5156
::constant OP_MAILSEND 5157
::constant OP_MAILSTAT 5158

/* pre9 allocates 1500-15FF to the previously-specified PATH personality. */
::constant OP_PATHOPEN 5376
::constant OP_PATHREAD 5377
::constant OP_PATHWRITE 5378
::constant OP_PATHAPPEND 5379
::constant OP_PATHCLOSE 5380
::constant OP_PATHSTAT 5381
::constant OP_PATHLIST 5382

::constant TYPE_NULL 0
::constant TYPE_BYTES 1
::constant TYPE_CHAR 2
::constant TYPE_UINT32 3
::constant TYPE_SINT32 4
::constant TYPE_UINT64 5
::constant TYPE_HANDLE 6
::constant TYPE_ARRAY 7
::constant TYPE_STRUCT 8

::method u16 class
  use strict arg n
  return d2c(n, 2)

::method u32 class
  use strict arg n
  return d2c(n, 4)

::method u64 class
  use strict arg n
  return d2c(n, 8)

::method readU16 class
  use strict arg bytes, offset
  return c2d(substr(bytes, offset, 2))

::method readU32 class
  use strict arg bytes, offset
  return c2d(substr(bytes, offset, 4))

::method readU64 class
  use strict arg bytes, offset
  return c2d(substr(bytes, offset, 8))

::method encodeFrame class
  use strict arg sessionId, requestId, objectHandle, operation, flags = 0, status = 0, reason = 0, payload = ''
  total = self~HEADER_LENGTH + payload~length
  if total > self~MAX_FRAME then raise syntax 88.900 array('MAS_FRAME_TOO_LARGE:' total)
  h = 'ALCH' || d2c(self~MAJOR,1) || d2c(self~MINOR,1) || self~u16(self~HEADER_LENGTH) || -
      self~u32(total) || self~u64(sessionId) || self~u64(requestId) || self~u32(objectHandle) || -
      self~u16(operation) || self~u16(flags) || self~u32(status) || self~u32(reason) || self~u32(payload~length)
  if h~length <> self~HEADER_LENGTH then raise syntax 88.900 array('MAS_HEADER_SIZE_INTERNAL:' h~length)
  return h || payload

::method decodeHeader class
  use strict arg h
  if h~length <> self~HEADER_LENGTH then raise syntax 88.900 array('MAS_HEADER_LENGTH:' h~length)
  if substr(h,1,4) <> 'ALCH' then raise syntax 88.900 array('MAS_BAD_EYE')
  if c2d(substr(h,5,1)) <> self~MAJOR then raise syntax 88.900 array('MAS_BAD_MAJOR')
  headerLen = self~readU16(h,7)
  if headerLen <> self~HEADER_LENGTH then raise syntax 88.900 array('MAS_BAD_HEADER_LENGTH:' headerLen)
  total = self~readU32(h,9)
  plen = self~readU32(h,45)
  if total <> headerLen + plen then raise syntax 88.900 array('MAS_LENGTH_RELATIONSHIP')
  if total > self~MAX_FRAME then raise syntax 88.900 array('MAS_FRAME_TOO_LARGE:' total)
  d = .directory~new
  d['total'] = total
  d['session_id'] = self~readU64(h,13)
  d['request_id'] = self~readU64(h,21)
  d['object_handle'] = self~readU32(h,29)
  d['operation'] = self~readU16(h,33)
  d['flags'] = self~readU16(h,35)
  d['status'] = self~readU32(h,37)
  d['reason'] = self~readU32(h,41)
  d['payload_length'] = plen
  return d

::method encodeValue class
  use strict arg type, tag = '', value = '', flags = 0
  tag = tag~string
  if tag~length > 255 then raise syntax 88.900 array('MAS_TAG_TOO_LONG')
  return d2c(type,1) || d2c(flags,1) || d2c(tag~length,1) || '00'x || self~u32(value~length) || tag || value

::method bytes class
  use strict arg tag, value
  return self~encodeValue(self~TYPE_BYTES, tag, value)

::method char class
  use strict arg tag, value, ccsid = 819
  return self~encodeValue(self~TYPE_CHAR, tag, self~u16(ccsid) || value)

::method uint32 class
  use strict arg tag, value
  return self~encodeValue(self~TYPE_UINT32, tag, self~u32(value))

::method uint64 class
  use strict arg tag, value
  return self~encodeValue(self~TYPE_UINT64, tag, self~u64(value))

::method handle class
  use strict arg tag, value
  return self~encodeValue(self~TYPE_HANDLE, tag, self~u32(value))

::method decodeValues class
  use strict arg payload
  out = .array~new
  p = 1
  do while p <= payload~length
    if p + 7 > payload~length then raise syntax 88.900 array('MAS_TYPED_PREFIX_TRUNCATED')
    type = c2d(substr(payload,p,1)); flags = c2d(substr(payload,p+1,1)); tagLen = c2d(substr(payload,p+2,1))
    if substr(payload,p+3,1) <> '00'x then raise syntax 88.900 array('MAS_TYPED_RESERVED_NONZERO')
    valueLen = self~readU32(payload,p+4)
    p += 8
    if p + tagLen + valueLen - 1 > payload~length then raise syntax 88.900 array('MAS_TYPED_VALUE_TRUNCATED')
    tag = substr(payload,p,tagLen); p += tagLen
    value = substr(payload,p,valueLen); p += valueLen
    out~append(.MasTypedValue~new(type, flags, tag, value))
  end
  return out

::method findValue class
  use strict arg values, tag
  do v over values
    if v~tag == tag then return v
  end
  return .nil

::class MasTypedValue public
::method init public
  expose type flags tag value
  use strict arg typeArg, flagsArg, tagArg, valueArg
  type=typeArg; flags=flagsArg; tag=tagArg; value=valueArg
::attribute type get
::attribute flags get
::attribute tag get
::attribute value get
::method asUint32 public
  expose type value
  if type <> .MasWire~TYPE_UINT32 & type <> .MasWire~TYPE_HANDLE then raise syntax 88.900 array('MAS_TYPED_NOT_U32:' type)
  if value~length <> 4 then raise syntax 88.900 array('MAS_TYPED_U32_SIZE')
  return c2d(value)
::method asUint64 public
  expose type value
  if type <> .MasWire~TYPE_UINT64 then raise syntax 88.900 array('MAS_TYPED_NOT_U64:' type)
  if value~length <> 8 then raise syntax 88.900 array('MAS_TYPED_U64_SIZE')
  return c2d(value)
::method asChar public
  expose type value
  if type <> .MasWire~TYPE_CHAR then raise syntax 88.900 array('MAS_TYPED_NOT_CHAR:' type)
  if value~length < 2 then raise syntax 88.900 array('MAS_TYPED_CHAR_TRUNCATED')
  return substr(value,3)
::method ccsid public
  expose type value
  if type <> .MasWire~TYPE_CHAR | value~length < 2 then return 0
  return c2d(substr(value,1,2))

::class MasSocketIO public
::method readExact class
  use strict arg socket, count
  out = ''
  do while out~length < count
    chunk = socket~recv(count - out~length)
    if chunk == .nil then raise syntax 88.900 array('MAS_SOCKET_RECV_ERROR:' socket~errno)
    if chunk == '' then return .nil
    out ||= chunk
  end
  return out

::method writeAll class
  use strict arg socket, data
  p = 1
  do while p <= data~length
    n = socket~send(substr(data,p))
    if n == .nil | n < 1 then raise syntax 88.900 array('MAS_SOCKET_SEND_ERROR:' socket~errno)
    p += n
  end
  return data~length

::requires 'socket.cls'
