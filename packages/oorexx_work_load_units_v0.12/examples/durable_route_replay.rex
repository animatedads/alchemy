path = "/tmp/wlu_route_replay_example.log"
ignore = RxFuncAdd("SysFileDelete", "rxunixsys", "SysFileDelete")
ignore = SysFileDelete(path)
keys = .WLUFastMacKeyRing~new
keys~addKey("route-demo", "000102030405060708090a0b0c0d0e0f")
journal = .WLUJobRouteFileJournal~new(path, keys)

d1 = .WLUJobRouteEvidence~new("CHAT-001", 1, 1000000, .WLUJobRouteEventType~TRANSITION, "GROK", "GEMMA", "", 0, 0, .false, 10000000, 11000000, 2, "AT_RISK", "standby-1", "QUALITY_POLICY", "quality:42", "ai-common", "2026-08")
e1 = d1~withProof(keys~sign(d1~canonicalText))
d2 = .WLUJobRouteEvidence~new("CHAT-001", 2, 2000000, .WLUJobRouteEventType~STAGE_SETTLED, "GROK", "", "rescue-1", 7000000, 1000000, .true, 10000000, 11000000, 2, "AT_RISK", "standby-1", "SUCCESS", "conversation:complete", "ai-common", "2026-08")
e2 = d2~withProof(keys~sign(d2~canonicalText))
ignore = journal~appendEvent(e1)
ignore = journal~appendEvent(e2)
say "journal sequence:" journal~sequence

/* Simulated process restart: this object has no WLUAuthority. */
reopened = .WLUJobRouteFileJournal~new(path, keys)
summary = reopened~summary("CHAT-001")~value
say "replayed events:" summary~eventCount
say "actual WLU:" .WLUUnits~format(summary~actualMicroWlu)
say "known handoff WLU:" .WLUUnits~format(summary~knownHandoffMicroWlu)
say "entitlement recreated: NO"
call SysFileDelete path
::requires "WLURouteJournal.cls"
