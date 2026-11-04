/* Single Time Service v0.9 — provider-neutral impact publication projection.
 * Pure, bounded, read-only projection: no queue write, RPC call, filesystem,
 * network, transport selection, implicit NOW, acknowledgement or dispatch.
 * Repeated projection of the same committed comparison is identical.
 */
/* No additional required classes: consumes a typed impact record. */

::class 'TimeChangePublication' public
::method init
  expose origin
  use strict arg origin = 'single.time.service'
  if origin == '' | origin~length > 128 then raise syntax 93.900 array ('bounded publication origin required')

::method project
  expose origin
  use strict arg impact, maxChanges = 366
  if \impact~isA(.Directory) then raise syntax 93.900 array ('impact record must be a directory')
  if \datatype(maxChanges,'W') | maxChanges < 1 | maxChanges > 366 then raise syntax 93.900 array ('maxChanges must be 1..366')
  if \impact~hasIndex('schema') | impact['schema'] \== 'single.time.impact/0.1' then
    raise syntax 93.900 array ('unsupported impact schema')
  if \impact~hasIndex('effect') | impact['effect'] \== 'ADVISORY_ONLY' then
    raise syntax 93.900 array ('impact is not advisory')
  if \impact~hasIndex('changes') | \impact['changes']~isA(.Array) then
    raise syntax 93.900 array ('impact changes must be an array')
  changes=impact['changes']
  if changes~items > maxChanges then raise syntax 93.900 array ('impact exceeds publication bound')
  if \impact~hasIndex('changedDays') | impact['changedDays'] \= changes~items then
    raise syntax 93.900 array ('impact change count mismatch')
  required=.array~of('institution','phrase','fromDate','throughDate','fromRevision','toRevision','fromHeadChecksum','toHeadChecksum','ruleComparisonMode')
  do key over required
    if \impact~hasIndex(key) then raise syntax 93.900 array ('missing impact provenance' key)
    if impact[key] == .nil | impact[key] == '' then raise syntax 93.900 array ('empty impact provenance' key)
  end
  if impact['ruleComparisonMode'] \== 'SAME_PROVIDER' then do
    if \impact~hasIndex('ruleFromSnapshotId') | \impact~hasIndex('ruleToSnapshotId') then
      raise syntax 93.900 array ('explicit rule comparison requires immutable snapshot identifiers')
    if impact['ruleFromSnapshotId'] == '' | impact['ruleToSnapshotId'] == '' then
      raise syntax 93.900 array ('empty rule snapshot identity')
  end
  output=.array~new
  do change over changes
    if \change~isA(.Directory) then raise syntax 93.900 array ('impact change must be a directory')
    if \change~hasIndex('date') | \change~hasIndex('reasonCodes') |,
       \change~hasIndex('before') | \change~hasIndex('after') then
      raise syntax 93.900 array ('incomplete impact change')
    if \change['reasonCodes']~isA(.Array) | change['reasonCodes']~items == 0 then
      raise syntax 93.900 array ('impact change requires reason codes')
    date=change['date']
    if date~length \= 10 then raise syntax 93.900 array ('impact change ISO date required')
    row=.directory~new
    row['schema']='single.time.change/0.1'
    row['origin']=origin
    row['kind']='TEMPORAL_IMPACT'
    row['institution']=impact['institution']
    row['phrase']=impact['phrase']
    row['date']=date
    row['authorityFromRevision']=impact['fromRevision']
    row['authorityToRevision']=impact['toRevision']
    row['authorityFromWitness']=impact['fromHeadChecksum']
    row['authorityToWitness']=impact['toHeadChecksum']
    row['ruleComparisonMode']=impact['ruleComparisonMode']
    row['ruleFromSnapshotId']=''
    row['ruleToSnapshotId']=''
    if impact~hasIndex('ruleFromSnapshotId') then row['ruleFromSnapshotId']=impact['ruleFromSnapshotId']
    if impact~hasIndex('ruleToSnapshotId') then row['ruleToSnapshotId']=impact['ruleToSnapshotId']
    row['reasonCodes']=change['reasonCodes']~copy
    row['before']=change['before']
    row['after']=change['after']
    if change~hasIndex('utcDeltaSeconds') then row['utcDeltaSeconds']=change['utcDeltaSeconds']
    else row['utcDeltaSeconds']=.nil
    row['deliverySemantics']='UNPUBLISHED_PROJECTION'
    row['effect']='ADVISORY_ONLY'
    /* Identity uses length prefixes to avoid field-collision ambiguity.
     * Consumers must key on the entire tuple, not treat it as an auth token. */
    key=''
    do value over .array~of(row['origin'],row['institution'],row['phrase'],row['date'],
       row['authorityFromRevision'],row['authorityToRevision'],
       row['authorityFromWitness'],row['authorityToWitness'],row['ruleComparisonMode'],
       row['ruleFromSnapshotId'],row['ruleToSnapshotId'])
      key=key || value~length || ':' || value
    end
    row['idempotencyKey']=key
    output~append(row)
  end
  return output
