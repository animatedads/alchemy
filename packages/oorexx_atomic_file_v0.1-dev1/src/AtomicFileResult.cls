/* ooRexx Atomic File v0.1-dev1 -- publication result/evidence */
::class AtomicFileResult public
::method init
  expose ok published durabilityRequested durabilityAchieved fileSynced parentSynced bytes mode replacedExisting provider errorCode errorMessage errorStage
  use strict arg ok, published = .false, durabilityRequested = 'NONE', durabilityAchieved = .false, -
                 fileSynced = .false, parentSynced = .false, bytes = 0, mode = 0, replacedExisting = .false, -
                 provider = '', errorCode = 0, errorMessage = '', errorStage = ''

::attribute ok get
::attribute published get
::attribute durabilityRequested get
::attribute durabilityAchieved get
::attribute fileSynced get
::attribute parentSynced get
::attribute bytes get
::attribute mode get
::attribute replacedExisting get
::attribute provider get
::attribute errorCode get
::attribute errorMessage get
::attribute errorStage get

::method requirePublished
  expose published errorMessage errorStage
  if \published then raise syntax 88.900 array(errorStage || ': ' || errorMessage)
  return self
