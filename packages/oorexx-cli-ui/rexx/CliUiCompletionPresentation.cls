/* Presentation-only adapter; Source Editor owns completion candidates. */
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
  if \datatype(index,'W') then return .false
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
::method preserveSelection
  expose candidates selected
  use strict arg nextCandidates
  old=self~current
  candidates=nextCandidates
  selected=0
  if old==.nil then return self
  do i=1 to candidates~items
    if candidates[i] \== old then iterate
    selected=i
    leave
  end
  return self
