/* Referee-side parser checks. Run from package root. */
board = .DiplomacyBoard~new('data/standard.source')
parser = .DiplomacyOrderParser~new(board)
units = .directory~new
units['PAR'] = .DiplomacyUnit~new('FRA','A','PAR')
units['MAR'] = .DiplomacyUnit~new('FRA','A','MAR')
units['BRE'] = .DiplomacyUnit~new('FRA','F','BRE')
units['MAO'] = .DiplomacyUnit~new('FRA','F','MAO')
units['CON'] = .DiplomacyUnit~new('TUR','F','CON')
units['RUM'] = .DiplomacyUnit~new('RUS','F','RUM')
units['SER'] = .DiplomacyUnit~new('AUS','A','SER')
units['LON'] = .DiplomacyUnit~new('ENG','A','LON')
units['NTH'] = .DiplomacyUnit~new('ENG','F','NTH')
units['STP'] = .DiplomacyUnit~new('RUS','F','STP/SC')
units['MUN'] = .DiplomacyUnit~new('GER','A','MUN')
units['GAS'] = .DiplomacyUnit~new('FRA','F','GAS')
units['SPA'] = .DiplomacyUnit~new('ITA','F','SPA/SC')
retreats = .directory~new
retreats['PAR'] = .array~of('PIC')
retreats['GAS'] = .array~of('SPA/NC')
ownership = .directory~new
ownership['STP'] = 'RUS'
ownership['MOS'] = 'RUS'
ownership['MAR'] = 'FRA'
ownership['POR'] = 'FRA'
checks = 0
failures = 0
reasons = .directory~new
call test 'A PAR - BUR','MOVEMENT','FRA','','MOVE','BUR'
call test ' a  par-bur ','MOVEMENT','FRA','','MOVE','BUR'
call test 'F BRE - MAO','MOVEMENT','FRA','','MOVE','MAO'
call test 'A MAR S A PAR - BUR','MOVEMENT','FRA','','SUPPORT_MOVE',''
call test 'A PAR S A MAR','MOVEMENT','FRA','BAD_SUPPORT','SUPPORT_HOLD',''
call test 'A MAR S A PAR H','MOVEMENT','FRA','SYNTAX','',''
call test 'A MUN H','MOVEMENT','GER','','HOLD',''
call test 'F NTH C A LON - NWY','MOVEMENT','ENG','','CONVOY',''
call test 'A LON - NWY VIA CONVOY','MOVEMENT','ENG','','MOVE','NWY'
call test 'A LON - NWY','MOVEMENT','ENG','','MOVE','NWY'
call test 'A PAR - MOS','MOVEMENT','FRA','NOT_ADJACENT','MOVE','MOS'
call test 'A LON - LON','MOVEMENT','ENG','NOT_ADJACENT','MOVE',''
call test 'A PAR - MAO','MOVEMENT','FRA','NOT_ADJACENT','MOVE',''
call test 'F BRE - PAR','MOVEMENT','FRA','NOT_ADJACENT','MOVE',''
call test 'F CON - BUL','MOVEMENT','TUR','NO_COAST','MOVE',''
call test 'F CON - BUL/SC','MOVEMENT','TUR','','MOVE','BUL/SC'
call test 'F RUM - BUL/SC','MOVEMENT','RUS','BAD_COAST','MOVE',''
call test 'F RUM - BUL','MOVEMENT','RUS','NO_COAST','MOVE',''
call test 'F GAS - SPA','MOVEMENT','FRA','NO_COAST','MOVE',''
call test 'F MAO - SPA','MOVEMENT','FRA','NO_COAST','MOVE',''
call test 'F STP/NC H','MOVEMENT','RUS','BAD_COAST','HOLD',''
call test 'F STP H','MOVEMENT','RUS','NO_COAST','HOLD',''
call test 'A SER S F CON - BUL','MOVEMENT','AUS','NO_COAST','SUPPORT_MOVE',''
call test 'A SER S F CON - BUL/SC','MOVEMENT','AUS','','SUPPORT_MOVE',''
call test 'F RUM S F CON - BUL/SC','MOVEMENT','RUS','','SUPPORT_MOVE',''
call test 'A PAR - BUR/NC','MOVEMENT','FRA','BAD_COAST','MOVE',''
call test 'F PAR H','MOVEMENT','FRA','WRONG_TYPE','HOLD',''
call test 'A PIC H','MOVEMENT','FRA','NO_UNIT','HOLD',''
call test 'A MUN H','MOVEMENT','FRA','NOT_OWN_UNIT','HOLD',''
call test 'F BRE C A LON - NWY','MOVEMENT','FRA','BAD_CONVOY','CONVOY',''
call test 'F MAO C A PAR - NWY','MOVEMENT','FRA','BAD_CONVOY','CONVOY',''
call test 'A PAR - PIC VIA CONVOY','MOVEMENT','FRA','BAD_CONVOY','MOVE','PIC'
call test 'A PAR R PIC','RETREAT','FRA','','RETREAT','PIC'
call test 'A PAR R BUR','RETREAT','FRA','NOT_RETREAT_OPTION','RETREAT','BUR'
call test 'A PAR D','RETREAT','FRA','','DISBAND',''
call test 'A PAR H','RETREAT','FRA','SYNTAX','',''
call test 'DISBAND A PAR','ADJUSTMENT','FRA','','DISBAND',''
call test 'BUILD A MOS','ADJUSTMENT','RUS','','BUILD','MOS'
call test 'BUILD F MOS','ADJUSTMENT','RUS','BAD_BUILD','BUILD',''
call test 'BUILD A MAR','ADJUSTMENT','FRA','BAD_BUILD','BUILD',''
call test 'BUILD F POR','ADJUSTMENT','FRA','BAD_BUILD','BUILD',''
-- REQ-00006237: every split fleet reference must explicitly name its coast.
call test 'F STP - BOT','MOVEMENT','RUS','NO_COAST','MOVE',''
call test 'F STP/SC - BOT','MOVEMENT','RUS','','MOVE','BOT'
call test 'F STP/SC H','MOVEMENT','RUS','','HOLD',''
call test 'F GAS - SPA/NC','MOVEMENT','FRA','','MOVE','SPA/NC'
call test 'F RUM - BUL/EC','MOVEMENT','RUS','','MOVE','BUL/EC'
call test 'F GAS S F SPA - MAO','MOVEMENT','FRA','NO_COAST','SUPPORT_MOVE',''
call test 'F GAS S F SPA/NC - MAO','MOVEMENT','FRA','BAD_COAST','SUPPORT_MOVE',''
call test 'F GAS S F SPA/SC - MAO','MOVEMENT','FRA','','SUPPORT_MOVE',''
call test 'F GAS S F SPA','MOVEMENT','FRA','NO_COAST','SUPPORT_HOLD',''
call test 'F GAS S F SPA/SC','MOVEMENT','FRA','','SUPPORT_HOLD',''
call test 'F GAS R SPA','RETREAT','FRA','NO_COAST','RETREAT',''
call test 'F GAS R SPA/NC','RETREAT','FRA','','RETREAT','SPA/NC'
call test 'F STP D','RETREAT','RUS','NO_COAST','DISBAND',''
call test 'DISBAND F STP','ADJUSTMENT','RUS','NO_COAST','DISBAND',''
call test 'DISBAND F STP/SC','ADJUSTMENT','RUS','','DISBAND',''
call test 'A PAR/NC H','MOVEMENT','FRA','BAD_COAST','HOLD',''
call test 'A MAR S A PAR/NC - BUR','MOVEMENT','FRA','BAD_COAST','SUPPORT_MOVE',''
call test 'A MAR S A PAR - BUR/NC','MOVEMENT','FRA','BAD_COAST','SUPPORT_MOVE',''
call test 'F NTH C A LON/NC - NWY','MOVEMENT','ENG','BAD_COAST','CONVOY',''
call test 'F NTH C A LON - NWY/NC','MOVEMENT','ENG','BAD_COAST','CONVOY',''
units~remove('STP')
call test 'BUILD F STP/NC','ADJUSTMENT','RUS','','BUILD','STP/NC'
call test 'BUILD F STP','ADJUSTMENT','RUS','NO_COAST','BUILD',''
call test 'BUILD A STP/NC','ADJUSTMENT','RUS','BAD_COAST','BUILD',''
call test 'WAIVE','ADJUSTMENT','RUS','','WAIVE',''
call test 'WAIVE NOW','ADJUSTMENT','RUS','SYNTAX','',''
call test 'A PAR - BUR EXTRA','MOVEMENT','FRA','SYNTAX','',''
call test 'A PAR S A PIC - BUR','MOVEMENT','FRA','BAD_SUPPORT','SUPPORT_MOVE',''
call test 'A PAR -','MOVEMENT','FRA','SYNTAX','',''
call test 'A PAR - B1R','MOVEMENT','FRA','SYNTAX','',''
call test 'A PAR - BUR/','MOVEMENT','FRA','SYNTAX','',''
orders = parser~parseOrders(.array~of('A PAR H','a par - bur','F PAR H','A MUN H'),'MOVEMENT','FRA',units)
call check orders~items = 4,'duplicate record count'
call check orders[1]~reason == 'SUPERSEDED','first superseded'
call check orders[2]~reason == 'SUPERSEDED','second superseded'
call check orders[2]~raw == 'a par - bur','raw preserved'
call check orders[3]~reason == 'WRONG_TYPE','last wrong type holds'
call check orders[4]~reason == 'NOT_OWN_UNIT','other power not superseded'
reasons['SUPERSEDED'] = .true
orders = parser~parseOrders(.array~of('A PAR H','A PAR WHAT'),'MOVEMENT','FRA',units)
call check orders[1]~reason == 'SUPERSEDED','last malformed order wins if unit recognizable'
call check orders[2]~reason == 'SYNTAX','malformed last order retained'
expected = 'SYNTAX NO_UNIT NOT_OWN_UNIT WRONG_TYPE NOT_ADJACENT NO_COAST BAD_COAST BAD_SUPPORT BAD_CONVOY NOT_RETREAT_OPTION BAD_BUILD SUPERSEDED'
do reasonCode over expected~subWords
  call check reasons~hasIndex(reasonCode),'coverage' reasonCode
end
say 'Checks:' checks 'Failures:' failures 'Reason codes:' reasons~items
exit (failures > 0)

test: procedure expose parser units retreats ownership checks failures reasons
  use strict arg raw, phase, power, reasonCode, action, destination
  order = parser~parseOrder(raw,phase)
  order = parser~validate(order,power,units,retreats,ownership)
  call check order~raw == raw,'raw' raw
  call check order~reason == reasonCode,'reason' raw 'expected' reasonCode 'actual' order~reason
  if action \== '' then call check order~action == action,'action' raw
  if destination \== '' then call check order~resolvedDestination == destination,'destination' raw
  if reasonCode \== '' then if order~reason == reasonCode then reasons[reasonCode] = .true
  return
check: procedure expose checks failures
  use strict arg ok, description
  checks += 1
  if \ok then do
    failures += 1
    say 'FAIL:' description
  end
  return
::requires 'src/DiplomacyOrderParser.cls'
