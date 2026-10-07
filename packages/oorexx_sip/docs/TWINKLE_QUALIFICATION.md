# Twinkle 1.10.3 qualification

Captured interoperability target: Twinkle 1.10.3 over UDP.

Observed REGISTER shape includes:

- Via with empty `rport`
- Contact `<sip:1001@127.0.0.1:5071;transport=udp>;expires=300`
- no separate `Expires:` header

v0.1-dev4 repairs the dev2 registrar behavior exposed by this trace:

1. Contact-level `expires` is authoritative for that binding.
2. Empty Via `rport` is returned with the packet source port.
3. `received` is returned with the packet source address.
4. REGISTER 200 Contact carries an explicit expiration.
5. Expiration zero removes the binding.

Executable regression fixtures:

- `tests/twinkle_register_fixture.rex`
- `tests/twinkle_options_fixture.rex`

The original Twinkle run proved REGISTER interoperability. A real Twinkle-originated INVITE was not completed because the headless CLI instance exited before its local command socket accepted `--call`; therefore this document does not claim Twinkle INVITE/RTP qualification.
