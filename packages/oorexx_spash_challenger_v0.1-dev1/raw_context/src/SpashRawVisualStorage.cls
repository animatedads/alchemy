/* Storage Fabric production catalogue seam; registration is not persistence.
 * Load genuine StorageFabric.cls in production, not the unit-test stub.
 */
::class SpashRawVisualStorage public
::method registerView
  use strict arg catalogue,originRef,viewRef,bytes,methodId
  if catalogue==.nil | originRef==.nil | viewRef==.nil then raise syntax 88.900 array('Storage Fabric references mandatory')
  if \catalogue~hasMethod('get') | \catalogue~hasMethod('put') then raise syntax 88.900 array('real StorageCatalogue API required')
  if \originRef~hasMethod('objectId') | \originRef~hasMethod('digest') | \viewRef~hasMethod('objectId') | \viewRef~hasMethod('digest') then raise syntax 88.900 array('StorageRef contract required')
  if length(originRef~digest)<>64 | length(viewRef~digest)<>64 then raise syntax 88.900 array('SHA-256 lineage required')
  if originRef~objectId==viewRef~objectId then raise syntax 88.900 array('original may not be overwritten')
  if \datatype(bytes,'W') | bytes<0 then raise syntax 88.900 array('view bytes must be a nonnegative integer')
  if methodId=='' then raise syntax 88.900 array('analysis method required')
  if catalogue~get(originRef~objectId)==.nil then raise syntax 88.900 array('original not in catalogue')
  if catalogue~get(viewRef~objectId)\==.nil then raise syntax 88.900 array('immutable PTS view already registered')
  o=.StorageObject~new(viewRef,'SPASH raw visual PTS window evidence',bytes,'text/tab-separated-values')
  o~eas~put(.StorageEA~new('spash','role','VISUAL_PTS_WINDOW','STRING','SPASH','DERIVED_OBSERVATION'))
  o~eas~put(.StorageEA~new('spash','origin_ref',originRef~objectId,'STRING','SPASH','SOURCE_LINEAGE'))
  o~eas~put(.StorageEA~new('spash','clock','SOURCE_VIDEO_PTS_TIMEBASE_AUDIO_UNALIGNED','STRING','SPASH','SOURCE_TIME_AUTHORITY'))
  o~eas~put(.StorageEA~new('spash','method',methodId,'STRING','SPASH','DERIVATION'))
  o~eas~put(.StorageEA~new('spash','persistence','CATALOGUE_ONLY_NOT_DURABLE','STRING','SPASH','NO_COMMIT_PROOF'))
  catalogue~put(o)
  return o
::requires 'StorageFabric.cls'