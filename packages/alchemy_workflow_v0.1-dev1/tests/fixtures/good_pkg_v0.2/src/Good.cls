/* Good.cls - a fixture that keeps every house rule. The traps in this comment are not code:
 * result = 1, x = y + 0, '|'b, '"'(x), ::method hidden private
 */
::class Good public
::constant MODULE_VERSION '0.2'
::constant MODULE_LASTCHANGED '2026-11-11'

::method init
  expose items
  use strict arg items = (.array~of(1, 2))

::method total
  expose items
  sum = 0
  do i over items
    sum += i
  end
  crlf = '0d0a'x
  bits = '0101'b
  msg = .message~new(self, 'COUNT')
  msg~send
  answer = msg~result
  say 'result = is in a string, + 0 too'
  return sum

::method count
  expose items
  return items~items

/* inherits both stamps from Good: the same package, the same component */
::class GoodChild public subclass Good
