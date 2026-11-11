/* Embedded reference-video provider invocation through Alchemy Foreign Runtime.
 *
 * This is the ONLY ooRexx execution seam for the Python/OpenCV reference
 * provider.  Foreign Runtime loads Python in-process, retains object identity,
 * acquires the GIL around calls, and preserves ooRexx's execution authority.
 *
 * No interpreter command line, shell escape, Popen, socket, REST, or files-as-
 * subprocess-protocol.  Job/result file references are the existing Media
 * Methodologies provider material contract and remain in PRIVATE storage.
 * Never commit those job/result materials or any derived image to Git.
 */
::class MediaForeignVideoInvoker public
::method init
  expose providerRoot registry
  use strict arg providerRootArg
  if providerRootArg=.nil then raise syntax 93.900 array('PROVIDER_ROOT_REQUIRED')
  providerRoot=strip(providerRootArg)
  if providerRoot='' then raise syntax 93.900 array('PROVIDER_ROOT_REQUIRED')
  registry=.MediaReferenceVideoProviderRegistry~new(providerRoot)

::method run
  expose providerRoot registry
  use strict arg methodologyIdArg, jobPathArg, resultPathArg
  methodologyId=translate(strip(methodologyIdArg))
  if \registry~supports(methodologyId) then raise syntax 93.900 array('UNREGISTERED_VIDEO_METHODOLOGY',methodologyId)
  if jobPathArg=.nil | resultPathArg=.nil then raise syntax 93.900 array('PRIVATE_MATERIAL_PATH_REQUIRED')
  jobPath=strip(jobPathArg)
  resultPath=strip(resultPathArg)
  if jobPath='' | resultPath='' then raise syntax 93.900 array('PRIVATE_MATERIAL_PATH_REQUIRED')

  /* The privacy boundary belongs to ooRexx, not just one reference provider.
   * Fail BEFORE loading any replaceable Python implementation. */
  self~preflightPaths(jobPath,resultPath,methodologyId)

  /* Use the real interpreter's resident import bridge, not a Python process.
   * Resolve the exact provider file inside its trusted installed directory.
   * No arbitrary module search path or caller-supplied Python source strings. */
  paths=.ForeignPython~import('os.path')
  root=paths~realpath(providerRoot)
  script=paths~realpath(root||'/reference_video_reconstruction.py')
  if left(script,length(root)+1)<>root||'/' then raise syntax 93.900 array('PROVIDER_PATH_ESCAPES_ROOT')
  if paths~isfile(script)=0 then raise syntax 93.900 array('REFERENCE_PROVIDER_MISSING')

  util=.ForeignPython~import('importlib.util')
  spec=util~spec_from_file_location('alchemy_video_reconstruction_reference',script)
  if spec=.nil then raise syntax 93.900 array('REFERENCE_PROVIDER_SPEC_FAILED')
  loader=spec~get('loader')
  if loader=.nil then raise syntax 93.900 array('REFERENCE_PROVIDER_LOADER_MISSING')
  provider=util~module_from_spec(spec)
  unused=loader~exec_module(provider)

  /* This method is implemented by the provider itself.  It consumes the
   * existing provider-job JSON and writes the private provider-result JSON.
   * We pass method ID twice (registry and provider) to reject a job mismatch. */
  providerRc=provider~run_job_file(jobPath,resultPath,methodologyId)
  provider~close
  loader~close
  spec~close
  util~close
  paths~close
  if \datatype(providerRc,'W') then raise syntax 93.900 array('INVALID_FOREIGN_PROVIDER_RETURN')
  return providerRc


/* Check job + output + source paths in ooRexx before foreign implementation.
 * Provider-side repetition is defence in depth, not the principal authority.
 * All paths are canonicalised through the resident Foreign Runtime os.path.
 * Paths cannot equal the root of the filesystem or resolve into a Git tree.
 */
::method preflightPaths
  use strict arg jobPath,resultPath,expectedMethodologyId=''
  env=.ForeignPython~import('os')
  environ=env~get('environ')
  privateRoot=environ~get('ALCHEMY_PRIVATE_MEDIA_ROOT','')
  if privateRoot=.nil then privateRoot=''
  privateRoot=strip(privateRoot)
  if privateRoot='' then raise syntax 93.900 array('PRIVATE_MEDIA_ROOT_REQUIRED')
  paths=.ForeignPython~import('os.path')
  if \paths~isabs(privateRoot) then raise syntax 93.900 array('PRIVATE_MEDIA_ROOT_NOT_ABSOLUTE')
  root=paths~realpath(privateRoot)
  if root='/' then raise syntax 93.900 array('PRIVATE_MEDIA_ROOT_UNSAFE')
  if \paths~isdir(root) then raise syntax 93.900 array('PRIVATE_MEDIA_ROOT_MISSING')
  /* Validate caller paths before reading the job JSON. */
  self~checkPrivatePath(paths,root,jobPath)
  self~checkPrivatePath(paths,root,resultPath)
  job=.json~fromJsonFile(jobPath)
  if job=.nil then raise syntax 93.900 array('PRIVATE_JOB_UNREADABLE')
  if \job~isA(.Directory) then raise syntax 93.900 array('PRIVATE_JOB_INVALID')
  if job['schema']<>'media-methodology.provider-job/0.1' then raise syntax 93.900 array('PRIVATE_JOB_SCHEMA_INVALID')
  if expectedMethodologyId<>'' then do
    if job['methodology_id']=.nil then raise syntax 93.900 array('METHODOLOGY_MISSING')
    if translate(strip(job['methodology_id']))<>translate(strip(expectedMethodologyId)) then raise syntax 93.900 array('METHODOLOGY_MISMATCH')
  end
  outDir=job['output_dir']
  if outDir=.nil then raise syntax 93.900 array('PRIVATE_OUTPUT_DIR_REQUIRED')
  self~checkPrivatePath(paths,root,outDir)
  /* Output filenames are provider-controlled ONLY after this name gate. */
  candidateId=job['candidate_id']
  if candidateId<>.nil then do
    allowed='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-'
    if length(candidateId)<1 | length(candidateId)>96 then raise syntax 93.900 array('UNSAFE_CANDIDATE_ID')
    if verify(candidateId,allowed)<>0 then raise syntax 93.900 array('UNSAFE_CANDIDATE_ID')
    if verify(left(candidateId,1),'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789')<>0 then raise syntax 93.900 array('UNSAFE_CANDIDATE_ID')
    if pos('..',candidateId)>0 then raise syntax 93.900 array('UNSAFE_CANDIDATE_ID')
  end
  source=job['source']
  if source=.nil then raise syntax 93.900 array('PRIVATE_SOURCE_REQUIRED')
  if \source~isA(.Directory) then raise syntax 93.900 array('PRIVATE_SOURCE_INVALID')
  kind=source['kind']
  if kind='VIDEO_FILE' then do
    sourcePath=source['path']
    if sourcePath=.nil then raise syntax 93.900 array('PRIVATE_SOURCE_PATH_REQUIRED')
    self~checkPrivatePath(paths,root,sourcePath)
  end
  else do
    if kind<>'SYNTHETIC_ONLY' then raise syntax 93.900 array('PRIVATE_SOURCE_KIND_UNSUPPORTED')
    /* A synthetic-only test job must never smuggle a source file path. */
    if source~hasIndex('path') then raise syntax 93.900 array('PRIVATE_SOURCE_PATH_UNEXPECTED')
  end
  paths~close
  environ~close
  env~close
  return 'ADMITTED'

::method checkPrivatePath private
  use strict arg paths,root,path
  if path=.nil then raise syntax 93.900 array('PRIVATE_MATERIAL_PATH_REQUIRED')
  if \paths~isabs(path) then raise syntax 93.900 array('PRIVATE_MATERIAL_PATH_NOT_ABSOLUTE')
  actual=paths~realpath(path)
  if actual<>root then do
    if left(actual,length(root)+1)<>root||'/' then raise syntax 93.900 array('PRIVATE_MATERIAL_OUTSIDE_ROOT')
  end
  cursor=actual
  if \paths~isdir(cursor) then cursor=paths~dirname(cursor)
  do forever
    if paths~exists(paths~join(cursor,'.git')) then raise syntax 93.900 array('GIT_WORKTREE_MEDIA_FORBIDDEN')
    parent=paths~dirname(cursor)
    if parent=cursor then leave
    cursor=parent
  end
  return actual

::requires 'MediaReferenceVideoProviders.cls'
::requires 'json.cls'
::requires 'python_foreign.cls'
