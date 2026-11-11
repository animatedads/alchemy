/* cut_feeds.rex -- write FD and FC chain windows for a wall-clock (FD-clock) span; FC shifted by the clock model.
 * Coding: Claude (Opus 5.5). usage: cut_feeds.rex HH:MM:SS.s durSec outPrefix */
numeric digits 16
parse arg t dur pre .
parse value value('SPASH_CLOCK',,'ENVIRONMENT') with cA cB
ch=fcfdChains(value('SPASH_PCM',,'ENVIRONMENT'),'CONTINUOUS')
t=hms2sec(t~changestr(':','')); off=cA+cB*(t-hms2sec('120000'))/3600
ch['FD']~writeWindow(t,dur*8000,pre'_FD.f32'); ch['FC']~writeWindow(t+off,dur*8000,pre'_FC.f32')
say 'FD' sec2hms(t) 'FC' sec2hms(t+off) 'offset' format(off,,3)
::requires 'FeedChain.cls'
