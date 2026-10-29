/* Builder/runtime description of one bounded code region.  Language choice is
 * editor/execution metadata; it does not alter the Wire application graph. */
::class WireCodeBlock public
::method init
  expose language source
  use strict arg language, source
  if language == "" then language = "rexx"
::attribute language get
::attribute source get
