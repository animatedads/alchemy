/* Enterprise WLU scheduling example: same work, different delivery demand. */
MICRO = 1000000
keys = .WLUFastMacKeyRing~new
ignore = keys~addKey("example-hot", "000102030405060708090a0b0c0d0e0f")
auth = .WLUAuthority~new(keys)

account = .WLUAccount~new("enterprise-ai", 100 * MICRO)
auth~addAccount(account)
auth~bindAccount("AI_*", "AI:*", account~accountId)

pool = .WLUThroughputPool~new("ai-throughput", 3 * MICRO)
auth~addThroughputPool(pool)
auth~bindThroughputPool("AI_*", "AI:*", pool~poolId)

/* 12 WLU expected, 15 WLU ceiling, wanted in 3 seconds => 4 WLU/s. */
demand = .WLUWorkDemand~new(12 * MICRO, 15 * MICRO, 3)
assessment = auth~assessDemand("AI_GPT", "AI:MODEL", demand)~value
say "expected WLU:" .WLUUnits~format(assessment~expectedMicroWlu)
say "requested WLU/s:" .WLUUnits~format(assessment~requestedRateMicroWluPerSecond)
say "available WLU/s:" .WLUUnits~format(assessment~deliveryAvailableRateMicroWluPerSecond)
say "shortfall WLU/s:" .WLUUnits~format(assessment~deliveryShortfallRateMicroWluPerSecond)

if \assessment~ready then do
  say "scheduler: capacity shortfall; simulate provider adding 1 WLU/s"
  ignore = pool~increaseCapacityRate(1 * MICRO)
end

reservation = auth~reserveDemand("AI_GPT", "AI:MODEL", demand, 30, "example-job")
if \reservation~ok then do
  say "not admitted:" reservation~code reservation~detail
  exit 1
end
say "admitted reservation:" reservation~value~reservationId
say "delivery promise WLU/s:" .WLUUnits~format(reservation~value~reservedRateMicroWluPerSecond)

/* Actual work was lower than forecast.  Acceleration itself is not charged. */
settled = auth~settle(reservation~value, 10 * MICRO)
say "settled:" settled~ok "actual WLU=10"
exit 0

::requires "WorkLoadUnits.cls"
