# Psychic Poker v0.7.41 — Structured Table Talk

v0.7.41 preserves the existing frozen table-talk dictionary and public TALK
transcript byte shape, but captures each accepted utterance as a
`StructuredUtterance v0.3` object before flattening.

No player receives a free-text channel.

    strategy / live AI chooses approved TOKEN + target
              |
              v
    PokerTableTalkLibrarian
      exact token -> frozen phrase/class/effect
              |
              v
    PokerStructuredTalkFactory
      sealed StructuredUtterance
        phrase segment = frozen dictionary phrase
        communicative act = talk class
        intended act = dictionary token
        intended outcome = talk class
        authority = POKER_TABLE_TALK_LIBRARIAN
        constraints = FROZEN_DICTIONARY, PUBLIC_SPEECH, NO_FREE_TEXT
        speaker/target correlations
              |
              +--> table_talk_structured evidence
              |
              v
    unchanged public line
      TALK Frank -> GROK [CHALLENGE] "I don't believe you."

The original `table_talk` relation is unchanged. The new relation is additive,
avoiding migration hazards for existing experiment databases.
