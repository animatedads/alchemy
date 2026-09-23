/* ooRexx Atomic File v0.1-dev1 -- same-directory native publication provider */
::class AtomicNativeProvider public
::method name
  return 'rxatomicnative'

::method capabilities
  return .array~of('atomic.replace.bytes', 'atomic.same-filesystem-stage', 'atomic.no-follow-target', -
                   'atomic.mode.preserve', 'atomic.sync.file', 'atomic.sync.parent')

::method unsupported private
  use strict arg options, stage, message
  return .AtomicFileResult~new(.false, .false, translate(options~durability), .false, .false, .false, -
                               0, 0, .false, self~name, 0, message, stage)

::method replace
  use strict arg path, bytes, options
  if translate(options~backupPolicy) \== 'NONE' then -
    return self~unsupported(options, 'BACKUP_POLICY', 'Backup publication policy is not implemented by the dev1 provider')
  if options~expectedGeneration \== .nil then -
    return self~unsupported(options, 'EXPECTED_GENERATION', 'Race-free generation compare-and-swap is not implemented by the dev1 provider')

  o = .directory~new
  o['DURABILITY'] = translate(options~durability)
  o['NO_FOLLOW'] = options~noFollow
  o['PRESERVE_MODE'] = options~preserveMode
  o['MODE'] = options~mode

  d = AtomicNativeReplace(path, bytes, o)
  if \d['OK'] then do
    published = .false
    if d~hasIndex('PUBLISHED') then published = d['PUBLISHED']
    return .AtomicFileResult~new(.false, published, translate(options~durability), .false, .false, .false, -
                                 0, 0, .false, self~name, d['ERRNO'], d['ERROR_MESSAGE'], d['STAGE'])
  end
  return .AtomicFileResult~new(.true, d['PUBLISHED'], d['DURABILITY'], d['DURABILITY_ACHIEVED'], -
                               d['FILE_SYNCED'], d['PARENT_SYNCED'], d['BYTES'], d['MODE'], -
                               d['REPLACED_EXISTING'], self~name)

::requires 'AtomicFileOptions.cls'
::requires 'AtomicFileResult.cls'
::requires 'rxatomicnative' LIBRARY
