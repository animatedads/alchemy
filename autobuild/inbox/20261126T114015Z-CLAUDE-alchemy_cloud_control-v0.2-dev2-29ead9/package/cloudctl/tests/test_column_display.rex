/* test_column_display.rex -- ColumnDisplay.cls, including Tom's original example rows.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 7 November 2026.
 * usage: rexx test_column_display.rex CLOUDCTL_DIR
 */
parse arg dir .
if dir='' then dir='.'
call (dir'/src/ColumnDisplay.cls')
t=.directory~new; t~pass=0; t~fail=0
p=.ColumnDisplay~new(.array~of(8, 15, 6))

/* Tom's example */
call eq t, p~format(.array~of('ID', 'Product Name', 'Price')), 'ID       Product Name    Price', 'header'
call eq t, p~separator, '-'~copies(31), 'separator (8+15+6 plus two gaps) -- the original crashed here'
call eq t, p~format(.array~of('P1001', 'Wireless Mouse', '29.99')), 'P1001    Wireless Mouse   29.99', 'number right-aligned'
call eq t, p~format(.array~of('P1002', .nil, '119.50')), 'P1002                    119.50', '.nil cell blank'
call eq t, p~format(.array~of('P1003', 'USB-C Hub', '')), 'P1003    USB-C Hub', 'empty price blank'
call eq t, p~format(.array~of('P1004')), 'P1004', 'omitted columns blank'

/* the faults */
call eq t, p~format(.array~of('P1005', , '9.99')), 'P1005                      9.99', 'omitted middle slot: price kept (original dropped it)'
call eq t, p~format(.array~of('P1006', 'x', '1234567.89')), 'P1006    x               ******', 'wide number starred, not cut to 567.89'
call eq t, p~format(.array~of('P1007', 'Mechanical Keyboard', '1')), 'P1007    Mechanical Key~      1', 'long text cut visibly'
call eq t, p~format(.array~of('P1008', 'The NIL object', '2')), 'P1008    The NIL object       2', 'the text "The NIL object" is data'
call eq t, p~format(.array~of('P1009', 'Fifteen chars!!', '3.5')), 'P1009    Fifteen chars!!    3.5', 'full-width name does not touch the price'
call eq t, p~separator('='), '='~copies(31), 'separator with a character'
call eq t, p~separator(''), '-'~copies(31), 'separator with an empty character'
call eq t, .ColumnDisplay~new(.array~of(3, 3), 0)~format(.array~of('ab', 'cd')), 'ab cd', 'gap 0'
bad=0
signal on syntax name badWidth
w=.ColumnDisplay~new(.array~of(8, 'x'))
signal off syntax
badWidthDone:
call eq t, bad, 1, 'a non-numeric width is refused on init'

say 'RESULT pass='t~pass 'fail='t~fail
if t~fail>0 then exit 1
exit 0

badWidth:
  bad=1
  signal badWidthDone

eq: procedure
  use strict arg t, got, want, label
  if got==want then do
    t~pass=t~pass+1
    say 'PASS' label
    return
  end
  t~fail=t~fail+1
  say 'FAIL' label
  say '  want ['want']'
  say '  got  ['got']'
  return
