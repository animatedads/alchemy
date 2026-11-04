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

::requires 'MediaReferenceVideoProviders.cls'
::requires 'python_foreign.cls'
