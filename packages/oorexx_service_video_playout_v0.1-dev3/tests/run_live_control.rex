/* Interactive, fixture-only openSUSE browser preview control.
 * Stage all assets with tools/prepare_live.sh before starting this program.
 * WAITING is native 24fps idle picture + silent 48kHz microphone.
 * Do not feed private/real customer content to approveMediaDemo.
 */
parse arg stageRoot
if stageRoot='' then do
  say 'USAGE run_live_control.rex ABSOLUTE_STAGE_ROOT'
  exit 2
end
p=.ServicePlayout~new('../rexx/service_playout.bridge.json')
p~approveMediaDemo
p~configure('/dev/video0','pulse:service_audio',1)
p~idleFrame(stageRoot || '/A01_IDLE.yuv')
p~enqueueClip(stageRoot || '/C01_03.yuv',stageRoot || '/C01_03.s16le',56)
p~enqueueClip(stageRoot || '/C02_01.yuv',stageRoot || '/C02_01.s16le',96)
p~enqueueCard(stageRoot || '/TPS_REPORT_DEMO.yuv',stageRoot || '/C02_12.s16le',144)
p~enqueueClip(stageRoot || '/C08_07.yuv',stageRoot || '/C08_07.s16le',96)
p~hold
p~start
say 'WAITING: /dev/video0 + service_mic online. Connect browser or VLC.'
say 'Commands: RELEASE | HOLD | STATS | QUIT'
do forever
  call charout , 'service> '
  parse pull action
  action=strip(translate(action))
  select
    when action='RELEASE' then do
      p~release
      say 'PLAYING queued media, then idle.'
    end
    when action='HOLD' then do
      p~hold
      say 'HOLDING at current position.'
    end
    when action='STATS' then say p~stats
    when action='QUIT' | action='' then leave
    otherwise say 'Unknown command; RELEASE, HOLD, STATS or QUIT.'
  end
end
p~stop
say 'FINAL' p~stats
exit 0
::requires '../rexx/ServicePlayout.cls'
