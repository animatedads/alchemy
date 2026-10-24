/* Architecture links — architecture.interconnect/0.1
 * Each interaction has its own semantic pattern, binding and assurance
 * questions. JMS, JSON-RPC and Queue Fabric are NOT one interchangeable
 * runtime API; a selected adapter must satisfy the semantic boundary.
 */
::requires 'json.cls'

::class ArchitectureInterconnects public
::attribute links get

::method init
  expose links
  links = .Directory~new

::method hasLink
  use strict arg identity
  return self~links~hasIndex(identity)

::method hasSubsystem
  use strict arg name
  do id over self~links~allIndexes
    if self~links[id]['subsystem'] == name then return .true
  end
  return .false

::method link
  use strict arg identity, producer, consumer, subsystem, pattern, authority, rationale
  if identity~strip == '' | producer~strip == '' | consumer~strip == '' | -
     subsystem~strip == '' | authority~strip == '' | rationale~strip == '' then -
    raise syntax 93.900 array('ARCH_LINK_FIELDS_REQUIRED')
  if pos('|'pattern'|','|REQUEST_REPLY|COMMAND|EVENT|STREAM|') == 0 then -
    raise syntax 93.900 array('ARCH_LINK_PATTERN_UNKNOWN', pattern)
  if self~hasLink(identity) then raise syntax 93.900 array('ARCH_LINK_DUPLICATE', identity)
  row = .Directory~new
  row['id'] = identity
  row['producer'] = producer
  row['consumer'] = consumer
  row['subsystem'] = subsystem
  row['pattern'] = pattern
  row['authority'] = authority
  row['rationale'] = rationale
  row['binding'] = ''
  row['serviceIntent'] = .nil
  row['jmsBridge'] = .nil
  row['placement'] = 'UNKNOWN'
  row['placementAuthority'] = ''
  row['placementEvidence'] = ''
  row['bindingAuthority'] = ''
  row['bindingEvidence'] = ''
  row['guarantees'] = .Directory~new
  self~links[identity] = row
  return row

/* Binding choices are semantic integration contracts, not merely byte
 * transports. JSON-RPC carrier and JMS broker remain open qualification.
 */
::method bind
  use strict arg identity, binding, rationale, authority, evidence = ''
  if \self~hasLink(identity) then raise syntax 93.900 array('ARCH_LINK_UNKNOWN',identity)
  if pos('|'binding'|','|direct_call|json_rpc|queue_fabric|jms|') == 0 then -
    raise syntax 93.900 array('ARCH_BINDING_UNKNOWN',binding)
  if rationale~strip == '' | authority~strip == '' then -
    raise syntax 93.900 array('ARCH_BINDING_RATIONALE_OR_AUTHORITY_REQUIRED')
  row = self~links[identity]
  row['binding'] = binding
  row['bindingRationale'] = rationale
  row['bindingAuthority'] = authority
  row['bindingEvidence'] = evidence
  /* Different bindings have different proof requirements. Reconsider old
   * guarantees whenever the transport model changes. */
  row['guarantees'] = .Directory~new
  row['serviceIntent'] = .nil
  row['jmsBridge'] = .nil
  return row

/* Application intent is a separate, attributable decision from the chosen
 * connector. It maps to the public ConnectIntent contract, not to sockets.
 */
::method placement
  use strict arg identity, locality, authority, evidence
  if \self~hasLink(identity) then raise syntax 93.900 array('ARCH_LINK_UNKNOWN',identity)
  if pos('|'locality'|','|SAME_PROCESS|SAME_HOST|REMOTE|') == 0 then -
    raise syntax 93.900 array('ARCH_PLACEMENT_INVALID',locality)
  if authority~strip == '' | evidence~strip == '' then -
    raise syntax 93.900 array('ARCH_PLACEMENT_EVIDENCE_REQUIRED')
  row = self~links[identity]
  row['placement'] = locality
  row['placementAuthority'] = authority
  row['placementEvidence'] = evidence
  return row

::method serviceIntent
  use strict arg identity, operation, mode, requirement, destination, authority, rationale
  if \self~hasLink(identity) then raise syntax 93.900 array('ARCH_LINK_UNKNOWN',identity)
  if operation~strip == '' | authority~strip == '' | rationale~strip == '' then -
    raise syntax 93.900 array('ARCH_CONNECT_INTENT_PROVENANCE_REQUIRED')
  mode = mode~translate
  requirement = requirement~translate
  if pos('|'mode'|','|REQUEST|NOTIFY|ENQUEUE|') == 0 then -
    raise syntax 93.900 array('ARCH_CONNECT_MODE_UNKNOWN',mode)
  if pos('|'requirement'|','|IMMEDIATE|BEST_EFFORT|DURABLE|') == 0 then -
    raise syntax 93.900 array('ARCH_CONNECT_REQUIREMENT_UNKNOWN',requirement)
  if requirement == 'DURABLE' & mode \== 'ENQUEUE' then -
    raise syntax 93.900 array('ARCH_CONNECT_DURABILITY_ONLY_FOR_ENQUEUE')
  row = self~links[identity]
  detail = .Directory~new
  detail['operation'] = operation
  detail['mode'] = mode
  detail['requirement'] = requirement
  detail['destination'] = destination
  detail['authority'] = authority
  detail['rationale'] = rationale
  row['serviceIntent'] = detail
  row['guarantees'] = .Directory~new
  return detail

/* JMS is a boundary bridge, NOT a selectable ConnectSelector provider.
 * Both directions require their own delivery and reconciliation proof.
 */
::method jmsBridge
  use strict arg identity, direction, source, target, authority, rationale
  if \self~hasLink(identity) then raise syntax 93.900 array('ARCH_LINK_UNKNOWN',identity)
  if self~links[identity]['binding'] \== 'jms' then -
    raise syntax 93.900 array('ARCH_JMS_BRIDGE_NOT_JMS_LINK',identity)
  if pos('|'direction'|','|JMS_TO_QUEUE|QUEUE_TO_JMS|') == 0 then -
    raise syntax 93.900 array('ARCH_JMS_BRIDGE_DIRECTION_INVALID',direction)
  if source~strip == '' | target~strip == '' | authority~strip == '' | rationale~strip == '' then -
    raise syntax 93.900 array('ARCH_JMS_BRIDGE_PROVENANCE_REQUIRED')
  detail = .Directory~new
  detail['direction'] = direction
  detail['source'] = source
  detail['target'] = target
  detail['authority'] = authority
  detail['rationale'] = rationale
  detail['status'] = 'DESIGN_ONLY_NOT_TRANSACTIONALLY_QUALIFIED'
  self~links[identity]['jmsBridge'] = detail
  return detail

::method guarantee
  use strict arg identity, dimension, description, authority, evidence
  if \self~hasLink(identity) then raise syntax 93.900 array('ARCH_LINK_UNKNOWN',identity)
  if pos('|'dimension'|','|AUTH|DELIVERY|RECOVERY|CARRIER|BROKER|CORRELATION|ORDERING|ACKNOWLEDGEMENT|TRANSACTION|REDELIVERY|DEAD_LETTER|IDEMPOTENCY|') == 0 then -
    raise syntax 93.900 array('ARCH_GUARANTEE_UNKNOWN',dimension)
  if description~strip == '' | authority~strip == '' | evidence~strip == '' then -
    raise syntax 93.900 array('ARCH_GUARANTEE_EVIDENCE_REQUIRED')
  record = .Directory~new
  record['description'] = description
  record['authority'] = authority
  record['evidence'] = evidence
  record['status'] = 'PROPOSED_REQUIRES_VERIFICATION'
  self~links[identity]['guarantees'][dimension] = record
  return record

::method allLinks
  out = .Array~new
  do id over self~links~allIndexes
    out~append(self~links[id])
  end
  return out

::method questions
  output = .Array~new
  do row over self~allLinks
    binding = row['binding']
    if binding == '' then do
      self~addQuestion(output,row,'binding', -
        'How should 'row['producer']' communicate with 'row['consumer']'?', -
        'Select DIRECT, RPC, QUEUE through ConnectSelector, or an explicit JMS bridge')
      iterate
    end
    if binding == 'jms' then do
      if row['jmsBridge'] == .nil then -
        self~addQuestion(output,row,'bridge', -
          'Which direction and endpoints does the JMS/Queue Fabric bridge require?', -
          'JMS_TO_QUEUE or QUEUE_TO_JMS with explicit source and target')
      needed = .Array~of('AUTH','BROKER','DELIVERY','ACKNOWLEDGEMENT', -
        'TRANSACTION','IDEMPOTENCY','ORDERING','REDELIVERY','DEAD_LETTER','RECOVERY')
      if row['pattern'] == 'REQUEST_REPLY' then needed~append('CORRELATION')
    end
    else do
      if binding == 'direct_call' & row['placement'] == 'UNKNOWN' then -
        self~addQuestion(output,row,'placement', -
          'Is 'row['id']' definitely within one ooRexx application process?', -
          'DIRECT requires SAME_PROCESS; host proximity or an adjacent container is insufficient')
      if row['serviceIntent'] == .nil then do
        self~addQuestion(output,row,'intent', -
          'What operation and result guarantee must link 'row['id']' provide?', -
          'Provide ConnectIntent operation, REQUEST/NOTIFY/ENQUEUE, IMMEDIATE/BEST_EFFORT/DURABLE, destination')
      end
      needed = .Array~of('AUTH','DELIVERY','RECOVERY')
      if binding == 'json_rpc' then needed~append('CARRIER')
      if binding == 'queue_fabric' then needed~append('ORDERING')
    end
    do kind over needed
      if row['guarantees']~hasIndex(kind) then iterate
      self~addQuestion(output,row,kind, -
        'What is the 'kind' contract for 'row['id']' ('binding')?', -
        'Explicitly define and qualify 'kind' without assuming equivalent guarantees')
    end
  end
  return output

/* Read-only ConnectSelector qualification: never invoke execute(). The exact
 * dev1 selector has REQUEST/NOTIFY through DIRECT or RPC, ENQUEUE through
 * QUEUE; it does not implement synchronous Queue request/reply or STREAM.
 */
::method qualification
  use strict arg selectorAdapter, issues, questions
  reviews = .Array~new
  do row over self~allLinks
    binding = row['binding']
    if binding == '' then iterate
    review = .Directory~new
    review['edgeId'] = row['id']
    review['binding'] = binding
    review['selectorContract'] = 'oorexx.connect_selector/0.1'
    review['executable'] = .JSON~false
    review['provider'] = ''
    review['status'] = 'INTENT_UNRESOLVED'
    if binding == 'jms' then do
      review['status'] = 'JMS_BRIDGE_REQUIRES_EXTERNAL_QUALIFICATION'
      review['provider'] = 'JMS_BRIDGE_NOT_CONNECT_SELECTOR_PROVIDER'
      review['bridge'] = row['jmsBridge']
    end
    else if row['serviceIntent'] \== .nil then do
      intent = row['serviceIntent']
      mode = intent['mode']
      pattern = row['pattern']
      mismatch = .false
      if binding == 'direct_call' & row['placement'] == 'REMOTE' then mismatch = .true
      if binding == 'direct_call' & row['placement'] == 'SAME_HOST' then mismatch = .true
      if pattern == 'STREAM' then mismatch = .true
      if pattern == 'REQUEST_REPLY' & mode \== 'REQUEST' then mismatch = .true
      if pattern == 'EVENT' & mode == 'REQUEST' then mismatch = .true
      if binding == 'queue_fabric' & mode \== 'ENQUEUE' then mismatch = .true
      if (binding == 'direct_call' | binding == 'json_rpc') & mode == 'ENQUEUE' then mismatch = .true
      if mismatch then do
        review['status'] = 'SEMANTIC_MISMATCH'
        self~addIssue(issues,'ARCH_CONNECT_SEMANTIC_MISMATCH',row['id'], -
          'Chosen connector cannot satisfy the declared interaction mode/pattern')
      end
      else if selectorAdapter == .nil then do
        review['status'] = 'SELECTOR_NOT_PROBED'
        self~addQuestion(questions,row,'selector', -
          'Which registered ConnectSelector adapter qualifies this link?', -
          'Read-only selector explain() witness with revision, adapter registrations and target evidence')
      end
      else do
        if \selectorAdapter~hasMethod('inspect') then -
          raise syntax 93.900 array('ARCH_SELECTOR_ADAPTER_REQUIRES_INSPECT')
        review = selectorAdapter~inspect(row)
        if review['status'] \== 'ELIGIBLE_REGISTERED' then -
          self~addIssue(issues,'ARCH_CONNECT_SELECTOR_UNAVAILABLE',row['id'], -
            'ConnectSelector cannot select the requested provider/guarantee: 'review['code'])
      end
    end
    reviews~append(review)
  end
  return reviews

::method addIssue private
  use strict arg issues, code, edgeId, message
  issue = .Directory~new
  issue['code'] = code
  issue['edgeId'] = edgeId
  issue['message'] = message
  issues~append(issue)

::method addQuestion private
  use strict arg output, row, dimension, words, purpose
  q = .Directory~new
  q['id'] = 'link_'row['id']'_'dimension
  q['section'] = '04-interconnect'
  q['question'] = words
  q['purpose'] = purpose
  q['answerMechanism'] = 'LINK_BINDING_OR_GUARANTEE'
  q['options'] = .Array~new
  output~append(q)

::method requirements
  selected = .Array~new
  external = .Array~new
  do row over self~allLinks
    binding = row['binding']
    if binding == '' then iterate
    selected~append('connect_selector')
    if binding == 'queue_fabric' | binding == 'jms' then selected~append('queue_fabric')
    if binding == 'json_rpc' | binding == 'jms' then do
      contract = .Directory~new
      contract['edgeId'] = row['id']
      contract['binding'] = binding
      contract['status'] = 'INTEGRATION_ADAPTER_UNRESOLVED'
      contract['qualificationRequired'] = .JSON~true
      if binding == 'json_rpc' then do
        contract['adapterRequirement'] = 'ConnectSelector RPC adapter + qualified JSON-RPC Fabric client/server'
        contract['transportRequirement'] = 'Socket Provider/carrier/server, JSON-RPC 2.0, auth and API schema qualification'
      end
      else do
        contract['adapterRequirement'] = 'ConnectJmsBridge + qualified JMS port and Queue adapter'
        contract['transportRequirement'] = 'JMS broker, client/session, ack/redelivery, idempotency and dead-letter verification'
        contract['bridge'] = row['jmsBridge']
        contract['acknowledgementOrder'] = 'JMS_TO_QUEUE: queue commit before source ack; QUEUE_TO_JMS: JMS send/commit before queue ack'
        contract['atomicAcrossSystems'] = .JSON~false
        contract['deliveryClaim'] = 'AT_LEAST_ONCE_WITH_DUPLICATE_RISK'
      end
      external~append(contract)
    end
  end
  payload = .Directory~new
  payload['componentIds'] = selected
  payload['externalRequirements'] = external
  return payload

::method snapshot
  record = .Directory~new
  record['schema'] = 'alchemy.architecture.interconnects/0.1'
  record['edges'] = self~allLinks
  record['openQuestions'] = self~questions
  record['authority'] = 'Per-edge, unqualified semantic integration proposals'
  return record
