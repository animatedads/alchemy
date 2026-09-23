# API

API: `sftp/0.1`

Primary classes:

* `SftpEndpoint(backend,maxRead=1048576,maxWrite=1048576)`
* `SftpBackend`
* `SftpMemoryBackend` (qualification/reference backend)
* `SftpCodec`
* `SftpPath`
* `SftpSubsystemHandler(backendFactory)`

`SftpEndpoint~consume(frame)` consumes exactly one length-framed SFTP packet and returns exactly one response frame.

The SSH integration point is `SftpSubsystemHandler`, registered as subsystem `sftp` in `SshEndpointRegistry`.  A future live-channel adapter will perform bounded channel framing and feed complete packets to the endpoint.
