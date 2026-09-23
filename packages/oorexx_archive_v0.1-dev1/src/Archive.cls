/*----------------------------------------------------------------------------*/
/* ooRexx Archive facade.                                                     */
/*----------------------------------------------------------------------------*/
::class ArchiveBuild public
::constant VERSION '0.1-dev1'
::constant API 'oorexx.archive/0.1'

::class Archive public
::method openZip class
  use strict arg path
  return .ZipArchive~fromFile(path)

::method parseZip class
  use strict arg bytes
  return .ZipArchive~fromBytes(bytes)

::method zipWriter class
  return .ZipWriter~new

::requires 'ZipBinary.cls'
::requires 'ZipEntry.cls'
::requires 'ZipPathPolicy.cls'
::requires 'ZipArchive.cls'
::requires 'ZipWriter.cls'
