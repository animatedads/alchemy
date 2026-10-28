/* Presentation adapter: Source Editor owns candidate semantics and ordering. */
::class CliUiCompletionPresentation public
::method init
  expose candidates selected
  use strict arg candidates
  selected=0
::attribute selected get
::method count
  expose candidates
  return candidates~items
::method candidate
  expose candidates
  use strict arg index
  if index<1 | index>candidates~items then return .nil
  return candidates[index]
::method select
  expose candidates selected
  use strict arg index
  if index<1 | index>candidates~items then return .false
  selected=index
  return .true
::method current
  expose selected
  if selected=0 then return .nil
  return self~candidate(selected)
::method replaceCandidates
  expose candidates selected
  use strict arg nextCandidates
  candidates=nextCandidates
  selected=0
  return self
