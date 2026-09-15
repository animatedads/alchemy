/* ooRexx Work Bundle v0.1-dev1
 * Immutable, digest-bound work description for managed execution nodes.
 * A valid signature proves producer authority over bundle content; it is not
 * itself authority for a particular job to execute the bundle.
 */

::class WorkBundleBuild public
::constant VERSION "0.1-dev1"
::constant API "work.bundle/0.1"

::class WorkBundleCodec public
::method text class
  use strict arg value
  return value~string~c2x~lower
::method list class
  use arg values=.nil, upper=.false
  if values==.nil | values~items=0 then return ""
  a=.array~new
  do v over values
    s=v~string
    if upper then s=s~upper
    a~append(self~text(s))
  end
  a~sort
  out=""
  do i=1 to a~items
    if i>1 then out=out||"," 
    out=out||a[i]
  end
  return out

::class WorkBundlePath public
::method safeRelative class
  use strict arg value
  p=value~string
  if p="" then return .false
  if p~left(1)="/" | p~left(1)="\\" then return .false
  if p~pos("\\")>0 then return .false
  if p~pos("00"x)>0 then return .false
  rest=p
  do while rest<>""
    slash=rest~pos("/")
    if slash=0 then do; part=rest; rest=""; end
    else do; part=rest~left(slash-1); rest=rest~substr(slash+1); end
    if part="" | part="." | part=".." then return .false
  end
  return .true
::method join class
  use strict arg root, relative
  if \self~safeRelative(relative) then raise syntax 88.900 array("unsafe bundle-relative path: "||relative)
  r=root~string
  if r~right(1)="/" then return r||relative
  return r||"/"||relative

::class WorkBundleDigestProvider public
::method digestText abstract
::method digestFile abstract

::class WorkBundleCryptoSHA256Digest subclass WorkBundleDigestProvider public
::method digestText
  use strict arg text
  return .SHA256~new(text~string)~digest
::method digestFile
  use strict arg path
  if stream(path,"C","QUERY EXISTS")="" then return ""
  s=.stream~new(path); s~open("READ")
  bytes=s~chars
  data=""
  if bytes>0 then data=s~charin(,bytes)
  s~close
  return .SHA256~new(data)~digest

::class WorkBundleProofAuthority public
::method sign abstract
::method verify abstract

/* Ed25519 producer proof. Private seeds are supplied by deployment and are not
 * embedded in the WorkBundle. publicKeys is indexed by PRODUCER|KEYID. */
::class WorkBundleEd25519ProofAuthority subclass WorkBundleProofAuthority public
::method init
  expose privateKeys publicKeys
  use arg privateArg=.nil, publicArg=.nil
  if privateArg==.nil then privateKeys=.directory~new; else privateKeys=privateArg
  if publicArg==.nil then publicKeys=.directory~new; else publicKeys=publicArg
::method key private
  use strict arg producerId,keyId
  return producerId~string~upper||"|"||keyId~string~upper
::method sign
  expose privateKeys
  use strict arg producerId,keyId,canonical
  k=self~key(producerId,keyId)
  if \privateKeys~hasIndex(k) then return ""
  return .Ed25519~sign(canonical~string,privateKeys[k])
::method verify
  expose publicKeys
  use strict arg producerId,keyId,canonical,signature
  k=self~key(producerId,keyId)
  if \publicKeys~hasIndex(k) then return .false
  if signature~string~length<>128 then return .false
  return .Ed25519~verify(canonical~string,signature~string,publicKeys[k])

::class WorkBundleFile public
::attribute relativePath get
::attribute sourcePath get
::attribute sha256 get
::attribute executable get
::method init
  expose relativePath sourcePath sha256 executable
  use strict arg relativeArg, sourceArg, digestArg, executableArg=.false
  relativePath=relativeArg~string
  sourcePath=sourceArg~string
  sha256=digestArg~string~lower
  executable=(executableArg==.true)
  if \ .WorkBundlePath~safeRelative(relativePath) then raise syntax 88.900 array("unsafe bundle file path: "||relativePath)
  if sourcePath="" then raise syntax 88.900 array("sourcePath must not be empty")
  if sha256~length<>64 then raise syntax 88.900 array("bundle file SHA-256 must be 64 hex characters")
::method canonical
  expose relativePath sha256 executable
  return "path="||.WorkBundleCodec~text(relativePath)||";sha256="||sha256||";exec="||executable

::class WorkBundleManifest public
::attribute bundleId get
::attribute producerId get
::attribute keyId get
::attribute sourceRef get
::attribute createdEpochMs get
::attribute expiresEpochMs get
::attribute files get
::attribute entrypoints get
::attribute permittedKinds get
::attribute requiredRuntimes get
::method init
  expose bundleId producerId keyId sourceRef createdEpochMs expiresEpochMs files entrypoints permittedKinds requiredRuntimes
  use strict arg bundleArg,producerArg,keyArg,sourceArg="",createdArg=0,expiresArg=0,filesArg=.nil,entryArg=.nil,kindsArg=.nil,runtimesArg=.nil
  bundleId=bundleArg~string; producerId=producerArg~string; keyId=keyArg~string; sourceRef=sourceArg~string
  createdEpochMs=createdArg+0; expiresEpochMs=expiresArg+0
  if filesArg==.nil then files=.array~new; else files=filesArg
  if entryArg==.nil then entrypoints=.array~new; else entrypoints=entryArg
  if kindsArg==.nil then permittedKinds=.array~new; else permittedKinds=kindsArg
  if runtimesArg==.nil then requiredRuntimes=.array~new; else requiredRuntimes=runtimesArg
  if bundleId="" | producerId="" | keyId="" then raise syntax 88.900 array("bundleId, producerId and keyId are mandatory")
  do e over entrypoints
    if \ .WorkBundlePath~safeRelative(e) then raise syntax 88.900 array("unsafe bundle entrypoint: "||e)
  end
::method hasEntrypoint
  expose entrypoints
  use strict arg value
  do e over entrypoints
    if e~string=value~string then return .true
  end
  return .false
::method permitsKind
  expose permittedKinds
  use strict arg value
  wanted=value~string~upper
  do k over permittedKinds
    if k~string~upper=wanted then return .true
  end
  return .false
::method requiresRuntime
  expose requiredRuntimes
  use strict arg value
  wanted=value~string~upper
  do r over requiredRuntimes
    if r~string~upper=wanted then return .true
  end
  return .false
::method canonical
  expose bundleId producerId keyId sourceRef createdEpochMs expiresEpochMs files entrypoints permittedKinds requiredRuntimes
  rows=.array~new
  do f over files; rows~append(f~canonical); end
  rows~sort
  fileText=""
  do i=1 to rows~items
    if i>1 then fileText=fileText||"|"
    fileText=fileText||.WorkBundleCodec~text(rows[i])
  end
  return "bundle="||.WorkBundleCodec~text(bundleId)||";producer="||.WorkBundleCodec~text(producerId)||";key="||.WorkBundleCodec~text(keyId)||";source="||.WorkBundleCodec~text(sourceRef)||";created="||createdEpochMs||";expires="||expiresEpochMs||";entry="||.WorkBundleCodec~list(entrypoints)||";kinds="||.WorkBundleCodec~list(permittedKinds,.true)||";runtimes="||.WorkBundleCodec~list(requiredRuntimes,.true)||";files="||fileText

::class WorkBundle public
::attribute manifest get
::attribute digest get
::attribute signature get
::method init
  expose manifest digest signature
  use strict arg manifestArg,digestArg,signatureArg
  manifest=manifestArg; digest=digestArg~string~lower; signature=signatureArg~string
  if manifest==.nil then raise syntax 88.900 array("manifest is mandatory")
  if digest~length<>64 then raise syntax 88.900 array("bundle digest must be SHA-256")
::method reference
  expose manifest digest signature
  return .WorkBundleRef~new(manifest~bundleId,digest,manifest~producerId,manifest~keyId,signature)

::class WorkBundleRef public
::attribute bundleId get
::attribute digest get
::attribute producerId get
::attribute keyId get
::attribute signature get
::attribute retrievalRef get
::method init
  expose bundleId digest producerId keyId signature retrievalRef
  use strict arg bundleArg,digestArg,producerArg,keyArg,signatureArg="",retrievalArg=""
  bundleId=bundleArg~string; digest=digestArg~string~lower; producerId=producerArg~string; keyId=keyArg~string; signature=signatureArg~string; retrievalRef=retrievalArg~string
::method canonical
  expose bundleId digest producerId keyId retrievalRef
  return "bundle="||.WorkBundleCodec~text(bundleId)||";digest="||digest||";producer="||.WorkBundleCodec~text(producerId)||";key="||.WorkBundleCodec~text(keyId)||";retrieval="||.WorkBundleCodec~text(retrievalRef)
::method queuePersistentType
  return "work.bundle.ref/0.1"
::method queuePersistentState
  expose bundleId digest producerId keyId signature retrievalRef
  t=.table~new; t["bundleId"]=bundleId; t["digest"]=digest; t["producerId"]=producerId; t["keyId"]=keyId; t["signature"]=signature; t["retrievalRef"]=retrievalRef; return t
::method queueRestoreState
  expose bundleId digest producerId keyId signature retrievalRef
  use strict arg state
  bundleId=state["bundleId"]~string; digest=state["digest"]~string; producerId=state["producerId"]~string; keyId=state["keyId"]~string; signature=state["signature"]~string; retrievalRef=state["retrievalRef"]~string; return self

::class WorkBundleRefFactory public
::method newBlank
  return .WorkBundleRef~new("","","","","","")

::class WorkBundleQueueTypes public
::method register class
  use strict arg payloadCodec
  if payloadCodec==.nil | \payloadCodec~hasMethod("TYPEREGISTRY") then return .false
  return payloadCodec~typeRegistry~register("work.bundle.ref/0.1",.WorkBundleRefFactory~new)

::class WorkBundleVerificationResult public
::attribute ok get
::attribute code get
::attribute detail get
::method init
  expose ok code detail
  use strict arg okArg,codeArg,detailArg=""
  ok=(okArg==.true); code=codeArg~string; detail=detailArg~string
::method success class
  return self~new(.true,"OK")
::method failure class
  use arg code,detail=""
  return self~new(.false,code,detail)

::class WorkBundleVerifier public
::method init
  expose digestProvider proofAuthority
  use strict arg digestArg,proofArg
  if digestArg==.nil | proofArg==.nil then raise syntax 88.900 array("digest provider and proof authority are mandatory")
  digestProvider=digestArg; proofAuthority=proofArg
::method verify
  expose digestProvider proofAuthority
  use strict arg bundle,nowEpochMs=0
  if bundle==.nil then return .WorkBundleVerificationResult~failure("BUNDLE_MISSING")
  m=bundle~manifest
  if m~expiresEpochMs>0 & nowEpochMs+0>=m~expiresEpochMs then return .WorkBundleVerificationResult~failure("BUNDLE_EXPIRED")
  canonical=m~canonical
  expected=digestProvider~digestText(canonical)
  if expected<>bundle~digest then return .WorkBundleVerificationResult~failure("BUNDLE_DIGEST_MISMATCH")
  if \proofAuthority~verify(m~producerId,m~keyId,canonical,bundle~signature) then return .WorkBundleVerificationResult~failure("BUNDLE_PROOF_INVALID")
  do f over m~files
    if stream(f~sourcePath,"C","QUERY EXISTS")="" then return .WorkBundleVerificationResult~failure("BUNDLE_FILE_MISSING",f~relativePath)
    got=digestProvider~digestFile(f~sourcePath)
    if got<>f~sha256 then return .WorkBundleVerificationResult~failure("BUNDLE_FILE_DIGEST_MISMATCH",f~relativePath)
  end
  return .WorkBundleVerificationResult~success

::class WorkBundleBuilder public
::method init
  expose digestProvider proofAuthority
  use strict arg digestArg,proofArg
  digestProvider=digestArg; proofAuthority=proofArg
::method seal
  expose digestProvider proofAuthority
  use strict arg rootDir,bundleId,producerId,keyId,relativeFiles,entrypoints,permittedKinds,requiredRuntimes,sourceRef="",createdEpochMs=0,expiresEpochMs=0,executableFiles=.nil
  files=.array~new
  do rel over relativeFiles
    if \ .WorkBundlePath~safeRelative(rel) then raise syntax 88.900 array("unsafe bundle file path: "||rel)
    path=.WorkBundlePath~join(rootDir,rel)
    if stream(path,"C","QUERY EXISTS")="" then raise syntax 88.900 array("bundle file not found: "||path)
    exec=.false
    if executableFiles<>.nil then do x over executableFiles
      if x~string=rel~string then do; exec=.true; leave; end
    end
    files~append(.WorkBundleFile~new(rel,path,digestProvider~digestFile(path),exec))
  end
  m=.WorkBundleManifest~new(bundleId,producerId,keyId,sourceRef,createdEpochMs,expiresEpochMs,files,entrypoints,permittedKinds,requiredRuntimes)
  canonical=m~canonical
  digest=digestProvider~digestText(canonical)
  signature=proofAuthority~sign(producerId,keyId,canonical)
  if signature="" then raise syntax 88.900 array("work bundle proof authority refused to sign")
  return .WorkBundle~new(m,digest,signature)

::class WorkBundleRepository public
::method fetch abstract

::class InMemoryWorkBundleRepository subclass WorkBundleRepository public
::method init
  expose bundles
  bundles=.directory~new
::method put
  expose bundles
  use strict arg bundle
  bundles[bundle~digest]=bundle
  return bundle~reference
::method fetch
  expose bundles
  use strict arg reference
  if reference==.nil then return .nil
  if \bundles~hasIndex(reference~digest) then return .nil
  b=bundles[reference~digest]
  if b~manifest~bundleId<>reference~bundleId then return .nil
  return b

::requires "crypto.cls"
