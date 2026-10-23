# Telephony audio profile — dev7

Speech does not own SIP, RTP, UDP or G.711 framing.  The current Library RTP
package remains the media-transport authority and exposes decoded PCM through
its own `RtpAudioFrame` boundary.

Dev7 adds an explicit speech-side profile:

```text
telephony-8k
  sample rate:   8000 Hz
  channels:      1
  sample format: S16LE
  encoding:      PCM
```

This matches the decoded narrowband PCM boundary expected around RTP PCMU/PCMA
media.  It is therefore possible for an RTP/audio adapter to pass decoded media
to streaming STT without an avoidable resample.

Azure TTS also supports this profile directly.  A TTS request with:

```rexx
options = .Directory~new
options['audioProfile'] = 'telephony-8k'
request = .SpeechTTSRequest~new(text, voice, language, options)
```

selects 8 kHz/16-bit/mono PCM for Azure batch or streaming synthesis.  The RTP
layer still owns PCMU/PCMA encoding and packetisation; Speech only supplies PCM.

`speech-16k` and the default Azure 24 kHz synthesis profile are also available.
