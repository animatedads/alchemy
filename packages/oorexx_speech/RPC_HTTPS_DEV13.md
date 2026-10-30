# Speech RPC / HTTPS publication — dev13

Speech dev13 adds an optional `speech.rpc/0.1` binding to the existing RPC Core.
It does not implement JSON-RPC, HTTP, TLS, LDAP, ConnectSelector or a second
transport selector.

Registered RPC Core operations:

- `speech / capabilities`
- `speech / intentions`
- `speech / synthesize`
- `speech / recognize`

`SpeechRpcInstaller~publishHttps()` maps these to the existing HTTPS JSON-RPC
publication names `speech.capabilities`, `speech.intentions`,
`speech.synthesize`, and `speech.recognize`.

The HTTPS gateway remains responsible for authenticating the accepted private-CA
TLS exchange against platform identity and authorizing each operation. Speech
never trusts request headers, JSON roles, bearer strings or LDAP claims itself.

## Material boundary

Ordinary JSON-RPC is control plane, not streaming PCM transport. TTS refuses to
return a local temporary pathname. The artifact must already contain a durable
`storage_identity` / `external_ref`, or the application must inject a material
authority implementing:

- `publishSpeechArtifact(artifact, context)` -> externally meaningful descriptor
- `resolveSpeechInput(reference, context)` -> materialised `SpeechAudioArtifact`

Without that authority, remote TTS/STT material operations fail closed.

Streaming TTS/STT remains on Speech's PCM stream API and the existing local/SIP
media seams. The HTTPS RPC gateway explicitly does not publish callback/stateful
streaming operations.
