/*
 * Facts Matrix: the "break down job, assign facts" front end, made trivially easy. (Tom, 2026-10-26.)
 *
 * A thin, ergonomic builder over the Belief Journal so a CLI tool, an MCP op, or a single chat can,
 * in a few lines, declare a job's DECISIONS and the FACTS they rest on, then admit a MEASUREMENT and
 * immediately see which fact was erroneous and the dependency tree of decisions that must now be
 * reconsidered. A measurement is a higher-tier defeater than an assumption, so it overturns the fact
 * it contradicts and everything built on it.
 *
 *   m~fact("speed", "the cache will speed matters up", 5)        -- an assumed fact, at a turn
 *   m~decision("impl", "implement the cache", 8); m~needs("impl","speed")
 *   m~measure("bench", "cache never hit; 1.6x slowdown", .array~of("speed"), 40)
 *   rev = m~review   -- erroneous facts + fallen decisions, each with its turn
 *
 * Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer. Pure ooRexx 5.3.
 */

::class FactsMatrix public
::method init
  expose net j facts decisions turns
  net = .ThoughtNetwork~new
  j = .BeliefJournal~new(net)
  facts = .directory~new; decisions = .directory~new; turns = .directory~new
::method journal
  expose j
  return j

::method fact
  /* an assumed fact: assertible until a stronger defeater contradicts it */
  expose net j facts turns
  use strict arg id, statement, turn = 0
  j~claim(id, statement)
  u = .Utterance~new("assume:" || id, "assumed")
  u~assert("SUPPORT", "TESTIMONY", id, , , "assumed (turn " || turn || ")")
  net~admit(u)
  facts[id] = statement; turns[id] = turn
  return self

::method decision
  expose j decisions turns
  use strict arg id, statement, turn = 0
  j~decision(id, statement)
  decisions[id] = statement; turns[id] = turn
  return self

::method needs
  expose j
  use strict arg decisionId, depId
  j~restsOn(decisionId, depId)
  return self

::method measure
  /* a measurement contradicts one or more facts, at DOCUMENTARY tier - above an assumption */
  expose net turns
  use strict arg id, statement, refuted, turn = 0
  u = .Utterance~new("measure:" || id, statement)
  do fid over refuted
    u~assert("REBUT", "DOCUMENTARY", fid, , , statement)
  end
  net~admit(u)
  turns[id] = turn
  return self

/* Which fact was erroneous, and the dependency tree of decisions to reconsider. */
::method review
  expose j facts decisions turns
  refuted = .array~new
  do fid over facts~allIndexes
    if \ j~status(fid)["ok"] then do
      d = .directory~new; d["id"] = fid; d["statement"] = facts[fid]; d["turn"] = turns[fid]
      refuted~append(d)
    end
  end
  fallen = .array~new
  do did over decisions~allIndexes
    s = j~status(did)
    if \ s["ok"] then do
      d = .directory~new; d["id"] = did; d["statement"] = decisions[did]
      d["turn"] = turns[did]; d["lost"] = s["failedDeps"]
      fallen~append(d)
    end
  end
  r = .directory~new; r["refutedFacts"] = refuted; r["fallenDecisions"] = fallen
  return r

::requires "BeliefJournal.cls"
