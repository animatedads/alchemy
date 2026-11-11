/* Bad.cls - a fixture that breaks the house rules, one per line, so the tests can name the line. */
::class Bad public
::constant MODULE_VERSION '0.3'
::constant MODULE_LASTCHANGED '2026-01-01'

::method init
  use strict arg items
  expose items

::method helper private
  return 1

::method sums
  expose items
  result = 0
  do i = 1 to items~items
    total = items[i] + 0
  end
  sep = '|'b
  q = '"'(sep)
  return total

::class Unstamped public
::method nothing
  return ''
