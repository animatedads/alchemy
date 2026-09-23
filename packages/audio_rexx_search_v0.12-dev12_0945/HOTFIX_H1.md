# v0.12-dev9 09:45 controller hotfix H1

This hotfix changes controller/campaign plumbing only. Worker DSP/search semantics and the
`audio-rexx-search-v0.12-dev9` remote worker tree remain unchanged.

Repairs:

1. 09:45 tp00023->tp00024 companion preparation decodes before concatenation and then
   pads/trims to the authoritative 9,120,000 samples (570.000 s at 16 kHz), avoiding
   Ogg/Vorbis packet/granule-boundary shortfall.
2. H audio staging uses the managed SSH config (`ED209H_SSH_CONFIG`, `SSH_CONFIG`, or
   `$HOME/.ssh/config`) and supports `ED209H_KEY` with `VULTR_KEY` retained as fallback.
3. H API job construction preserves empty TSV fields by converting tabs to a
   non-whitespace delimiter before Bash `read`. An empty `reject_bands` therefore remains
   empty and the processing-chain field cannot shift into it.

No H job is considered submitted until the API returns HTTP 202. The earlier 400
`INVALID_REJECT_BANDS` request did not start DSP work.
