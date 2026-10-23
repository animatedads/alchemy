/* ooRexx Maths v0.18 -- theoretical mathematics foundations.
 *
 * This file owns generic mathematical structure, never domain interpretation.
 * v0.18 deliberately begins with executable finite structures so the object
 * vocabulary is backed by checkable semantics rather than taxonomy alone.
 */

::class MathSet public
::method init
  expose _values _byKey
  use strict arg elements
  if \elements~isA(.Array) then raise syntax 88.900 array('Array of set elements',elements)
  _values=.array~new
  _byKey=.directory~new
  do element over elements
    key=math_theory_key(element)
    if \_byKey~hasIndex(key) then do
      _byKey[key]=element
      _values~append(element)
    end
  end
::method empty class
  return self~new(.array~new)
::method of class
  use strict arg elements
  return self~new(elements)
::method values
  expose _values
  return _values
::method cardinality
  expose _values
  return _values~items
::method items
  return self~cardinality
::method contains
  expose _byKey
  use strict arg value
  return _byKey~hasIndex(math_theory_key(value))
::method '[]'
  use strict arg value
  return self~contains(value)
::method union
  expose _values
  use strict arg other
  call math_theory_require_set other
  a=.array~new
  do v over _values; a~append(v); end
  do v over other~values; a~append(v); end
  return .MathSet~new(a)
::method intersection
  expose _values
  use strict arg other
  call math_theory_require_set other
  a=.array~new
  do v over _values
    if other~contains(v) then a~append(v)
  end
  return .MathSet~new(a)
::method difference
  expose _values
  use strict arg other
  call math_theory_require_set other
  a=.array~new
  do v over _values
    if \other~contains(v) then a~append(v)
  end
  return .MathSet~new(a)
::method subsetOf
  expose _values
  use strict arg other
  call math_theory_require_set other
  do v over _values
    if \other~contains(v) then return .false
  end
  return .true
::method properSubsetOf
  use strict arg other
  if \self~subsetOf(other) then return .false
  return self~cardinality < other~cardinality
::method equals
  use strict arg other
  if \other~isA(.MathSet) then return .false
  if self~cardinality <> other~cardinality then return .false
  return self~subsetOf(other)
::method canonical
  expose _byKey
  keys=_byKey~allIndexes
  keys~sort
  out='set{'
  first=.true
  do key over keys
    if \first then out=out','
    first=.false
    out=out||key
  end
  return out'}'
::method string
  return self~canonical


::class MathOrderedPair public
::method init
  expose _left _right
  use strict arg left,right
  _left=left; _right=right
::method left; expose _left; return _left
::method right; expose _right; return _right
::method first; expose _left; return _left
::method second; expose _right; return _right
::method canonical
  expose _left _right
  return '('math_theory_key(_left)','math_theory_key(_right)')'
::method string; return self~canonical


::class MathMapEntry public
::method init
  expose _from _to
  use strict arg from,to
  _from=from; _to=to
::method from; expose _from; return _from
::method to; expose _to; return _to
::method canonical
  expose _from _to
  return math_theory_key(_from)'->'math_theory_key(_to)
::method string; return self~canonical


::class MathMap public
::method init
  expose _domain _codomain _entries _byKey
  use strict arg domain,codomain,mappings
  call math_theory_require_set domain
  call math_theory_require_set codomain
  if \mappings~isA(.Array) then raise syntax 88.900 array('Array of map entries',mappings)
  _domain=domain; _codomain=codomain; _entries=.array~new; _byKey=.directory~new
  do mapping over mappings
    if mapping~isA(.MathMapEntry) then entry=mapping
    else do
      if \mapping~isA(.Array) then raise syntax 88.900 array('MathMapEntry or [from,to] pair',mapping)
      if mapping~items<>2 then raise syntax 88.900 array('two-element map pair',mapping~items)
      entry=.MathMapEntry~new(mapping[1],mapping[2])
    end
    from=entry~from; to=entry~to
    if \domain~contains(from) then raise syntax 88.900 array('map source in domain',math_theory_key(from))
    if \codomain~contains(to) then raise syntax 88.900 array('map target in codomain',math_theory_key(to))
    key=math_theory_key(from)
    if _byKey~hasIndex(key) then raise syntax 88.900 array('single image for each map source',key)
    _byKey[key]=entry
    _entries~append(entry)
  end
  if _entries~items<>domain~cardinality then raise syntax 88.900 array('total map covering domain',_entries~items)
::method domain; expose _domain; return _domain
::method codomain; expose _codomain; return _codomain
::method entries; expose _entries; return _entries
::method apply
  expose _domain _byKey
  use strict arg value
  if \_domain~contains(value) then raise syntax 88.900 array('map argument in domain',math_theory_key(value))
  return _byKey[math_theory_key(value)]~to
::method image
  expose _entries
  a=.array~new
  do entry over _entries; a~append(entry~to); end
  return .MathSet~new(a)
::method injective
  expose _entries
  seen=.directory~new
  do entry over _entries
    key=math_theory_key(entry~to)
    if seen~hasIndex(key) then return .false
    seen[key]=1
  end
  return .true
::method surjective
  expose _codomain
  return self~image~equals(_codomain)
::method bijective
  if \self~injective then return .false
  return self~surjective
::method compose
  expose _codomain _domain _entries
  use strict arg after
  if \after~isA(.MathMap) then raise syntax 88.900 array('MathMap',after)
  if \_codomain~equals(after~domain) then raise syntax 88.900 array('compatible map codomain/domain','incompatible')
  pairs=.array~new
  do entry over _entries
    pairs~append(.array~of(entry~from,after~apply(entry~to)))
  end
  return .MathMap~new(_domain,after~codomain,pairs)
::method canonical
  expose _domain _codomain _entries
  out='map[' _domain~canonical '->' _codomain~canonical ']'
  do entry over _entries; out=out'{'entry~canonical'}'; end
  return out
::method string; return self~canonical


::class MathRelation public
::method init
  expose _leftSet _rightSet _pairs _byKey
  use strict arg leftSet,rightSet,pairs
  call math_theory_require_set leftSet
  call math_theory_require_set rightSet
  if \pairs~isA(.Array) then raise syntax 88.900 array('Array of relation pairs',pairs)
  _leftSet=leftSet; _rightSet=rightSet; _pairs=.array~new; _byKey=.directory~new
  do pair over pairs
    if pair~isA(.MathOrderedPair) then p=pair
    else do
      if \pair~isA(.Array) then raise syntax 88.900 array('MathOrderedPair or [left,right] pair',pair)
      if pair~items<>2 then raise syntax 88.900 array('two-element relation pair',pair~items)
      p=.MathOrderedPair~new(pair[1],pair[2])
    end
    if \leftSet~contains(p~left) then raise syntax 88.900 array('relation left member in left set',math_theory_key(p~left))
    if \rightSet~contains(p~right) then raise syntax 88.900 array('relation right member in right set',math_theory_key(p~right))
    key=math_theory_pair_key(p~left,p~right)
    if \_byKey~hasIndex(key) then do
      _byKey[key]=p; _pairs~append(p)
    end
  end
::method leftSet; expose _leftSet; return _leftSet
::method rightSet; expose _rightSet; return _rightSet
::method pairs; expose _pairs; return _pairs
::method contains
  expose _byKey
  use strict arg left,right
  return _byKey~hasIndex(math_theory_pair_key(left,right))
::method inverse
  expose _leftSet _rightSet _pairs
  pairs=.array~new
  do p over _pairs; pairs~append(.array~of(p~right,p~left)); end
  return .MathRelation~new(_rightSet,_leftSet,pairs)
::method reflexive
  expose _leftSet _rightSet
  if \_leftSet~equals(_rightSet) then return .false
  do v over _leftSet~values
    if \self~contains(v,v) then return .false
  end
  return .true
::method symmetric
  expose _leftSet _rightSet _pairs
  if \_leftSet~equals(_rightSet) then return .false
  do p over _pairs
    if \self~contains(p~right,p~left) then return .false
  end
  return .true
::method transitive
  expose _leftSet _rightSet _pairs
  if \_leftSet~equals(_rightSet) then return .false
  do p over _pairs
    do q over _pairs
      if math_theory_equal(p~right,q~left) then do
        if \self~contains(p~left,q~right) then return .false
      end
    end
  end
  return .true
::method equivalence
  if \self~reflexive then return .false
  if \self~symmetric then return .false
  return self~transitive
::method canonical
  expose _leftSet _rightSet _pairs
  out='relation[' _leftSet~canonical 'x' _rightSet~canonical ']'
  do p over _pairs; out=out'{'p~canonical'}'; end
  return out
::method string; return self~canonical


::class MathFiniteBinaryOperation public
::method init
  expose _carrier _table
  use strict arg carrier,table
  call math_theory_require_set carrier
  if \table~isA(.Array) then raise syntax 88.900 array('Array of [left,right,value] operation rows',table)
  _carrier=carrier; _table=.directory~new
  do row over table
    if \row~isA(.Array) then raise syntax 88.900 array('three-element operation row',row)
    if row~items<>3 then raise syntax 88.900 array('three-element operation row',row~items)
    left=row[1]; right=row[2]; value=row[3]
    if \carrier~contains(left) then raise syntax 88.900 array('operation left operand in carrier',math_theory_key(left))
    if \carrier~contains(right) then raise syntax 88.900 array('operation right operand in carrier',math_theory_key(right))
    if \carrier~contains(value) then raise syntax 88.900 array('operation value in carrier',math_theory_key(value))
    key=math_theory_pair_key(left,right)
    if _table~hasIndex(key) then raise syntax 88.900 array('single operation result for ordered pair',key)
    _table[key]=value
  end
  expected=carrier~cardinality*carrier~cardinality
  if _table~items<>expected then raise syntax 88.900 array('total finite binary operation table',_table~items)
::method carrier; expose _carrier; return _carrier
::method apply
  expose _carrier _table
  use strict arg left,right
  if \_carrier~contains(left) then raise syntax 88.900 array('operation left operand in carrier',math_theory_key(left))
  if \_carrier~contains(right) then raise syntax 88.900 array('operation right operand in carrier',math_theory_key(right))
  return _table[math_theory_pair_key(left,right)]
::method associative
  expose _carrier
  do a over _carrier~values
    do b over _carrier~values
      do c over _carrier~values
        left=self~apply(self~apply(a,b),c)
        right=self~apply(a,self~apply(b,c))
        if \math_theory_equal(left,right) then return .false
      end
    end
  end
  return .true
::method commutative
  expose _carrier
  do a over _carrier~values
    do b over _carrier~values
      if \math_theory_equal(self~apply(a,b),self~apply(b,a)) then return .false
    end
  end
  return .true
::method hasIdentity
  expose _carrier
  use strict arg identity
  if \_carrier~contains(identity) then return .false
  do a over _carrier~values
    if \math_theory_equal(self~apply(identity,a),a) then return .false
    if \math_theory_equal(self~apply(a,identity),a) then return .false
  end
  return .true
::method hasInverseFor
  expose _carrier
  use strict arg value,identity
  do candidate over _carrier~values
    left=self~apply(value,candidate)
    right=self~apply(candidate,value)
    if math_theory_equal(left,identity) then do
      if math_theory_equal(right,identity) then return .true
    end
  end
  return .false
::method canonical
  expose _carrier _table
  keys=_table~allIndexes; keys~sort
  out='binary-operation[' _carrier~canonical ']'
  do key over keys; out=out'{'key'='math_theory_key(_table[key])'}'; end
  return out
::method string; return self~canonical


::class MathFiniteGroup public
::method init
  expose _carrier _operation _identity _valid _checks
  use strict arg carrier,operation,identity
  call math_theory_require_set carrier
  if \operation~isA(.MathFiniteBinaryOperation) then raise syntax 88.900 array('MathFiniteBinaryOperation',operation)
  if \carrier~equals(operation~carrier) then raise syntax 88.900 array('operation on the supplied carrier','carrier mismatch')
  if \carrier~contains(identity) then raise syntax 88.900 array('group identity in carrier',math_theory_key(identity))
  _carrier=carrier; _operation=operation; _identity=identity; _checks=.directory~new
  _checks['closure']=.true
  _checks['associative']=operation~associative
  _checks['identity']=operation~hasIdentity(identity)
  inverses=.true
  do value over carrier~values
    if \operation~hasInverseFor(value,identity) then inverses=.false
  end
  _checks['inverses']=inverses
  _valid=_checks['associative']
  if _valid then _valid=_checks['identity']
  if _valid then _valid=_checks['inverses']
::method carrier; expose _carrier; return _carrier
::method operation; expose _operation; return _operation
::method identity; expose _identity; return _identity
::method checks; expose _checks; return _checks
::method valid; expose _valid; return _valid
::method abelian
  expose _valid _operation
  if \_valid then return .false
  return _operation~commutative
::method order; expose _carrier; return _carrier~cardinality
::method canonical
  expose _carrier _identity _valid
  return 'finite-group[carrier='_carrier~canonical';identity='math_theory_key(_identity)';valid='_valid']'
::method string; return self~canonical

::class MathFiniteMonoid public
::method init
  expose _carrier _operation _identity _checks _valid
  use strict arg carrier,operation,identity
  call math_theory_require_set carrier
  if \operation~isA(.MathFiniteBinaryOperation) then raise syntax 88.900 array('MathFiniteBinaryOperation',operation)
  if \carrier~equals(operation~carrier) then raise syntax 88.900 array('operation on the supplied carrier','carrier mismatch')
  if \carrier~contains(identity) then raise syntax 88.900 array('monoid identity in carrier',math_theory_key(identity))
  _carrier=carrier; _operation=operation; _identity=identity; _checks=.directory~new
  _checks['closure']=.true
  _checks['associative']=operation~associative
  _checks['identity']=operation~hasIdentity(identity)
  _valid=_checks['associative']
  if _valid then _valid=_checks['identity']
::method carrier; expose _carrier; return _carrier
::method operation; expose _operation; return _operation
::method identity; expose _identity; return _identity
::method checks; expose _checks; return _checks
::method valid; expose _valid; return _valid
::method commutative
  expose _valid _operation
  if \_valid then return .false
  return _operation~commutative
::method order; expose _carrier; return _carrier~cardinality
::method canonical
  expose _carrier _identity _valid
  return 'finite-monoid[carrier='_carrier~canonical';identity='math_theory_key(_identity)';valid='_valid']'
::method string; return self~canonical


::class MathFiniteRing public
::method init
  expose _carrier _addition _multiplication _zero _one _checks _valid
  use strict arg carrier,addition,multiplication,zero,one=.nil
  call math_theory_require_set carrier
  if \addition~isA(.MathFiniteBinaryOperation) then raise syntax 88.900 array('MathFiniteBinaryOperation addition',addition)
  if \multiplication~isA(.MathFiniteBinaryOperation) then raise syntax 88.900 array('MathFiniteBinaryOperation multiplication',multiplication)
  if \carrier~equals(addition~carrier) then raise syntax 88.900 array('addition on ring carrier','carrier mismatch')
  if \carrier~equals(multiplication~carrier) then raise syntax 88.900 array('multiplication on ring carrier','carrier mismatch')
  if \carrier~contains(zero) then raise syntax 88.900 array('ring zero in carrier',math_theory_key(zero))
  if one \== .nil then do
    if \carrier~contains(one) then raise syntax 88.900 array('ring one in carrier',math_theory_key(one))
  end
  _carrier=carrier; _addition=addition; _multiplication=multiplication; _zero=zero; _one=one; _checks=.directory~new
  addGroup=.MathFiniteGroup~new(carrier,addition,zero)
  _checks['additiveAbelianGroup']=addGroup~valid
  if _checks['additiveAbelianGroup'] then _checks['additiveAbelianGroup']=addGroup~abelian
  _checks['multiplicationAssociative']=multiplication~associative
  distributive=.true
  do a over carrier~values
    do b over carrier~values
      do c over carrier~values
        left=multiplication~apply(a,addition~apply(b,c))
        right=addition~apply(multiplication~apply(a,b),multiplication~apply(a,c))
        if \math_theory_equal(left,right) then distributive=.false
        left=multiplication~apply(addition~apply(a,b),c)
        right=addition~apply(multiplication~apply(a,c),multiplication~apply(b,c))
        if \math_theory_equal(left,right) then distributive=.false
      end
    end
  end
  _checks['distributive']=distributive
  if one == .nil then _checks['multiplicativeIdentity']='UNDECLARED'
  else _checks['multiplicativeIdentity']=multiplication~hasIdentity(one)
  _valid=_checks['additiveAbelianGroup']
  if _valid then _valid=_checks['multiplicationAssociative']
  if _valid then _valid=_checks['distributive']
  if _valid then do
    if one \== .nil then _valid=_checks['multiplicativeIdentity']
  end
::method carrier; expose _carrier; return _carrier
::method addition; expose _addition; return _addition
::method multiplication; expose _multiplication; return _multiplication
::method zero; expose _zero; return _zero
::method one; expose _one; return _one
::method checks; expose _checks; return _checks
::method valid; expose _valid; return _valid
::method unital; expose _one _checks; if _one == .nil then return .false; return _checks['multiplicativeIdentity']
::method commutative
  expose _valid _multiplication
  if \_valid then return .false
  return _multiplication~commutative
::method order; expose _carrier; return _carrier~cardinality
::method canonical
  expose _carrier _zero _one _valid
  oneText='UNDECLARED'; if _one \== .nil then oneText=math_theory_key(_one)
  return 'finite-ring[carrier='_carrier~canonical';zero='math_theory_key(_zero)';one='oneText';valid='_valid']'
::method string; return self~canonical


::class MathFiniteField public
::method init
  expose _ring _checks _valid
  use strict arg ring
  if \ring~isA(.MathFiniteRing) then raise syntax 88.900 array('MathFiniteRing',ring)
  _ring=ring; _checks=.directory~new
  _checks['ring']=ring~valid
  _checks['commutative']=ring~commutative
  _checks['unital']=ring~unital
  inverses=.true
  if _checks['ring'] then do
    carrier=ring~carrier
    multiply=ring~multiplication
    zero=ring~zero; one=ring~one
    do value over carrier~values
      if \math_theory_equal(value,zero) then do
        if \multiply~hasInverseFor(value,one) then inverses=.false
      end
    end
  end
  else inverses=.false
  _checks['nonzeroMultiplicativeInverses']=inverses
  _valid=_checks['ring']
  if _valid then _valid=_checks['commutative']
  if _valid then _valid=_checks['unital']
  if _valid then _valid=_checks['nonzeroMultiplicativeInverses']
::method ring; expose _ring; return _ring
::method carrier; expose _ring; return _ring~carrier
::method addition; expose _ring; return _ring~addition
::method multiplication; expose _ring; return _ring~multiplication
::method zero; expose _ring; return _ring~zero
::method one; expose _ring; return _ring~one
::method checks; expose _checks; return _checks
::method valid; expose _valid; return _valid
::method order; expose _ring; return _ring~order
::method canonical
  expose _ring _valid
  return 'finite-field[ring={'_ring~canonical'};valid='_valid']'
::method string; return self~canonical


::class MathGroupHomomorphism public
::method init
  expose _source _target _map _valid
  use strict arg sourceGroup,targetGroup,map
  if \sourceGroup~isA(.MathFiniteGroup) then raise syntax 88.900 array('MathFiniteGroup source',sourceGroup)
  if \targetGroup~isA(.MathFiniteGroup) then raise syntax 88.900 array('MathFiniteGroup target',targetGroup)
  if \map~isA(.MathMap) then raise syntax 88.900 array('MathMap',map)
  if \map~domain~equals(sourceGroup~carrier) then raise syntax 88.900 array('map domain equal to source group carrier','mismatch')
  if \map~codomain~equals(targetGroup~carrier) then raise syntax 88.900 array('map codomain equal to target group carrier','mismatch')
  _source=sourceGroup; _target=targetGroup; _map=map
  _valid=.true
  do a over sourceGroup~carrier~values
    do b over sourceGroup~carrier~values
      sourceValue=sourceGroup~operation~apply(a,b)
      mappedSource=map~apply(sourceValue)
      targetValue=targetGroup~operation~apply(map~apply(a),map~apply(b))
      if \math_theory_equal(mappedSource,targetValue) then _valid=.false
    end
  end
::method source; expose _source; return _source
::method target; expose _target; return _target
::method map; expose _map; return _map
::method valid; expose _valid; return _valid
::method injective; expose _valid _map; if \_valid then return .false; return _map~injective
::method surjective; expose _valid _map; if \_valid then return .false; return _map~surjective
::method isomorphism
  if \self~injective then return .false
  return self~surjective
::method kernel
  expose _source _target _map
  a=.array~new
  do value over _source~carrier~values
    if math_theory_equal(_map~apply(value),_target~identity) then a~append(value)
  end
  return .MathSet~new(a)
::method canonical
  expose _source _target _map _valid
  return 'group-homomorphism[source={'_source~canonical'};target={'_target~canonical'};map={'_map~canonical'};valid='_valid']'
::method string; return self~canonical


/* Mathematical statements are revision-bearing objects.  A proof artifact is
 * admissible only for the exact statement id and revision it names. */
::class MathStatement public
::method init
  expose _id _text _assumptions _revision _dependencies _artifacts _state
  use strict arg id,text,assumptions=.nil,revision=1
  if id~string~strip='' then raise syntax 88.900 array('non-empty statement id',id)
  if text~string~strip='' then raise syntax 88.900 array('non-empty mathematical statement',text)
  if \datatype(revision,'W') then raise syntax 88.900 array('positive statement revision',revision)
  if revision<1 then raise syntax 88.900 array('positive statement revision',revision)
  _id=id~string~strip~upper; _text=text~string; _assumptions=assumptions; _revision=revision
  _dependencies=.array~new; _artifacts=.array~new; _state='PROPOSED'
::method id; expose _id; return _id
::method text; expose _text; return _text
::method assumptions; expose _assumptions; return _assumptions
::method revision; expose _revision; return _revision
::method kind; return 'STATEMENT'
::method dependencies; expose _dependencies; return _dependencies
::method proofArtifacts; expose _artifacts; return _artifacts
::method state; expose _state; return _state
::method addDependency
  expose _dependencies _id _revision
  use strict arg statement
  if \statement~isA(.MathStatement) then raise syntax 88.900 array('MathStatement dependency',statement)
  if statement~id=_id then do
    if statement~revision=_revision then raise syntax 88.900 array('non-self statement dependency',_id)
  end
  _dependencies~append(statement); return self
::method attachProof
  expose _artifacts _id _revision _state
  use strict arg artifact
  if \artifact~isA(.MathProofArtifact) then raise syntax 88.900 array('MathProofArtifact',artifact)
  if artifact~statementId<>_id then raise syntax 88.900 array('proof artifact for statement '_id,artifact~statementId)
  if artifact~statementRevision<>_revision then raise syntax 88.900 array('proof artifact for statement revision '_revision,artifact~statementRevision)
  _artifacts~append(artifact)
  if artifact~accepted then do
    select
      when artifact~kind='COUNTEREXAMPLE' then _state='DISPROVED'
      when artifact~kind='FORMAL' then _state='FORMALIZED'
      when artifact~kind='INDEPENDENT_CHECK' then if _state<>'FORMALIZED' then _state='INDEPENDENTLY_CHECKED'
      otherwise if _state='PROPOSED' then _state='PROVED'
    end
  end
  return self
::method withdraw
  expose _state
  _state='WITHDRAWN'; return self
::method disprove
  expose _state
  _state='DISPROVED'; return self
::method supersede
  expose _state
  _state='SUPERSEDED'; return self
::method canonical
  expose _id _text _revision _state _dependencies _artifacts
  out='statement[id='_id';revision='_revision';kind='self~kind';state='_state';text='_text']'
  i=0
  do d over _dependencies; i+=1; out=out'|dependency['i']='d~id'@'d~revision; end
  i=0
  do a over _artifacts; i+=1; out=out'|proof['i']={'a~canonical'}'; end
  return out
::method string; return self~canonical

::class MathDefinition subclass MathStatement public
::method kind; return 'DEFINITION'

::class MathAxiom subclass MathStatement public
::method kind; return 'AXIOM'

::class MathLemma subclass MathStatement public
::method kind; return 'LEMMA'

::class MathTheorem subclass MathStatement public
::method kind; return 'THEOREM'

::class MathCorollary subclass MathStatement public
::method kind; return 'COROLLARY'

::class MathConjecture subclass MathStatement public
::method kind; return 'CONJECTURE'


::class MathProofArtifact public
::method init
  expose _statementId _statementRevision _kind _authority _authorityVersion _status _reference
  use strict arg statementId,statementRevision,kind,authority,authorityVersion='',status='VERIFIED',reference=''
  if \datatype(statementRevision,'W') then raise syntax 88.900 array('positive statement revision',statementRevision)
  if statementRevision<1 then raise syntax 88.900 array('positive statement revision',statementRevision)
  _statementId=statementId~string~strip~upper; _statementRevision=statementRevision
  _kind=kind~string~strip~upper; _authority=authority~string~strip; _authorityVersion=authorityVersion~string~strip
  _status=status~string~strip~upper; _reference=reference~string
  select
    when _kind='FORMAL' then nop
    when _kind='DERIVATION' then nop
    when _kind='INDEPENDENT_CHECK' then nop
    when _kind='COUNTEREXAMPLE' then nop
    otherwise raise syntax 88.900 array('FORMAL, DERIVATION, INDEPENDENT_CHECK, or COUNTEREXAMPLE proof kind',_kind)
  end
::method statementId; expose _statementId; return _statementId
::method statementRevision; expose _statementRevision; return _statementRevision
::method kind; expose _kind; return _kind
::method authority; expose _authority; return _authority
::method authorityVersion; expose _authorityVersion; return _authorityVersion
::method status; expose _status; return _status
::method reference; expose _reference; return _reference
::method accepted
  expose _status
  return _status='VERIFIED' | _status='PASS' | _status='FORMALLY_VERIFIED'
::method canonical
  expose _statementId _statementRevision _kind _authority _authorityVersion _status _reference
  return 'proof-artifact[statement='_statementId'@'_statementRevision';kind='_kind';authority='_authority';version='_authorityVersion';status='_status';reference='_reference']'
::method string; return self~canonical


::class MathTheoryCatalogue public
::method init
  expose _byId
  _byId=.directory~new
::method add
  expose _byId
  use strict arg statement
  if \statement~isA(.MathStatement) then raise syntax 88.900 array('MathStatement catalogue entry',statement)
  id=statement~id
  if \_byId~hasIndex(id) then _byId[id]=.array~new
  revisions=_byId[id]
  do existing over revisions
    if existing~revision=statement~revision then raise syntax 88.900 array('unique statement revision for 'id,statement~revision)
  end
  revisions~append(statement)
  return statement
::method ids
  expose _byId
  ids=_byId~allIndexes
  ids~sort
  return ids
::method has
  expose _byId
  use strict arg id
  return _byId~hasIndex(id~string~strip~upper)
::method revision
  expose _byId
  use strict arg id,revision
  key=id~string~strip~upper
  if \_byId~hasIndex(key) then return .nil
  do statement over _byId[key]
    if statement~revision=revision then return statement
  end
  return .nil
::method latest
  expose _byId
  use strict arg id
  key=id~string~strip~upper
  if \_byId~hasIndex(key) then return .nil
  best=.nil; bestRevision=0
  do statement over _byId[key]
    if statement~revision>bestRevision then do
      best=statement; bestRevision=statement~revision
    end
  end
  return best
::method revisionCount
  expose _byId
  use strict arg id
  key=id~string~strip~upper
  if \_byId~hasIndex(key) then return 0
  return _byId[key]~items
::method canonical
  expose _byId
  ids=self~ids
  out='theory-catalogue'
  do id over ids
    out=out'|'id'['self~revisionCount(id)']'
  end
  return out
::method string; return self~canonical


::routine math_theory_require_set
  use strict arg value
  if \value~isA(.MathSet) then raise syntax 88.900 array('MathSet',value)
  return value

::routine math_theory_key
  use strict arg value
  if value~hasMethod('CANONICAL') then return value~canonical
  return value~string

::routine math_theory_pair_key
  use strict arg left,right
  l=math_theory_key(left); r=math_theory_key(right)
  return l~length':'l'|'r~length':'r

::routine math_theory_equal
  use strict arg left,right
  return math_theory_key(left)==math_theory_key(right)
