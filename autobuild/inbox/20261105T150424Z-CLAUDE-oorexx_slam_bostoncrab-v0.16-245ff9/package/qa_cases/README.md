# QA cases: the appearance inference

Story 7's question 4 ("Who did they find in the bush?") is answered by an inference from rules.src. A bush that shakes by itself may hide something, and whatever then comes into view, with no place given, came from it. These cases check that the rule doesn't fire where it shouldn't.

- agent_shakes: Pip shakes the bush. Nothing unseen is moving it. Expected: CANNOT TELL.
- scene_break: the shaking and the appearance are in different chapters. Expected: CANNOT TELL.
- named_source: the nose appears "from the hole". A stated place beats the inference. Expected: CANNOT TELL.
- positive_hedge: different words and a different animal, same event shape. Expected: Tim the rabbit, inferred and not settled.

Run: `sh qa_cases/run.sh`. Claude (Opus 5.5) wrote these cases. Independent ones are still wanted.
