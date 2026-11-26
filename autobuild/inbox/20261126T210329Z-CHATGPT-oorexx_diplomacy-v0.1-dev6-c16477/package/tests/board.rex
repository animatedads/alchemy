/* Run from package root: rexx tests/board.rex */
board = .DiplomacyBoard~new('data/standard.source')
checks = 0
failures = 0
call check board~provinceCodes~items = 75, '75 provinces'
call check board~supplyCentres~items = 34, '34 supply centres'
call check board~nodeCodes~items = 81, '81 graph nodes'
do code over board~nodeCodes
  do kind over .array~of('A','F')
    do neighbour over board~neighbours(code,kind)
      call check board~adjacent(neighbour,code,kind), code kind neighbour 'reverse edge'
    end
  end
end
call check board~adjacent('CON','BUL/SC','F'), 'CON to BUL/SC'
call check \board~adjacent('RUM','BUL/SC','F'), 'RUM cannot reach BUL/SC'
call check board~adjacent('RUM','BUL/EC','F'), 'RUM to BUL/EC'
call check board~provinceOf('BUL/EC') = board~provinceOf('BUL/SC'), 'coast aliases share province'
call check \board~adjacent('GAS','SPA/SC','F'), 'GAS cannot reach south coast'
call check board~adjacent('GAS','SPA','A'), 'army ignores coast'
say 'Checks:' checks 'Failures:' failures
exit (failures > 0)
check: procedure expose checks failures
  use strict arg ok, description
  checks += 1
  if \ok then do
    failures += 1
    say 'FAIL:' description
  end
  return
::requires 'src/DiplomacyBoard.cls'
