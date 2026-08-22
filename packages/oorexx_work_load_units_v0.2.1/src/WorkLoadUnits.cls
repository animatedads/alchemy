/*
 * WorkLoadUnits v0.2
 *
 * A common workload-accounting, admission and delivery-capacity primitive for
 * ooRexx systems.  WLU is deliberately not money.  Consumers emit metering
 * facts; versioned policy values those facts into WLU.  WLU measures work;
 * WLU/second expresses requested delivery capacity.  Entitlement, temporary
 * burst limits and throughput promises are enforced before consumer side
 * effects begin.
 */

::options digits 30

::class WLUDBuild public
::constant VERSION "0.2.1"
::constant API_VERSION "work.load.units/0.2"
::constant MICRO_PER_WLU 1000000

::class WLUReservationState public
::constant ACTIVE "ACTIVE"
::constant SETTLED "SETTLED"
::constant RELEASED "RELEASED"
::constant EXPIRED "EXPIRED"

::class WLUResult public
::attribute ok get
::attribute code get
::attribute value get
::attribute detail get
::attribute retryAfterSeconds get

::method init
  expose ok code value detail retryAfterSeconds
  use strict arg ok = .false, code = "WLU_FAILED", value = .nil, detail = "", retryAfterSeconds = .nil

::method success class
  use strict arg value = .nil, detail = ""
  return self~new(.true, "WLU_OK", value, detail)

::method failure class
  use strict arg code, detail = "", value = .nil, retryAfterSeconds = .nil
  return self~new(.false, code, value, detail, retryAfterSeconds)

::class WLUUnits public

::method parse class
  use strict arg text
  numeric digits 30
  text = text~string~strip
  if text = "" then raise syntax 88.900 array("WLU amount must not be empty")
  if text~substr(1, 1) = "-" then raise syntax 88.900 array("WLU amount must not be negative")
  dot = text~pos(".")
  if dot = 0 then do
    whole = text
    fraction = ""
  end
  else do
    if text~lastPos(".") \= dot then raise syntax 88.900 array("WLU amount contains more than one decimal point")
    whole = text~left(dot - 1)
    fraction = text~substr(dot + 1)
  end
  if whole = "" then whole = "0"
  if verify(whole, "0123456789") \= 0 then raise syntax 88.900 array("WLU amount has a non-decimal whole part")
  if fraction \= "" then do
    if verify(fraction, "0123456789") \= 0 then raise syntax 88.900 array("WLU amount has a non-decimal fractional part")
    if fraction~length > 6 then raise syntax 88.900 array("WLU amount supports at most six decimal places")
  end
  fraction = (fraction || "000000")~left(6)
  return (whole * .WLUDBuild~MICRO_PER_WLU) + fraction

::method format class
  use strict arg microWlu
  numeric digits 30
  ignore = self~assertMicro(microWlu)
  whole = microWlu % .WLUDBuild~MICRO_PER_WLU
  fraction = (microWlu // .WLUDBuild~MICRO_PER_WLU)~right(6, "0")
  do while fraction \= "" & fraction~right(1) = "0"
    fraction = fraction~left(fraction~length - 1)
  end
  if fraction = "" then return whole~string
  return whole~string || "." || fraction

::method assertMicro class
  use strict arg microWlu
  if \datatype(microWlu, "W") then raise syntax 88.900 array("WLU micro-unit value must be a whole number")
  if microWlu < 0 then raise syntax 88.900 array("WLU micro-unit value must not be negative")
  return microWlu

::method ceilDivide class
  use strict arg numerator, denominator
  numeric digits 30
  if denominator <= 0 then raise syntax 88.900 array("WLU denominator must be positive")
  if numerator <= 0 then return 0
  return (numerator + denominator - 1) % denominator

::class WLUTimeSource public
::method nowTick
  numeric digits 30
  return time("F")
::method addSeconds
  use strict arg tick, seconds
  numeric digits 30
  return tick + (seconds * 1000000)
::method secondsUntil
  use strict arg futureTick
  numeric digits 30
  remaining = futureTick - self~nowTick
  if remaining <= 0 then return 0
  return .WLUUnits~ceilDivide(remaining, 1000000)

::class WLUTestTimeSource public
::attribute tick get
::method init
  expose tick
  use strict arg startTick = 1000000
  numeric digits 30
  tick = startTick
::method nowTick
  expose tick
  return tick
::method addSeconds
  use strict arg baseTick, seconds
  numeric digits 30
  return baseTick + (seconds * 1000000)
::method secondsUntil
  expose tick
  use strict arg futureTick
  numeric digits 30
  remaining = futureTick - tick
  if remaining <= 0 then return 0
  return .WLUUnits~ceilDivide(remaining, 1000000)
::method advanceSeconds
  expose tick
  use strict arg seconds
  numeric digits 30
  tick += seconds * 1000000
  return tick

::class WLUIdGenerator public
::attribute prefix get
::method init
  expose prefix counter
  use strict arg prefix = "wlu"
  counter = 0
::method next
  expose prefix counter
  guard on
  counter += 1
  return prefix || "-" || .DateTime~new~microseconds || "-" || counter

::class WLUFact public
::attribute factType get
::attribute quantity get
::attribute source get
::attribute dimensions get

::method init
  expose factType quantity source dimensions
  use strict arg factType, quantity = 1, source = "", dimensionsArg = .nil
  factType = factType~string~strip~upper
  if factType = "" then raise syntax 88.900 array("WLU fact type must not be empty")
  if \datatype(quantity, "W") | quantity < 0 then raise syntax 88.900 array("WLU fact quantity must be a non-negative whole number")
  source = source~string
  dimensions = .table~new
  if dimensionsArg \== .nil then do
    supplier = dimensionsArg~supplier
    do while supplier~available
      dimensions[supplier~index~string] = supplier~item~string
      supplier~next
    end
  end

::class WLURateRule public
::attribute factType get
::attribute microWluNumerator get
::attribute quantityDenominator get
::attribute fixedMicroWlu get

::method init
  expose factType microWluNumerator quantityDenominator fixedMicroWlu
  use strict arg factType, microWluNumerator, quantityDenominator = 1, fixedMicroWlu = 0
  factType = factType~string~strip~upper
  if factType = "" then raise syntax 88.900 array("WLU rate rule fact type must not be empty")
  ignore = .WLUUnits~assertMicro(microWluNumerator)
  ignore = .WLUUnits~assertMicro(fixedMicroWlu)
  if \datatype(quantityDenominator, "W") | quantityDenominator < 1 then raise syntax 88.900 array("WLU rate rule denominator must be a positive whole number")

::method chargeMicroWlu
  expose microWluNumerator quantityDenominator fixedMicroWlu
  use strict arg quantity
  numeric digits 30
  if \datatype(quantity, "W") | quantity < 0 then raise syntax 88.900 array("WLU fact quantity must be a non-negative whole number")
  return fixedMicroWlu + .WLUUnits~ceilDivide(quantity * microWluNumerator, quantityDenominator)

::class WLUChargeLine public
::attribute factType get
::attribute quantity get
::attribute microWlu get

::method init
  expose factType quantity microWlu
  use strict arg factType, quantity, microWlu

::class WLUQuote public
::attribute rateCardId get
::attribute rateCardVersion get
::attribute microWlu get
::attribute lines get

::method init
  expose rateCardId rateCardVersion microWlu lines
  use strict arg rateCardId, rateCardVersion, microWlu, linesArg
  lines = .array~new
  do line over linesArg
    lines~append(line)
  end

::class WLURateCard public
::attribute rateCardId get
::attribute version get
::attribute sealed get

::method init
  expose rateCardId version rules sealed
  use strict arg rateCardId, version
  rateCardId = rateCardId~string~strip
  version = version~string~strip
  if rateCardId = "" | version = "" then raise syntax 88.900 array("WLU rate card id and version must not be empty")
  rules = .table~new
  sealed = .false

::method addRule
  expose rules sealed
  use strict arg rule
  if sealed then raise syntax 88.900 array("WLU rate card is sealed")
  if rule == .nil | \rule~isA(.WLURateRule) then raise syntax 88.900 array("WLU rate card requires WLURateRule objects")
  if rules~hasIndex(rule~factType) then raise syntax 88.900 array("Duplicate WLU rate rule for " || rule~factType)
  rules[rule~factType] = rule
  return self

::method seal
  expose sealed
  sealed = .true
  return self

::method quote
  expose rateCardId version rules sealed
  use strict arg facts
  numeric digits 30
  if \sealed then return .WLUResult~failure("WLU_RATE_CARD_UNSEALED", rateCardId || "/" || version)
  total = 0
  lines = .array~new
  do fact over facts
    if fact == .nil | \fact~isA(.WLUFact) then return .WLUResult~failure("WLU_INVALID_FACT", "Rate card accepts WLUFact objects only")
    rule = rules[fact~factType]
    if rule == .nil then return .WLUResult~failure("WLU_UNMETERED_FACT", "No explicit rate rule for " || fact~factType)
    charge = rule~chargeMicroWlu(fact~quantity)
    total += charge
    lines~append(.WLUChargeLine~new(fact~factType, fact~quantity, charge))
  end
  return .WLUResult~success(.WLUQuote~new(rateCardId, version, total, lines))

::class WLUWorkDemand public
::attribute expectedMicroWlu get
::attribute ceilingMicroWlu get
::attribute targetSeconds get
::attribute requestedRateMicroWluPerSecond get

::method init
  expose expectedMicroWlu ceilingMicroWlu targetSeconds requestedRateMicroWluPerSecond
  use strict arg expectedMicroWlu, ceilingMicroWlu = .nil, targetSeconds = 0, requestedRateMicroWluPerSecond = .nil
  numeric digits 30
  ignore = .WLUUnits~assertMicro(expectedMicroWlu)
  if expectedMicroWlu <= 0 then raise syntax 88.900 array("WLU demand expected work must be positive")
  if ceilingMicroWlu == .nil then ceilingMicroWlu = expectedMicroWlu
  ignore = .WLUUnits~assertMicro(ceilingMicroWlu)
  if ceilingMicroWlu < expectedMicroWlu then raise syntax 88.900 array("WLU demand ceiling must be >= expected work")
  if \datatype(targetSeconds, "W") | targetSeconds < 0 then raise syntax 88.900 array("WLU demand targetSeconds must be a non-negative whole number")
  if requestedRateMicroWluPerSecond == .nil then do
    if targetSeconds = 0 then requestedRateMicroWluPerSecond = 0
    else requestedRateMicroWluPerSecond = .WLUUnits~ceilDivide(expectedMicroWlu, targetSeconds)
  end
  ignore = .WLUUnits~assertMicro(requestedRateMicroWluPerSecond)
  if targetSeconds > 0 & requestedRateMicroWluPerSecond = 0 then raise syntax 88.900 array("WLU timed demand requires a positive delivery rate")

::method isAccelerated
  expose requestedRateMicroWluPerSecond
  return requestedRateMicroWluPerSecond > 0

::class WLUDemandAssessment public
::attribute identity get
::attribute scope get
::attribute expectedMicroWlu get
::attribute ceilingMicroWlu get
::attribute requestedRateMicroWluPerSecond get
::attribute entitlementAvailableMicroWlu get
::attribute entitlementShortfallMicroWlu get
::attribute deliveryAvailableRateMicroWluPerSecond get
::attribute deliveryShortfallRateMicroWluPerSecond get
::attribute limitingBucketIds get
::attribute limitingThroughputPoolIds get
::attribute retryAfterSeconds get

::method init
  expose identity scope expectedMicroWlu ceilingMicroWlu requestedRateMicroWluPerSecond entitlementAvailableMicroWlu entitlementShortfallMicroWlu deliveryAvailableRateMicroWluPerSecond deliveryShortfallRateMicroWluPerSecond limitingBucketIds limitingThroughputPoolIds retryAfterSeconds
  use strict arg identity, scope, expectedMicroWlu, ceilingMicroWlu, requestedRateMicroWluPerSecond, entitlementAvailableMicroWlu, entitlementShortfallMicroWlu, deliveryAvailableRateMicroWluPerSecond, deliveryShortfallRateMicroWluPerSecond, limitingBucketIdsArg, limitingThroughputPoolIdsArg, retryAfterSeconds = .nil
  limitingBucketIds = .array~new
  do id over limitingBucketIdsArg
    limitingBucketIds~append(id~string)
  end
  limitingThroughputPoolIds = .array~new
  do id over limitingThroughputPoolIdsArg
    limitingThroughputPoolIds~append(id~string)
  end

::method ready
  expose entitlementShortfallMicroWlu deliveryShortfallRateMicroWluPerSecond limitingBucketIds
  return entitlementShortfallMicroWlu = 0 & deliveryShortfallRateMicroWluPerSecond = 0 & limitingBucketIds~items = 0

::class WLUThroughputPool public
::attribute poolId get
::attribute capacityRateMicroWluPerSecond get
::attribute reservedRateMicroWluPerSecond get

::method init
  expose poolId capacityRateMicroWluPerSecond reservedRateMicroWluPerSecond
  use strict arg poolId, capacityRateMicroWluPerSecond
  poolId = poolId~string~strip
  if poolId = "" then raise syntax 88.900 array("WLU throughput pool id must not be empty")
  ignore = .WLUUnits~assertMicro(capacityRateMicroWluPerSecond)
  reservedRateMicroWluPerSecond = 0

::method availableRateMicroWluPerSecond
  expose capacityRateMicroWluPerSecond reservedRateMicroWluPerSecond
  numeric digits 30
  return capacityRateMicroWluPerSecond - reservedRateMicroWluPerSecond

::method canHoldRate
  use strict arg rateMicroWluPerSecond
  ignore = .WLUUnits~assertMicro(rateMicroWluPerSecond)
  return self~availableRateMicroWluPerSecond >= rateMicroWluPerSecond

::method holdRate
  expose reservedRateMicroWluPerSecond
  use strict arg rateMicroWluPerSecond
  guard on
  ignore = .WLUUnits~assertMicro(rateMicroWluPerSecond)
  if self~availableRateMicroWluPerSecond < rateMicroWluPerSecond then return .false
  reservedRateMicroWluPerSecond += rateMicroWluPerSecond
  return .true

::method releaseRate
  expose reservedRateMicroWluPerSecond
  use strict arg rateMicroWluPerSecond
  guard on
  ignore = .WLUUnits~assertMicro(rateMicroWluPerSecond)
  if rateMicroWluPerSecond > reservedRateMicroWluPerSecond then raise syntax 88.900 array("WLU throughput release exceeds reserved rate")
  reservedRateMicroWluPerSecond -= rateMicroWluPerSecond
  return reservedRateMicroWluPerSecond

::method increaseCapacityRate
  expose capacityRateMicroWluPerSecond
  use strict arg extraRateMicroWluPerSecond
  guard on
  ignore = .WLUUnits~assertMicro(extraRateMicroWluPerSecond)
  capacityRateMicroWluPerSecond += extraRateMicroWluPerSecond
  return capacityRateMicroWluPerSecond

::method setCapacityRate
  expose capacityRateMicroWluPerSecond reservedRateMicroWluPerSecond
  use strict arg newRateMicroWluPerSecond
  guard on
  ignore = .WLUUnits~assertMicro(newRateMicroWluPerSecond)
  if newRateMicroWluPerSecond < reservedRateMicroWluPerSecond then return .false
  capacityRateMicroWluPerSecond = newRateMicroWluPerSecond
  return .true

::class WLUAccount public
::attribute accountId get
::attribute grantedMicroWlu get
::attribute reservedMicroWlu get
::attribute spentMicroWlu get

::method init
  expose accountId grantedMicroWlu reservedMicroWlu spentMicroWlu
  use strict arg accountId, grantedMicroWlu
  accountId = accountId~string~strip
  if accountId = "" then raise syntax 88.900 array("WLU account id must not be empty")
  ignore = .WLUUnits~assertMicro(grantedMicroWlu)
  reservedMicroWlu = 0
  spentMicroWlu = 0

::method availableMicroWlu
  expose grantedMicroWlu reservedMicroWlu spentMicroWlu
  numeric digits 30
  return grantedMicroWlu - reservedMicroWlu - spentMicroWlu

::method canHold
  use strict arg amount
  ignore = .WLUUnits~assertMicro(amount)
  return self~availableMicroWlu >= amount

::method hold
  expose reservedMicroWlu
  use strict arg amount
  guard on
  ignore = .WLUUnits~assertMicro(amount)
  if self~availableMicroWlu < amount then return .false
  reservedMicroWlu += amount
  return .true

::method settleHold
  expose reservedMicroWlu spentMicroWlu
  use strict arg heldAmount, actualAmount
  guard on
  ignore = .WLUUnits~assertMicro(heldAmount)
  ignore = .WLUUnits~assertMicro(actualAmount)
  if actualAmount > heldAmount then raise syntax 88.900 array("WLU account settlement exceeds held amount")
  if heldAmount > reservedMicroWlu then raise syntax 88.900 array("WLU account settlement exceeds total reserved amount")
  reservedMicroWlu -= heldAmount
  spentMicroWlu += actualAmount
  return .true

::method grant
  expose grantedMicroWlu
  use strict arg amount
  guard on
  ignore = .WLUUnits~assertMicro(amount)
  grantedMicroWlu += amount
  return grantedMicroWlu

::class WLUCapacityBucket public
::attribute bucketId get
::attribute capacityMicroWlu get
::attribute refillMicroWluPerSecond get
::attribute tokensMicroWlu get

::method init
  expose bucketId capacityMicroWlu refillMicroWluPerSecond tokensMicroWlu lastTick refillRemainder
  use strict arg bucketId, capacityMicroWlu, refillMicroWluPerSecond = 0, startTick = 0
  bucketId = bucketId~string~strip
  if bucketId = "" then raise syntax 88.900 array("WLU capacity bucket id must not be empty")
  ignore = .WLUUnits~assertMicro(capacityMicroWlu)
  ignore = .WLUUnits~assertMicro(refillMicroWluPerSecond)
  tokensMicroWlu = capacityMicroWlu
  lastTick = startTick
  refillRemainder = 0

::method availableAt
  expose tokensMicroWlu
  use strict arg nowTick
  guard on
  ignore = self~refill(nowTick)
  return tokensMicroWlu

::method canHold
  use strict arg amount, nowTick
  ignore = .WLUUnits~assertMicro(amount)
  return self~availableAt(nowTick) >= amount

::method hold
  expose tokensMicroWlu
  use strict arg amount, nowTick
  guard on
  ignore = .WLUUnits~assertMicro(amount)
  ignore = self~refill(nowTick)
  if tokensMicroWlu < amount then return .false
  tokensMicroWlu -= amount
  return .true

::method settleHold
  expose capacityMicroWlu tokensMicroWlu
  use strict arg heldAmount, actualAmount, nowTick
  guard on
  ignore = .WLUUnits~assertMicro(heldAmount)
  ignore = .WLUUnits~assertMicro(actualAmount)
  if actualAmount > heldAmount then raise syntax 88.900 array("WLU capacity settlement exceeds held amount")
  ignore = self~refill(nowTick)
  refund = heldAmount - actualAmount
  tokensMicroWlu += refund
  if tokensMicroWlu > capacityMicroWlu then tokensMicroWlu = capacityMicroWlu
  return .true

::method retryAfterSeconds
  expose refillMicroWluPerSecond
  use strict arg amount, nowTick
  numeric digits 30
  ignore = .WLUUnits~assertMicro(amount)
  available = self~availableAt(nowTick)
  if available >= amount then return 0
  if refillMicroWluPerSecond = 0 then return .nil
  shortage = amount - available
  return .WLUUnits~ceilDivide(shortage, refillMicroWluPerSecond)

::method refill private
  expose capacityMicroWlu refillMicroWluPerSecond tokensMicroWlu lastTick refillRemainder
  use strict arg nowTick
  numeric digits 30
  if lastTick = 0 then do
    lastTick = nowTick
    return tokensMicroWlu
  end
  if nowTick <= lastTick then return tokensMicroWlu
  elapsed = nowTick - lastTick
  lastTick = nowTick
  if refillMicroWluPerSecond = 0 then return tokensMicroWlu
  numerator = elapsed * refillMicroWluPerSecond + refillRemainder
  added = numerator % 1000000
  refillRemainder = numerator // 1000000
  if added > 0 then do
    tokensMicroWlu += added
    if tokensMicroWlu >= capacityMicroWlu then do
      tokensMicroWlu = capacityMicroWlu
      refillRemainder = 0
    end
  end
  return tokensMicroWlu

::class WLUPolicyBinding public
::attribute identityPattern get
::attribute scopePattern get
::attribute targetId get

::method init
  expose identityPattern scopePattern targetId
  use strict arg identityPattern, scopePattern, targetId
  identityPattern = identityPattern~string~strip
  scopePattern = scopePattern~string~strip
  targetId = targetId~string~strip
  if identityPattern = "" | scopePattern = "" | targetId = "" then raise syntax 88.900 array("WLU policy binding fields must not be empty")

::method matches
  expose identityPattern scopePattern
  use strict arg identity, scope
  return self~matchesOne(identityPattern, identity~string) & self~matchesOne(scopePattern, scope~string)

::method specificity
  expose identityPattern scopePattern
  score = 0
  if identityPattern \= "*" then score += identityPattern~length
  if scopePattern \= "*" then score += scopePattern~length
  if identityPattern~right(1) \= "*" then score += 100000
  if scopePattern~right(1) \= "*" then score += 100000
  return score

::method matchesOne private
  use strict arg pattern, value
  if pattern = "*" then return .true
  if pattern~right(1) = "*" then return value~startsWith(pattern~left(pattern~length - 1))
  return pattern = value

::class WLUReservation public
::attribute reservationId get
::attribute identity get
::attribute accountId get
::attribute scope get
::attribute rateCardId get
::attribute rateCardVersion get
::attribute reservedMicroWlu get
::attribute issuedTick get
::attribute expiresTick get
::attribute bucketIds get
::attribute proofRevision get
::attribute proof get
::attribute expectedMicroWlu get
::attribute reservedRateMicroWluPerSecond get
::attribute throughputPoolIds get

::method init
  expose reservationId identity accountId scope rateCardId rateCardVersion reservedMicroWlu issuedTick expiresTick bucketIds proofRevision proof expectedMicroWlu reservedRateMicroWluPerSecond throughputPoolIds
  use strict arg reservationId, identity, accountId, scope, rateCardId, rateCardVersion, reservedMicroWlu, issuedTick, expiresTick, bucketIdsArg, proofRevision, proof, expectedMicroWlu = .nil, reservedRateMicroWluPerSecond = 0, throughputPoolIdsArg = .nil
  if expectedMicroWlu == .nil then expectedMicroWlu = reservedMicroWlu
  throughputPoolIds = .array~new
  if throughputPoolIdsArg \== .nil then do
    do poolId over throughputPoolIdsArg
      throughputPoolIds~append(poolId~string)
    end
  end
  bucketIds = .array~new
  do bucketId over bucketIdsArg
    bucketIds~append(bucketId~string)
  end

::method canonicalText
  expose reservationId identity accountId scope rateCardId rateCardVersion reservedMicroWlu issuedTick expiresTick bucketIds proofRevision expectedMicroWlu reservedRateMicroWluPerSecond throughputPoolIds
  text = "wlu.reservation/1" || "0a"x
  text ||= self~field("reservation-id", reservationId)
  text ||= self~field("identity", identity)
  text ||= self~field("account-id", accountId)
  text ||= self~field("scope", scope)
  text ||= self~field("rate-card-id", rateCardId)
  text ||= self~field("rate-card-version", rateCardVersion)
  text ||= self~field("reserved-micro-wlu", reservedMicroWlu)
  text ||= self~field("expected-micro-wlu", expectedMicroWlu)
  text ||= self~field("reserved-rate-micro-wlu-per-second", reservedRateMicroWluPerSecond)
  text ||= self~field("issued-tick", issuedTick)
  text ||= self~field("expires-tick", expiresTick)
  text ||= self~field("proof-revision", proofRevision)
  text ||= self~field("bucket-count", bucketIds~items)
  do bucketId over bucketIds
    text ||= self~field("bucket-id", bucketId)
  end
  text ||= self~field("throughput-pool-count", throughputPoolIds~items)
  do poolId over throughputPoolIds
    text ||= self~field("throughput-pool-id", poolId)
  end
  return text

::method field private
  use strict arg name, value
  value = value~string
  return name || ":" || value~length || ":" || value || "0a"x

::class WLUReservationRecord public
::attribute reservationId get
::attribute identity get
::attribute accountId get
::attribute scope get
::attribute rateCardId get
::attribute rateCardVersion get
::attribute reservedMicroWlu get
::attribute consumedMicroWlu get
::attribute actualMicroWlu get
::attribute issuedTick get
::attribute expiresTick get
::attribute bucketIds get
::attribute state get
::attribute proofRevision get
::attribute proof get
::attribute expectedMicroWlu get
::attribute reservedRateMicroWluPerSecond get
::attribute throughputPoolIds get

::method init
  expose reservationId identity accountId scope rateCardId rateCardVersion reservedMicroWlu consumedMicroWlu actualMicroWlu issuedTick expiresTick bucketIds state proofRevision proof expectedMicroWlu reservedRateMicroWluPerSecond throughputPoolIds
  use strict arg reservationId, identity, accountId, scope, rateCardId, rateCardVersion, reservedMicroWlu, issuedTick, expiresTick, bucketIdsArg, expectedMicroWlu = .nil, reservedRateMicroWluPerSecond = 0, throughputPoolIdsArg = .nil
  if expectedMicroWlu == .nil then expectedMicroWlu = reservedMicroWlu
  throughputPoolIds = .array~new
  if throughputPoolIdsArg \== .nil then do
    do poolId over throughputPoolIdsArg
      throughputPoolIds~append(poolId~string)
    end
  end
  consumedMicroWlu = 0
  actualMicroWlu = 0
  state = .WLUReservationState~ACTIVE
  proofRevision = 1
  proof = .nil
  bucketIds = .array~new
  do bucketId over bucketIdsArg
    bucketIds~append(bucketId~string)
  end

::method snapshot
  expose reservationId identity accountId scope rateCardId rateCardVersion reservedMicroWlu issuedTick expiresTick bucketIds proofRevision proof expectedMicroWlu reservedRateMicroWluPerSecond throughputPoolIds
  return .WLUReservation~new(reservationId, identity, accountId, scope, rateCardId, rateCardVersion, reservedMicroWlu, issuedTick, expiresTick, bucketIds, proofRevision, proof, expectedMicroWlu, reservedRateMicroWluPerSecond, throughputPoolIds)

::method refreshProof
  expose proof
  use strict arg keyRing
  snap = self~snapshot
  proof = keyRing~sign(snap~canonicalText)
  return self~snapshot

::method addConsumed
  expose consumedMicroWlu reservedMicroWlu
  use strict arg amount
  ignore = .WLUUnits~assertMicro(amount)
  if consumedMicroWlu + amount > reservedMicroWlu then return .false
  consumedMicroWlu += amount
  return .true

::method addReservation
  expose reservedMicroWlu proofRevision
  use strict arg amount
  reservedMicroWlu += amount
  proofRevision += 1
  return reservedMicroWlu

::method setDeliveryRate
  expose reservedRateMicroWluPerSecond proofRevision
  use strict arg newRateMicroWluPerSecond
  ignore = .WLUUnits~assertMicro(newRateMicroWluPerSecond)
  reservedRateMicroWluPerSecond = newRateMicroWluPerSecond
  proofRevision += 1
  return reservedRateMicroWluPerSecond

::method close
  expose state actualMicroWlu
  use strict arg newState, actual
  state = newState
  actualMicroWlu = actual
  return state

::class WLULedgerEvent public
::attribute sequence get
::attribute tick get
::attribute eventType get
::attribute reservationId get
::attribute identity get
::attribute accountId get
::attribute scope get
::attribute microWlu get
::attribute detail get

::method init
  expose sequence tick eventType reservationId identity accountId scope microWlu detail
  use strict arg sequence, tick, eventType, reservationId = "", identity = "", accountId = "", scope = "", microWlu = 0, detail = ""

::method canonicalText
  expose sequence tick eventType reservationId identity accountId scope microWlu detail
  values = .array~of(sequence, tick, eventType, reservationId, identity, accountId, scope, microWlu, detail)
  names = .array~of("sequence", "tick", "event-type", "reservation-id", "identity", "account-id", "scope", "micro-wlu", "detail")
  text = "wlu.ledger.event/1" || "0a"x
  do i = 1 to names~items
    value = values[i]~string
    text ||= names[i] || ":" || value~length || ":" || value || "0a"x
  end
  return text

::class WLUMemoryLedger public
::attribute events get
::method init
  expose events sequence
  events = .array~new
  sequence = 0
::method append
  expose events sequence
  use strict arg tick, eventType, reservationId = "", identity = "", accountId = "", scope = "", microWlu = 0, detail = ""
  guard on
  sequence += 1
  event = .WLULedgerEvent~new(sequence, tick, eventType, reservationId, identity, accountId, scope, microWlu, detail)
  events~append(event)
  return event
::method count
  expose events
  return events~items

::class WLUAuthority public
::attribute apiVersion get
::attribute ledger get
::attribute keyRing get
::attribute clock get

::method init
  expose apiVersion accounts buckets throughputPools rateCards accountBindings bucketBindings throughputBindings rateCardBindings reservations idempotency operations keyRing ledger clock idGenerator
  use strict arg keyRing, ledger = .nil, clock = .nil
  if keyRing == .nil | \keyRing~isA(.WLUFastMacKeyRing) then raise syntax 88.900 array("WLUAuthority requires WLUFastMacKeyRing")
  if ledger == .nil then ledger = .WLUMemoryLedger~new
  if clock == .nil then clock = .WLUTimeSource~new
  apiVersion = .WLUDBuild~API_VERSION
  accounts = .table~new
  buckets = .table~new
  throughputPools = .table~new
  rateCards = .table~new
  accountBindings = .array~new
  bucketBindings = .array~new
  throughputBindings = .array~new
  rateCardBindings = .array~new
  reservations = .table~new
  idempotency = .table~new
  operations = .table~new
  idGenerator = .WLUIdGenerator~new("wlu-res")

::method addAccount
  expose accounts
  use strict arg account
  guard on
  if account == .nil | \account~isA(.WLUAccount) then raise syntax 88.900 array("WLUAuthority accepts WLUAccount objects")
  if accounts~hasIndex(account~accountId) then raise syntax 88.900 array("Duplicate WLU account: " || account~accountId)
  accounts[account~accountId] = account
  return account

::method addBucket
  expose buckets clock
  use strict arg bucket
  guard on
  if bucket == .nil | \bucket~isA(.WLUCapacityBucket) then raise syntax 88.900 array("WLUAuthority accepts WLUCapacityBucket objects")
  if buckets~hasIndex(bucket~bucketId) then raise syntax 88.900 array("Duplicate WLU capacity bucket: " || bucket~bucketId)
  buckets[bucket~bucketId] = bucket
  return bucket

::method addThroughputPool
  expose throughputPools
  use strict arg pool
  guard on
  if pool == .nil | \pool~isA(.WLUThroughputPool) then raise syntax 88.900 array("WLUAuthority accepts WLUThroughputPool objects")
  if throughputPools~hasIndex(pool~poolId) then raise syntax 88.900 array("Duplicate WLU throughput pool: " || pool~poolId)
  throughputPools[pool~poolId] = pool
  return pool

::method bindThroughputPool
  expose throughputPools throughputBindings
  use strict arg identityPattern, scopePattern, poolId
  guard on
  poolId = poolId~string~strip
  if \throughputPools~hasIndex(poolId) then raise syntax 88.900 array("Cannot bind unknown WLU throughput pool: " || poolId)
  throughputBindings~append(.WLUPolicyBinding~new(identityPattern, scopePattern, poolId))
  return .true

::method assessDemand
  expose accounts buckets throughputPools clock
  use strict arg identity, scope, demand
  guard on
  numeric digits 30
  identity = identity~string~strip
  scope = scope~string~strip
  if demand == .nil | \demand~isA(.WLUWorkDemand) then return .WLUResult~failure("WLU_DEMAND_REQUIRED", "assessDemand requires WLUWorkDemand")
  nowTick = clock~nowTick
  ignore = self~expireDueAt(nowTick)

  accountResolution = self~resolveAccount(identity, scope)
  if \accountResolution~ok then return accountResolution
  account = accountResolution~value
  entitlementAvailable = account~availableMicroWlu
  entitlementShortfall = 0
  if entitlementAvailable < demand~ceilingMicroWlu then entitlementShortfall = demand~ceilingMicroWlu - entitlementAvailable

  limitingBuckets = .array~new
  retryAfter = 0
  retryKnown = .true
  bucketResolution = self~resolveBuckets(identity, scope)
  if \bucketResolution~ok then return bucketResolution
  do bucketId over bucketResolution~value
    bucket = buckets[bucketId]
    if \bucket~canHold(demand~ceilingMicroWlu, nowTick) then do
      limitingBuckets~append(bucketId)
      retry = bucket~retryAfterSeconds(demand~ceilingMicroWlu, nowTick)
      if retry == .nil then retryKnown = .false
      else if retry > retryAfter then retryAfter = retry
    end
  end

  limitingPools = .array~new
  throughputResolution = self~resolveThroughputPools(identity, scope)
  if \throughputResolution~ok then return throughputResolution
  targetRate = demand~requestedRateMicroWluPerSecond
  availableRate = targetRate
  if throughputResolution~value~items > 0 then do
    availableRate = .nil
    do poolId over throughputResolution~value
      pool = throughputPools[poolId]
      poolAvailable = pool~availableRateMicroWluPerSecond
      if availableRate == .nil | poolAvailable < availableRate then availableRate = poolAvailable
      if poolAvailable < targetRate then limitingPools~append(poolId)
    end
  end
  if availableRate == .nil then availableRate = targetRate
  deliveryShortfall = 0
  if availableRate < targetRate then deliveryShortfall = targetRate - availableRate
  if retryKnown then retryValue = retryAfter
  else retryValue = .nil
  assessment = .WLUDemandAssessment~new(identity, scope, demand~expectedMicroWlu, demand~ceilingMicroWlu, targetRate, entitlementAvailable, entitlementShortfall, availableRate, deliveryShortfall, limitingBuckets, limitingPools, retryValue)
  return .WLUResult~success(assessment)

::method reserveDemand
  use strict arg identity, scope, demand, ttlSeconds = 30, requestId = "", rateCardId = "DIRECT", rateCardVersion = "1"
  if demand == .nil | \demand~isA(.WLUWorkDemand) then return .WLUResult~failure("WLU_DEMAND_REQUIRED", "reserveDemand requires WLUWorkDemand")
  assessmentResult = self~assessDemand(identity, scope, demand)
  if \assessmentResult~ok then return assessmentResult
  assessment = assessmentResult~value
  if assessment~entitlementShortfallMicroWlu > 0 then return .WLUResult~failure("WLU_ENTITLEMENT_EXHAUSTED", "work ceiling exceeds available entitlement", assessment)
  if assessment~limitingBucketIds~items > 0 then return .WLUResult~failure("WLU_CAPACITY_EXHAUSTED", "work ceiling exceeds temporary token/burst capacity", assessment, assessment~retryAfterSeconds)
  if assessment~deliveryShortfallRateMicroWluPerSecond > 0 then return .WLUResult~failure("WLU_THROUGHPUT_EXHAUSTED", "requested delivery rate exceeds currently reservable throughput", assessment)
  return self~reserve(identity, scope, demand~ceilingMicroWlu, ttlSeconds, requestId, rateCardId, rateCardVersion, demand~expectedMicroWlu, demand~requestedRateMicroWluPerSecond)

::method addRateCard
  expose rateCards
  use strict arg rateCard
  guard on
  if rateCard == .nil | \rateCard~isA(.WLURateCard) then raise syntax 88.900 array("WLUAuthority accepts WLURateCard objects")
  if \rateCard~sealed then raise syntax 88.900 array("WLUAuthority accepts only sealed rate cards")
  key = self~rateCardKey(rateCard~rateCardId, rateCard~version)
  if rateCards~hasIndex(key) then raise syntax 88.900 array("Duplicate WLU rate card: " || key)
  rateCards[key] = rateCard
  return rateCard

::method bindRateCard
  expose rateCards rateCardBindings
  use strict arg identityPattern, scopePattern, rateCardId, rateCardVersion
  guard on
  key = self~rateCardKey(rateCardId, rateCardVersion)
  if \rateCards~hasIndex(key) then raise syntax 88.900 array("Cannot bind unknown WLU rate card: " || key)
  replacement = .WLUPolicyBinding~new(identityPattern, scopePattern, key)
  do i = 1 to rateCardBindings~items
    existing = rateCardBindings[i]
    if existing~identityPattern = replacement~identityPattern & existing~scopePattern = replacement~scopePattern then do
      rateCardBindings[i] = replacement
      return .true
    end
  end
  rateCardBindings~append(replacement)
  return .true

::method quoteFacts
  use strict arg identity, scope, facts
  guard on
  resolution = self~resolveRateCard(identity~string~strip, scope~string~strip)
  if \resolution~ok then return resolution
  return resolution~value~quote(facts)

::method reserveFacts
  use strict arg identity, scope, facts, ttlSeconds = 30, requestId = ""
  quoted = self~quoteFacts(identity, scope, facts)
  if \quoted~ok then return quoted
  quote = quoted~value
  return self~reserve(identity, scope, quote~microWlu, ttlSeconds, requestId, quote~rateCardId, quote~rateCardVersion)

::method bindAccount
  expose accounts accountBindings
  use strict arg identityPattern, scopePattern, accountId
  guard on
  accountId = accountId~string~strip
  if \accounts~hasIndex(accountId) then raise syntax 88.900 array("Cannot bind unknown WLU account: " || accountId)
  replacement = .WLUPolicyBinding~new(identityPattern, scopePattern, accountId)
  do i = 1 to accountBindings~items
    existing = accountBindings[i]
    if existing~identityPattern = replacement~identityPattern & existing~scopePattern = replacement~scopePattern then do
      accountBindings[i] = replacement
      return .true
    end
  end
  accountBindings~append(replacement)
  return .true

::method bindBucket
  expose buckets bucketBindings
  use strict arg identityPattern, scopePattern, bucketId
  guard on
  bucketId = bucketId~string~strip
  if \buckets~hasIndex(bucketId) then raise syntax 88.900 array("Cannot bind unknown WLU capacity bucket: " || bucketId)
  bucketBindings~append(.WLUPolicyBinding~new(identityPattern, scopePattern, bucketId))
  return .true

::method reserve
  expose accounts buckets throughputPools reservations idempotency keyRing ledger clock idGenerator
  use strict arg identity, scope, microWlu, ttlSeconds = 30, requestId = "", rateCardId = "DIRECT", rateCardVersion = "1", expectedMicroWlu = .nil, requestedRateMicroWluPerSecond = 0
  guard on
  numeric digits 30
  identity = identity~string~strip
  scope = scope~string~strip
  requestId = requestId~string~strip
  rateCardId = rateCardId~string~strip
  rateCardVersion = rateCardVersion~string~strip
  if identity = "" then return .WLUResult~failure("WLU_IDENTITY_REQUIRED", "identity must not be empty")
  if scope = "" then return .WLUResult~failure("WLU_SCOPE_REQUIRED", "scope must not be empty")
  if rateCardId = "" | rateCardVersion = "" then return .WLUResult~failure("WLU_RATE_CARD_REQUIRED", "rate card id/version must not be empty")
  if \datatype(microWlu, "W") | microWlu <= 0 then return .WLUResult~failure("WLU_INVALID_AMOUNT", "reservation amount must be a positive micro-WLU integer")
  if expectedMicroWlu == .nil then expectedMicroWlu = microWlu
  if \datatype(expectedMicroWlu, "W") | expectedMicroWlu <= 0 | expectedMicroWlu > microWlu then return .WLUResult~failure("WLU_INVALID_EXPECTATION", "expected WLU must be positive and no greater than reservation ceiling")
  if \datatype(requestedRateMicroWluPerSecond, "W") | requestedRateMicroWluPerSecond < 0 then return .WLUResult~failure("WLU_INVALID_DELIVERY_RATE", "requested delivery rate must be non-negative micro-WLU/second")
  if \datatype(ttlSeconds, "W") | ttlSeconds < 0 then return .WLUResult~failure("WLU_INVALID_TTL", "TTL must be a non-negative whole number")
  nowTick = clock~nowTick
  ignore = self~expireDueAt(nowTick)

  if requestId \= "" & idempotency~hasIndex(requestId) then do
    prior = idempotency[requestId]
    expected = identity || "0a"x || scope || "0a"x || microWlu || "0a"x || rateCardId || "0a"x || rateCardVersion || "0a"x || expectedMicroWlu || "0a"x || requestedRateMicroWluPerSecond
    if prior[1] \= expected then return .WLUResult~failure("WLU_IDEMPOTENCY_CONFLICT", "requestId was already used with different reservation parameters")
    record = reservations[prior[2]]
    if record == .nil then return .WLUResult~failure("WLU_IDEMPOTENCY_BROKEN", "idempotent reservation record is unavailable")
    return .WLUResult~success(record~snapshot, "idempotent replay")
  end

  accountResolution = self~resolveAccount(identity, scope)
  if \accountResolution~ok then do
    ignore = self~audit(nowTick, "DENY", "", identity, "", scope, microWlu, accountResolution~code)
    return accountResolution
  end
  account = accountResolution~value
  if \account~canHold(microWlu) then do
    detail = "account=" || account~accountId || " available=" || account~availableMicroWlu || " requested=" || microWlu
    ignore = self~audit(nowTick, "DENY", "", identity, account~accountId, scope, microWlu, "WLU_ENTITLEMENT_EXHAUSTED")
    return .WLUResult~failure("WLU_ENTITLEMENT_EXHAUSTED", detail)
  end

  bucketResolution = self~resolveBuckets(identity, scope)
  if \bucketResolution~ok then return bucketResolution
  bucketIds = bucketResolution~value
  retryAfter = 0
  retryKnown = .true
  do bucketId over bucketIds
    bucket = buckets[bucketId]
    if \bucket~canHold(microWlu, nowTick) then do
      retry = bucket~retryAfterSeconds(microWlu, nowTick)
      if retry == .nil then retryKnown = .false
      else if retry > retryAfter then retryAfter = retry
      detail = "bucket=" || bucketId || " available=" || bucket~availableAt(nowTick) || " requested=" || microWlu
      ignore = self~audit(nowTick, "DENY", "", identity, account~accountId, scope, microWlu, "WLU_CAPACITY_EXHAUSTED:" || bucketId)
      if retryKnown then return .WLUResult~failure("WLU_CAPACITY_EXHAUSTED", detail, .nil, retryAfter)
      return .WLUResult~failure("WLU_CAPACITY_EXHAUSTED", detail)
    end
  end

  throughputResolution = self~resolveThroughputPools(identity, scope)
  if \throughputResolution~ok then return throughputResolution
  throughputPoolIds = throughputResolution~value
  do poolId over throughputPoolIds
    pool = throughputPools[poolId]
    if \pool~canHoldRate(requestedRateMicroWluPerSecond) then do
      detail = "pool=" || poolId || " available-rate=" || pool~availableRateMicroWluPerSecond || " requested-rate=" || requestedRateMicroWluPerSecond
      ignore = self~audit(nowTick, "DENY", "", identity, account~accountId, scope, microWlu, "WLU_THROUGHPUT_EXHAUSTED:" || poolId)
      return .WLUResult~failure("WLU_THROUGHPUT_EXHAUSTED", detail)
    end
  end

  /* All policy checks are complete before the first hold mutates accounting. */
  if \account~hold(microWlu) then return .WLUResult~failure("WLU_ATOMICITY_FAILURE", "account changed during serialized reservation")
  heldBuckets = .array~new
  do bucketId over bucketIds
    bucket = buckets[bucketId]
    if \bucket~hold(microWlu, nowTick) then do
      /* This path should be unreachable while authority guard is held. */
      do heldId over heldBuckets
        ignore = buckets[heldId]~settleHold(microWlu, 0, nowTick)
      end
      ignore = account~settleHold(microWlu, 0)
      return .WLUResult~failure("WLU_ATOMICITY_FAILURE", "capacity changed during serialized reservation")
    end
    heldBuckets~append(bucketId)
  end

  heldThroughputPools = .array~new
  do poolId over throughputPoolIds
    pool = throughputPools[poolId]
    if \pool~holdRate(requestedRateMicroWluPerSecond) then do
      do heldPoolId over heldThroughputPools
        ignore = throughputPools[heldPoolId]~releaseRate(requestedRateMicroWluPerSecond)
      end
      do heldId over heldBuckets
        ignore = buckets[heldId]~settleHold(microWlu, 0, nowTick)
      end
      ignore = account~settleHold(microWlu, 0)
      return .WLUResult~failure("WLU_ATOMICITY_FAILURE", "throughput changed during serialized reservation")
    end
    heldThroughputPools~append(poolId)
  end

  expiresTick = 0
  if ttlSeconds > 0 then expiresTick = clock~addSeconds(nowTick, ttlSeconds)
  reservationId = idGenerator~next
  record = .WLUReservationRecord~new(reservationId, identity, account~accountId, scope, rateCardId, rateCardVersion, microWlu, nowTick, expiresTick, bucketIds, expectedMicroWlu, requestedRateMicroWluPerSecond, throughputPoolIds)
  snapshot = record~refreshProof(keyRing)
  reservations[reservationId] = record
  if requestId \= "" then idempotency[requestId] = .array~of(identity || "0a"x || scope || "0a"x || microWlu || "0a"x || rateCardId || "0a"x || rateCardVersion || "0a"x || expectedMicroWlu || "0a"x || requestedRateMicroWluPerSecond, reservationId)
  ignore = self~audit(nowTick, "RESERVE", reservationId, identity, account~accountId, scope, microWlu, "")
  return .WLUResult~success(snapshot)

::method admit
  expose clock
  use strict arg reservation
  guard on
  nowTick = clock~nowTick
  validated = self~validateActive(reservation, nowTick)
  if \validated~ok then return validated
  return .WLUResult~success(validated~value~snapshot, "reservation admitted")

::method consume
  expose operations ledger clock
  use strict arg reservation, microWlu, operationId = ""
  guard on
  if \datatype(microWlu, "W") | microWlu < 0 then return .WLUResult~failure("WLU_INVALID_AMOUNT", "consumption must be non-negative micro-WLU")
  operationId = operationId~string~strip
  nowTick = clock~nowTick
  validated = self~validateActive(reservation, nowTick)
  if \validated~ok then return validated
  record = validated~value
  if operationId \= "" then do
    opKey = record~reservationId || "|CONSUME|" || operationId
    if operations~hasIndex(opKey) then do
      prior = operations[opKey]
      if prior[1] \= microWlu then return .WLUResult~failure("WLU_IDEMPOTENCY_CONFLICT", "consume operationId reused with a different amount")
      return .WLUResult~success(record~snapshot, "idempotent consume replay")
    end
  end
  if \record~addConsumed(microWlu) then return .WLUResult~failure("WLU_RESERVATION_EXCEEDED", "consumption would exceed reserved WLU")
  if operationId \= "" then operations[opKey] = .array~of(microWlu)
  ignore = self~audit(nowTick, "CONSUME", record~reservationId, record~identity, record~accountId, record~scope, microWlu, operationId)
  return .WLUResult~success(record~snapshot)

::method consumeFacts
  expose rateCards
  use strict arg reservation, facts, operationId = ""
  guard on
  nowTick = self~clock~nowTick
  validated = self~validateActive(reservation, nowTick)
  if \validated~ok then return validated
  record = validated~value
  key = self~rateCardKey(record~rateCardId, record~rateCardVersion)
  card = rateCards[key]
  if card == .nil then return .WLUResult~failure("WLU_RATE_CARD_NOT_FOUND", key)
  quoted = card~quote(facts)
  if \quoted~ok then return quoted
  return self~consume(reservation, quoted~value~microWlu, operationId)

::method topUp
  expose accounts buckets keyRing clock
  use strict arg reservation, extraMicroWlu
  guard on
  if \datatype(extraMicroWlu, "W") | extraMicroWlu <= 0 then return .WLUResult~failure("WLU_INVALID_AMOUNT", "top-up must be positive micro-WLU")
  nowTick = clock~nowTick
  validated = self~validateActive(reservation, nowTick)
  if \validated~ok then return validated
  record = validated~value
  account = accounts[record~accountId]
  if \account~canHold(extraMicroWlu) then return .WLUResult~failure("WLU_ENTITLEMENT_EXHAUSTED", "account cannot fund reservation top-up")
  do bucketId over record~bucketIds
    bucket = buckets[bucketId]
    if \bucket~canHold(extraMicroWlu, nowTick) then do
      retry = bucket~retryAfterSeconds(extraMicroWlu, nowTick)
      return .WLUResult~failure("WLU_CAPACITY_EXHAUSTED", "bucket cannot fund reservation top-up: " || bucketId, .nil, retry)
    end
  end
  ignore = account~hold(extraMicroWlu)
  do bucketId over record~bucketIds
    ignore = buckets[bucketId]~hold(extraMicroWlu, nowTick)
  end
  ignore = record~addReservation(extraMicroWlu)
  snapshot = record~refreshProof(keyRing)
  ignore = self~audit(nowTick, "TOPUP", record~reservationId, record~identity, record~accountId, record~scope, extraMicroWlu, "")
  return .WLUResult~success(snapshot)

::method changeDeliveryRate
  expose throughputPools keyRing clock
  use strict arg reservation, newRateMicroWluPerSecond
  guard on
  if \datatype(newRateMicroWluPerSecond, "W") | newRateMicroWluPerSecond < 0 then return .WLUResult~failure("WLU_INVALID_DELIVERY_RATE", "delivery rate must be non-negative micro-WLU/second")
  nowTick = clock~nowTick
  validated = self~validateActive(reservation, nowTick)
  if \validated~ok then return validated
  record = validated~value
  oldRate = record~reservedRateMicroWluPerSecond
  if newRateMicroWluPerSecond = oldRate then return .WLUResult~success(record~snapshot, "delivery rate unchanged")
  if newRateMicroWluPerSecond > oldRate then do
    delta = newRateMicroWluPerSecond - oldRate
    do poolId over record~throughputPoolIds
      pool = throughputPools[poolId]
      if \pool~canHoldRate(delta) then return .WLUResult~failure("WLU_THROUGHPUT_EXHAUSTED", "cannot accelerate; pool=" || poolId || " shortfall-rate=" || (delta - pool~availableRateMicroWluPerSecond))
    end
    held = .array~new
    do poolId over record~throughputPoolIds
      if \throughputPools[poolId]~holdRate(delta) then do
        do heldId over held
          ignore = throughputPools[heldId]~releaseRate(delta)
        end
        return .WLUResult~failure("WLU_ATOMICITY_FAILURE", "throughput changed during serialized acceleration")
      end
      held~append(poolId)
    end
  end
  else do
    delta = oldRate - newRateMicroWluPerSecond
    do poolId over record~throughputPoolIds
      ignore = throughputPools[poolId]~releaseRate(delta)
    end
  end
  ignore = record~setDeliveryRate(newRateMicroWluPerSecond)
  snapshot = record~refreshProof(keyRing)
  ignore = self~audit(nowTick, "DELIVERY_RATE", record~reservationId, record~identity, record~accountId, record~scope, 0, "old-rate=" || oldRate || " new-rate=" || newRateMicroWluPerSecond)
  return .WLUResult~success(snapshot)

::method settle
  expose clock
  use strict arg reservation, actualMicroWlu = .nil
  guard on
  nowTick = clock~nowTick
  validated = self~validateActive(reservation, nowTick)
  if \validated~ok then return validated
  record = validated~value
  if actualMicroWlu == .nil then actualMicroWlu = record~consumedMicroWlu
  if \datatype(actualMicroWlu, "W") | actualMicroWlu < 0 then return .WLUResult~failure("WLU_INVALID_AMOUNT", "settlement amount must be non-negative micro-WLU")
  if actualMicroWlu > record~reservedMicroWlu then return .WLUResult~failure("WLU_SETTLEMENT_EXCEEDS_RESERVATION", "top up the reservation before settling a larger actual amount")
  if actualMicroWlu < record~consumedMicroWlu then return .WLUResult~failure("WLU_SETTLEMENT_BELOW_CONSUMED", "settlement cannot be lower than already recorded consumption")
  return self~closeRecord(record, .WLUReservationState~SETTLED, actualMicroWlu, nowTick)

::method settleFacts
  expose rateCards clock
  use strict arg reservation, facts
  guard on
  nowTick = clock~nowTick
  validated = self~validateActive(reservation, nowTick)
  if \validated~ok then return validated
  record = validated~value
  key = self~rateCardKey(record~rateCardId, record~rateCardVersion)
  card = rateCards[key]
  if card == .nil then return .WLUResult~failure("WLU_RATE_CARD_NOT_FOUND", key)
  quoted = card~quote(facts)
  if \quoted~ok then return quoted
  return self~settle(reservation, quoted~value~microWlu)

::method release
  expose clock
  use strict arg reservation
  guard on
  nowTick = clock~nowTick
  validated = self~validateActive(reservation, nowTick)
  if \validated~ok then return validated
  record = validated~value
  /* Work already recorded as consumed is never refunded merely because the
   * unused remainder is being released. */
  return self~closeRecord(record, .WLUReservationState~RELEASED, record~consumedMicroWlu, nowTick)

::method reservationConsumed
  expose clock
  use strict arg reservation
  guard on
  nowTick = clock~nowTick
  validated = self~validateActive(reservation, nowTick)
  if \validated~ok then return validated
  return .WLUResult~success(validated~value~consumedMicroWlu)

::method reservationState
  expose reservations clock
  use strict arg reservationId
  guard on
  nowTick = clock~nowTick
  ignore = self~expireDueAt(nowTick)
  record = reservations[reservationId~string]
  if record == .nil then return .WLUResult~failure("WLU_RESERVATION_NOT_FOUND", reservationId~string)
  return .WLUResult~success(record~state)

::method accountFor
  expose accounts
  use strict arg identity, scope
  guard on
  resolved = self~resolveAccount(identity~string, scope~string)
  if \resolved~ok then return resolved
  return .WLUResult~success(resolved~value)

::method expireDue
  expose clock
  guard on
  return self~expireDueAt(clock~nowTick)

::method validateActive private
  expose reservations keyRing
  use strict arg reservation, nowTick
  if reservation == .nil | \reservation~isA(.WLUReservation) then return .WLUResult~failure("WLU_RESERVATION_REQUIRED", "a WLUReservation proof is required")
  record = reservations[reservation~reservationId]
  if record == .nil then return .WLUResult~failure("WLU_RESERVATION_NOT_FOUND", reservation~reservationId)
  if \keyRing~verify(reservation~canonicalText, reservation~proof) then return .WLUResult~failure("WLU_RESERVATION_PROOF_INVALID", "reservation authentication failed")
  if reservation~proofRevision \= record~proofRevision then return .WLUResult~failure("WLU_RESERVATION_STALE", "reservation proof revision is no longer current")
  if reservation~reservedMicroWlu \= record~reservedMicroWlu then return .WLUResult~failure("WLU_RESERVATION_STALE", "reservation amount no longer matches authority state")
  if record~state \= .WLUReservationState~ACTIVE then return .WLUResult~failure("WLU_RESERVATION_NOT_ACTIVE", record~state)
  if record~expiresTick \= 0 & nowTick >= record~expiresTick then do
    ignore = self~expireOne(record, nowTick)
    return .WLUResult~failure("WLU_RESERVATION_EXPIRED", "reservation expired before admission")
  end
  return .WLUResult~success(record)

::method closeRecord private
  expose accounts buckets throughputPools
  use strict arg record, newState, actualMicroWlu, nowTick
  held = record~reservedMicroWlu
  account = accounts[record~accountId]
  ignore = account~settleHold(held, actualMicroWlu)
  do bucketId over record~bucketIds
    ignore = buckets[bucketId]~settleHold(held, actualMicroWlu, nowTick)
  end
  do poolId over record~throughputPoolIds
    ignore = throughputPools[poolId]~releaseRate(record~reservedRateMicroWluPerSecond)
  end
  ignore = record~close(newState, actualMicroWlu)
  ignore = self~audit(nowTick, newState, record~reservationId, record~identity, record~accountId, record~scope, actualMicroWlu, "reserved=" || held)
  return .WLUResult~success(record~state)

::method expireOne private
  use strict arg record, nowTick
  if record~state \= .WLUReservationState~ACTIVE then return .false
  /* Expiry settles work already observed and refunds only unused reservation. */
  ignore = self~closeRecord(record, .WLUReservationState~EXPIRED, record~consumedMicroWlu, nowTick)
  return .true

::method expireDueAt private
  expose reservations
  use strict arg nowTick
  expired = 0
  supplier = reservations~supplier
  do while supplier~available
    record = supplier~item
    if record~state = .WLUReservationState~ACTIVE then do
      if record~expiresTick \= 0 & nowTick >= record~expiresTick then do
        if self~expireOne(record, nowTick) then expired += 1
      end
    end
    supplier~next
  end
  return expired

::method resolveAccount private
  expose accounts accountBindings
  use strict arg identity, scope
  best = .nil
  bestScore = -1
  ambiguous = .false
  do binding over accountBindings
    if \binding~matches(identity, scope) then iterate
    score = binding~specificity
    if score > bestScore then do
      best = binding
      bestScore = score
      ambiguous = .false
    end
    else if score = bestScore then do
      if best \== .nil & binding~targetId \= best~targetId then ambiguous = .true
    end
  end
  if ambiguous then return .WLUResult~failure("WLU_POLICY_AMBIGUOUS", "more than one equally specific account binding applies")
  if best == .nil then return .WLUResult~failure("WLU_ACCOUNT_NOT_BOUND", identity || " @ " || scope)
  account = accounts[best~targetId]
  if account == .nil then return .WLUResult~failure("WLU_ACCOUNT_NOT_FOUND", best~targetId)
  return .WLUResult~success(account)

::method resolveRateCard private
  expose rateCards rateCardBindings
  use strict arg identity, scope
  best = .nil
  bestScore = -1
  ambiguous = .false
  do binding over rateCardBindings
    if \binding~matches(identity, scope) then iterate
    score = binding~specificity
    if score > bestScore then do
      best = binding
      bestScore = score
      ambiguous = .false
    end
    else if score = bestScore then do
      if best \== .nil & binding~targetId \= best~targetId then ambiguous = .true
    end
  end
  if ambiguous then return .WLUResult~failure("WLU_POLICY_AMBIGUOUS", "more than one equally specific rate-card binding applies")
  if best == .nil then return .WLUResult~failure("WLU_RATE_CARD_NOT_BOUND", identity || " @ " || scope)
  card = rateCards[best~targetId]
  if card == .nil then return .WLUResult~failure("WLU_RATE_CARD_NOT_FOUND", best~targetId)
  return .WLUResult~success(card)

::method rateCardKey private
  use strict arg rateCardId, rateCardVersion
  return rateCardId~string~strip || "@" || rateCardVersion~string~strip

::method resolveBuckets private
  expose buckets bucketBindings
  use strict arg identity, scope
  ids = .array~new
  seen = .table~new
  do binding over bucketBindings
    if \binding~matches(identity, scope) then iterate
    bucketId = binding~targetId
    if seen~hasIndex(bucketId) then iterate
    if \buckets~hasIndex(bucketId) then return .WLUResult~failure("WLU_BUCKET_NOT_FOUND", bucketId)
    seen[bucketId] = .true
    ids~append(bucketId)
  end
  return .WLUResult~success(ids)

::method resolveThroughputPools private
  expose throughputPools throughputBindings
  use strict arg identity, scope
  ids = .array~new
  seen = .table~new
  do binding over throughputBindings
    if \binding~matches(identity, scope) then iterate
    poolId = binding~targetId
    if seen~hasIndex(poolId) then iterate
    if \throughputPools~hasIndex(poolId) then return .WLUResult~failure("WLU_THROUGHPUT_POOL_NOT_FOUND", poolId)
    seen[poolId] = .true
    ids~append(poolId)
  end
  return .WLUResult~success(ids)

::method audit private
  expose ledger
  use strict arg tick, eventType, reservationId, identity, accountId, scope, microWlu, detail
  if ledger == .nil then return .nil
  return ledger~append(tick, eventType, reservationId, identity, accountId, scope, microWlu, detail)

::requires "WLUFastMac.cls"
