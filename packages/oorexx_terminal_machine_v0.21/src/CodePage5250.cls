/*
 * 5250 character conversion boundary v0.1.
 *
 * CP037 is represented as an exact reversible ISO-8859-1 <-> IBM037 byte
 * table.  The terminal core remains encoding-neutral; other CCSIDs can be
 * registered later without changing the datastream machine.
 */

::class CodePage5250 public
::attribute name get

::method init
  expose name
  use arg nameArg
  name = nameArg~string~strip~upper

::method decode
  raise syntax 93.914 array("CodePage5250 decode() must be implemented by a concrete code page")

::method encode
  raise syntax 93.914 array("CodePage5250 encode() must be implemented by a concrete code page")

::class CodePage037 subclass CodePage5250 public
::method init
  self~init:super("IBM037")

::method localMap private
  return -
    "000102039C09867F978D8E0B0C0D0E0F101112139D8508871819928F1C1D1E1F"x || -
    "80818283840A171B88898A8B8C050607909116939495960498999A9B14159E1A"x || -
    "20A0E2E4E0E1E3E5E7F1A22E3C282B7C26E9EAEBE8EDEEEFECDF21242A293BAC"x || -
    "2D2FC2C4C0C1C3C5C7D1A62C255F3E3FF8C9CACBC8CDCECFCC603A2340273D22"x || -
    "D8616263646566676869ABBBF0FDFEB1B06A6B6C6D6E6F707172AABAE6B8C6A4"x || -
    "B57E737475767778797AA1BFD0DDDEAE5EA3A5B7A9A7B6BCBDBE5B5DAFA8B4D7"x || -
    "7B414243444546474849ADF4F6F2F3F57D4A4B4C4D4E4F505152B9FBFCF9FAFF"x || -
    "5CF7535455565758595AB2D4D6D2D3D530313233343536373839B3DBDCD9DA9F"x

::method remoteMap private
  return -
    "00010203372D2E2F1605250B0C0D0E0F101112133C3D322618193F271C1D1E1F"x || -
    "405A7F7B5B6C507D4D5D5C4E6B604B61F0F1F2F3F4F5F6F7F8F97A5E4C7E6E6F"x || -
    "7CC1C2C3C4C5C6C7C8C9D1D2D3D4D5D6D7D8D9E2E3E4E5E6E7E8E9BAE0BBB06D"x || -
    "79818283848586878889919293949596979899A2A3A4A5A6A7A8A9C04FD0A107"x || -
    "202122232415061728292A2B2C090A1B30311A333435360838393A3B04143EFF"x || -
    "41AA4AB19FB26AB5BDB49A8A5FCAAFBC908FEAFABEA0B6B39DDA9B8BB7B8B9AB"x || -
    "6465626663679E687471727378757677AC69EDEEEBEFECBF80FDFEFBFCADAE59"x || -
    "4445424643479C4854515253585556578C49CDCECBCFCCE170DDDEDBDC8D8EDF"x

::method decode
  use arg bytes
  map = self~localMap
  textOut = ""
  do i = 1 to bytes~length
    b = x2d(bytes~substr(i, 1)~c2x)
    /* The 5250 display convention treats NUL as a visible blank. */
    if b == 0 then textOut ||= " "
    else if b == 28 then textOut ||= "*" /* DUP glyph fallback */
    else textOut ||= map~substr(b + 1, 1)
  end
  return textOut

::method decodeDisplayByte
  use arg byteArg
  if byteArg~length == 0 then return ""
  b = x2d(byteArg~substr(1,1)~c2x)
  if self~isAttributeByte(byteArg) then return " "
  return self~decode(byteArg~substr(1,1))

::method encode
  use arg textArg
  text = textArg~string
  map = self~remoteMap
  bytesOut = ""
  do i = 1 to text~length
    localByte = x2d(text~substr(i, 1)~c2x)
    bytesOut ||= map~substr(localByte + 1, 1)
  end
  return bytesOut

::method isAttributeByte
  use arg byteArg
  if byteArg~length == 0 then return .false
  n = x2d(byteArg~substr(1,1)~c2x)
  return n >= 32 & n <= 63

::class CodePage5250Registry public
::method forName class
  use arg nameArg = "37"
  name = nameArg~string~strip~upper
  if name == "37" | name == "037" | name == "IBM037" | name == "CP037" then return .CodePage037~new
  return .nil
