/* ooRexx Atomic File v0.1-dev1 -- publication options */
::class AtomicFileOptions public
::method init
  self~durability = 'FULL'
  self~noFollow = .true
  self~preserveMode = .true
  self~mode = 384              /* 0600 when creating a new target */
  self~expectedGeneration = .nil
  self~backupPolicy = 'NONE'

::attribute durability
::attribute noFollow
::attribute preserveMode
::attribute mode
::attribute expectedGeneration
::attribute backupPolicy
