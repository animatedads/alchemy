/*----------------------------------------------------------------------------*/
/* Immutable-enough ZIP central-directory entry model.                        */
/*----------------------------------------------------------------------------*/
::class ZipEntry public

::method init
  expose name method flags crc32Bytes compressedSize uncompressedSize localOffset -
         versionMadeBy versionNeeded externalAttributes internalAttributes -
         diskStart isDirectory unixMode localDataStart localDataEnd
  use strict arg name, method, flags, crc32Bytes, compressedSize, uncompressedSize, -
                 localOffset, versionMadeBy, versionNeeded, externalAttributes, -
                 internalAttributes, diskStart, isDirectory, unixMode = .nil
  localDataStart = .nil
  localDataEnd = .nil

::attribute name get
::attribute method get
::attribute flags get
::attribute crc32Bytes get
::attribute compressedSize get
::attribute uncompressedSize get
::attribute localOffset get
::attribute versionMadeBy get
::attribute versionNeeded get
::attribute externalAttributes get
::attribute internalAttributes get
::attribute diskStart get
::attribute isDirectory get
::attribute unixMode get
::attribute localDataStart get
::attribute localDataStart set
::attribute localDataEnd get
::attribute localDataEnd set

::method hostSystem
  expose versionMadeBy
  return versionMadeBy % 256

::method encrypted
  expose flags
  return self~flagSet(flags, 1) | self~flagSet(flags, 64) | self~flagSet(flags, 8192)

::method hasDataDescriptor
  expose flags
  return self~flagSet(flags, 8)

::method utf8Name
  expose flags
  return self~flagSet(flags, 2048)

::method flagSet private
  use strict arg value, mask
  return (value // (mask * 2)) >= mask
