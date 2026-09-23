numeric digits 30
parse arg stamp
if stamp='' then do; say 'usage: wallclock_to_serial.rex "YYYY-MM-DD HH:MM:SS"'; exit 2; end
say .AudioV9VoiceClock~parse(stamp)
exit 0
::requires 'AudioV9VoiceCampaign.cls'
