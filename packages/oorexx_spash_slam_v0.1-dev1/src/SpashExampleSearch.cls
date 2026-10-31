/* SPASH example-to-corpus observation subsequence search.
 * Uses measured observations; does not decode WAV or assert physical source.
 * Architecture: Tom Dyer. Code: ChatGPT GPT-6, 2026-10-30.
 */
::requires 'SpashObservation.cls'
::class SpashExampleSearch public
::method init
  expose _floor _speedTolerance
  use strict arg minimumLikeness=.78, speedTolerance=.20
  if \datatype(minimumLikeness,'N') then raise syntax 88.900 array('numeric likeness floor',minimumLikeness)
  if \datatype(speedTolerance,'N') then raise syntax 88.900 array('numeric speed tolerance',speedTolerance)
  if minimumLikeness<0 | minimumLikeness>1 then raise syntax 88.900 array('likeness floor in [0,1]',minimumLikeness)
  if speedTolerance<0 | speedTolerance>=1 then raise syntax 88.900 array('speed tolerance in [0,1)',speedTolerance)
  _floor=minimumLikeness; _speedTolerance=speedTolerance
::method find
  expose _floor _speedTolerance
  use strict arg query,candidate,maxResults=20
  if \query~isA(.array) then raise syntax 88.900 array('query must be Array',query)
  if \candidate~isA(.array) then raise syntax 88.900 array('candidate must be Array',candidate)
  if \datatype(maxResults,'N') then raise syntax 88.900 array('numeric result count',maxResults)
  if maxResults<1 | maxResults<>trunc(maxResults) then raise syntax 88.900 array('positive integer result count',maxResults)
  if query~items=0 then raise syntax 88.900 array('nonempty query',query)
  do i=1 to query~items
    q=query[i]
    if \q~isA(.SpashObservation) then raise syntax 88.900 array('query contains wrong type',i)
  end
  do i=1 to candidate~items
    c=candidate[i]
    if \c~isA(.SpashObservation) then raise syntax 88.900 array('candidate contains wrong type',i)
  end
  /* Different feeds within one query require an explicit alignment contract. */
  do i=2 to query~items
    if query[i]~sourceId \== query[1]~sourceId then raise syntax 88.900 array('unaligned multi-feed query',i)
    if query[i]~methodFoundationId \== query[1]~methodFoundationId then raise syntax 88.900 array('mixed query foundations',i)
    if query[i]~startMs<query[i-1]~endMs then raise syntax 88.900 array('unordered/overlapping query',i)
  end
  results=.array~new
  if candidate~items<query~items then return results
  do startIndex=1 to candidate~items-query~items+1
    score=0; valid=.true; previous=.nil
    do k=1 to query~items
      q=query[k]; c=candidate[startIndex+k-1]
      if previous \== .nil then do
        if c~sourceId \== candidate[startIndex]~sourceId then valid=.false
        if c~startMs<previous~endMs then valid=.false
      end
      /* Method foundation is the explicit compatibility boundary. */
      if c~methodFoundationId \== q~methodFoundationId then valid=.false
      if c~sampleRate \== q~sampleRate then valid=.false
      if \valid then leave
      likeness=q~likeness(c)
      if likeness==.nil then do
        valid=.false; leave
      end
      score=score+likeness
      previous=c
    end
    if \valid then iterate
    first=query[1]; last=query[query~items]
    cfirst=candidate[startIndex]; clast=candidate[startIndex+query~items-1]
    qDuration=last~endMs-first~startMs
    cDuration=clast~endMs-cfirst~startMs
    if qDuration<=0 | cDuration<=0 then iterate
    timeScale=cDuration/qDuration
    if abs(timeScale-1)>_speedTolerance then iterate
    avg=score/query~items
    final=max(0,avg-.1*abs(timeScale-1))
    if final<_floor then iterate
    row=.directory~new
    row~put(first~sourceId,'QUERY_SOURCE_ID')
    row~put(cfirst~sourceId,'CANDIDATE_SOURCE_ID')
    row~put(first~startMs,'QUERY_START_MS')
    row~put(last~endMs,'QUERY_END_MS')
    row~put(cfirst~startMs,'MATCH_START_MS')
    row~put(clast~endMs,'MATCH_END_MS')
    row~put(query~items,'MATCHED_BLOCKS')
    row~put(final,'LIKENESS')
    row~put(timeScale,'TIME_SCALE')
    row~put('ALGORITHM_CANDIDATE_ONLY','AUTHORITY')
    row~put(cfirst~methodFoundationId,'METHOD_FOUNDATION_ID')
    results~append(row)
  end
  /* Deterministic likeness ranking with overlapping candidate suppression. */
  sorted=.array~new
  do i=1 to results~items
    row=results[i]
    sorted~append(row)
    do j=sorted~items to 2 by -1
      a=sorted[j]; b=sorted[j-1]
      move=.false
      if a~at('LIKENESS')>b~at('LIKENESS') then move=.true
      if a~at('LIKENESS')=b~at('LIKENESS') then do
        if a~at('CANDIDATE_SOURCE_ID')<b~at('CANDIDATE_SOURCE_ID') then move=.true
        if a~at('CANDIDATE_SOURCE_ID')=b~at('CANDIDATE_SOURCE_ID') then do
          if a~at('MATCH_START_MS')<b~at('MATCH_START_MS') then move=.true
        end
      end
      if \move then leave
      sorted[j]=b; sorted[j-1]=a
    end
  end
  selected=.array~new
  do i=1 to sorted~items
    row=sorted[i]; overlaps=.false
    do j=1 to selected~items
      old=selected[j]
      if row~at('CANDIDATE_SOURCE_ID') \== old~at('CANDIDATE_SOURCE_ID') then iterate
      if max(row~at('MATCH_START_MS'),old~at('MATCH_START_MS')) < min(row~at('MATCH_END_MS'),old~at('MATCH_END_MS')) then overlaps=.true
    end
    if overlaps then iterate
    selected~append(row)
    if selected~items>=maxResults then leave
  end
  return selected
