# ooRexx Speech continuity sphere v0.1

Authoritative continuity for `packages/oorexx_speech`.

Start with:

    gopher --profile oorexx-speech context oorexx-speech --full
    gopher --profile oorexx-speech search Macrospace --sphere oorexx-speech
    gopher --profile oorexx-speech search SIP --sphere oorexx-speech
    gopher --profile oorexx-speech search HTTPS --sphere oorexx-speech
    gopher --profile oorexx-speech search LDAP --sphere oorexx-speech

Speech owns TTS/STT channel, stream, duplex-session and provider semantics. It does not own SIP signalling, RTP packetisation, HTTPS/TLS, LDAP identity, RPC transport, Storage identity or local audio device authority.
