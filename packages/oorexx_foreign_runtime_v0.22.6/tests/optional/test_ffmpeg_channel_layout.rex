lib=.foreign~load('ffmpeg_channel_layout.bridge.json')
layout=lib~struct('AVChannelLayout')
ignored=lib~layout_default(layout,2)
if layout~get('nb_channels')<>2 then do; say 'FAIL AVChannelLayout nb_channels'; exit 1; end
if layout~get('mask')<>3 then do; say 'FAIL AVChannelLayout stereo mask:' layout~get('mask'); exit 2; end
text=.foreign~buffer(128)
rc=lib~layout_describe(layout,text,128)
if rc<0 then do; say 'FAIL av_channel_layout_describe rc='rc; exit 3; end
desc=text~bytes
nul=desc~pos('00'x)
if nul>0 then desc=desc~left(nul-1)
if desc='' then do; say 'FAIL empty channel layout description'; exit 4; end
say 'FFmpeg AVChannelLayout:' desc
say 'channels:' layout~get('nb_channels') 'mask:' layout~get('mask')
ignored=lib~layout_uninit(layout)
text~close; layout~close; lib~close
say 'PASS Foreign Runtime -> FFmpeg AVChannelLayout struct'
exit 0
::requires '../../rexx/foreign.cls'
