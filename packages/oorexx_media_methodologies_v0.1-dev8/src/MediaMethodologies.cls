/* Media Methodologies core contract.
 *
 * API: media.methodologies/0.1
 *
 * This package is deliberately a catalogue/planning contract, not a single
 * processing implementation.  Multiple methodologies and providers may coexist.
 */

::class MediaMethodologySpec public
::method init
  expose id name domain family maturity authorityEffect experimental reconstructive principle
  use arg idArg, nameArg, domainArg, familyArg, maturityArg = "ESTABLISHED", authorityArg = "MEASURE", experimentalArg = .false, reconstructiveArg = .false, principleArg = ""
  id = translate(strip(idArg))
  name = strip(nameArg)
  domain = translate(strip(domainArg))
  family = translate(strip(familyArg))
  maturity = translate(strip(maturityArg))
  authorityEffect = translate(strip(authorityArg))
  experimental = experimentalArg
  reconstructive = reconstructiveArg
  principle = principleArg
  if id == "" then raise syntax 93.900 array("Methodology id must not be empty")
  if name == "" then raise syntax 93.900 array("Methodology name must not be empty")
  if domain == "" then raise syntax 93.900 array("Methodology domain must not be empty")
  if family == "" then raise syntax 93.900 array("Methodology family must not be empty")

::method id
  expose id
  return id
::method name
  expose name
  return name
::method domain
  expose domain
  return domain
::method family
  expose family
  return family
::method maturity
  expose maturity
  return maturity
::method authorityEffect
  expose authorityEffect
  return authorityEffect
::method experimental
  expose experimental
  return experimental
::method reconstructive
  expose reconstructive
  return reconstructive
::method principle
  expose principle
  return principle

::class MediaMethodologyProvider public
::method methodologies abstract

::class MediaMethodologyPolicy public
::method init
  expose allowExperimental allowReconstruction allowedDomains
  use arg allowExperimentalArg = .true, allowReconstructionArg = .true
  allowExperimental = allowExperimentalArg
  allowReconstruction = allowReconstructionArg
  allowedDomains = .Directory~new

::method allowDomain
  expose allowedDomains
  use arg domainArg
  key = translate(strip(domainArg))
  if key \== "" then allowedDomains~put(.true, key)
  return self

::method accepts
  expose allowExperimental allowReconstruction allowedDomains
  use arg spec
  if spec == .nil then return .false
  if \allowExperimental then do
    if spec~experimental then return .false
  end
  if \allowReconstruction then do
    if spec~reconstructive then return .false
  end
  if allowedDomains~items > 0 then do
    if allowedDomains~hasIndex(spec~domain) = 0 then return .false
  end
  return .true

::class MediaMethodologyCatalogue public
::method init
  expose specs providers
  specs = .Directory~new
  providers = .Array~new

::method register
  expose specs
  use arg spec
  if spec == .nil then raise syntax 93.900 array("Methodology spec must not be NIL")
  if \spec~isA(.MediaMethodologySpec) then raise syntax 93.900 array("Methodology must be a MediaMethodologySpec")
  specs~put(spec, spec~id)
  return spec

::method methodology
  expose specs
  use arg idArg
  key = translate(strip(idArg))
  if specs~hasIndex(key) = 0 then return .nil
  return specs~at(key)

::method count
  expose specs
  return specs~items

::method all
  expose specs
  items = .Array~new
  supplier = specs~supplier
  do while supplier~available
    items~append(supplier~item)
    supplier~next
  end
  return items

::method byDomain
  use arg domainArg
  wanted = translate(strip(domainArg))
  matches = .Array~new
  allItems = self~all
  do i = 1 to allItems~items
    spec = allItems~at(i)
    if spec~domain == wanted then matches~append(spec)
  end
  return matches

::method byFamily
  use arg familyArg
  wanted = translate(strip(familyArg))
  matches = .Array~new
  allItems = self~all
  do i = 1 to allItems~items
    spec = allItems~at(i)
    if spec~family == wanted then matches~append(spec)
  end
  return matches

::method experimental
  matches = .Array~new
  allItems = self~all
  do i = 1 to allItems~items
    spec = allItems~at(i)
    if spec~experimental then matches~append(spec)
  end
  return matches

::method reconstructive
  matches = .Array~new
  allItems = self~all
  do i = 1 to allItems~items
    spec = allItems~at(i)
    if spec~reconstructive then matches~append(spec)
  end
  return matches

::method candidates
  use arg domainArg = "", familyArg = "", policyArg = .nil
  domainWanted = translate(strip(domainArg))
  familyWanted = translate(strip(familyArg))
  if policyArg == .nil then policyArg = .MediaMethodologyPolicy~new
  matches = .Array~new
  allItems = self~all
  do i = 1 to allItems~items
    spec = allItems~at(i)
    if domainWanted \== "" then do
      if spec~domain \== domainWanted then iterate
    end
    if familyWanted \== "" then do
      if spec~family \== familyWanted then iterate
    end
    if \policyArg~accepts(spec) then iterate
    matches~append(spec)
  end
  return matches

::method registerProvider
  expose providers
  use arg provider
  if provider == .nil then raise syntax 93.900 array("Provider must not be NIL")
  providers~append(provider)
  return self

/* Providers are interrogated when refreshProviders() is called.  Consumers may
 * call this before each planning operation so available methodologies are not
 * frozen as permanent truth. */
::method refreshProviders
  expose providers
  do i = 1 to providers~items
    offered = providers~at(i)~methodologies
    if offered == .nil then iterate
    do j = 1 to offered~items
      self~register(offered~at(j))
    end
  end
  return self

::class MediaMethodologyStep public
::method init
  expose methodologyId parameters
  use arg methodologyIdArg, parametersArg = .nil
  methodologyId = translate(strip(methodologyIdArg))
  if methodologyId == "" then raise syntax 93.900 array("Methodology step id must not be empty")
  if parametersArg == .nil then parametersArg = .Directory~new
  parameters = parametersArg
::method methodologyId
  expose methodologyId
  return methodologyId
::method parameters
  expose parameters
  return parameters

::class MediaMethodologyPlan public
::method init
  expose goal steps
  use arg goalArg = ""
  goal = goalArg
  steps = .Array~new
::method add
  expose steps
  use arg step
  if step == .nil then raise syntax 93.900 array("Plan step must not be NIL")
  steps~append(step)
  return self
::method steps
  expose steps
  return steps~copy
::method goal
  expose goal
  return goal

::class MediaDerivedEvidence public
::method init
  expose methodologyId sourceRefs outputRef timeStart timeEnd authorityEffect uncertaintyRef metadata
  use arg methodologyIdArg, sourceRefsArg, outputRefArg, timeStartArg = .nil, timeEndArg = .nil, authorityArg = "MEASURE", uncertaintyRefArg = .nil, metadataArg = .nil
  methodologyId = translate(strip(methodologyIdArg))
  if sourceRefsArg == .nil then sourceRefsArg = .Array~new
  sourceRefs = sourceRefsArg
  outputRef = outputRefArg
  timeStart = timeStartArg
  timeEnd = timeEndArg
  authorityEffect = translate(strip(authorityArg))
  uncertaintyRef = uncertaintyRefArg
  if metadataArg == .nil then metadataArg = .Directory~new
  metadata = metadataArg
::method methodologyId
  expose methodologyId
  return methodologyId
::method sourceRefs
  expose sourceRefs
  return sourceRefs~copy
::method outputRef
  expose outputRef
  return outputRef
::method timeStart
  expose timeStart
  return timeStart
::method timeEnd
  expose timeEnd
  return timeEnd
::method authorityEffect
  expose authorityEffect
  return authorityEffect
::method uncertaintyRef
  expose uncertaintyRef
  return uncertaintyRef
::method metadata
  expose metadata
  return metadata

::class MediaReconstructionCandidate subclass MediaDerivedEvidence public
::method init
  expose candidateStatus supportMapRef
  use arg methodologyIdArg, sourceRefsArg, outputRefArg, timeStartArg = .nil, timeEndArg = .nil, uncertaintyRefArg = .nil, supportMapRefArg = .nil, metadataArg = .nil
  self~init:super(methodologyIdArg, sourceRefsArg, outputRefArg, timeStartArg, timeEndArg, "RECONSTRUCT", uncertaintyRefArg, metadataArg)
  candidateStatus = "CANDIDATE"
  supportMapRef = supportMapRefArg
::method status
  expose candidateStatus
  return candidateStatus
::method supportMapRef
  expose supportMapRef
  return supportMapRef
