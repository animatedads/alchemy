/* Demonstrates that the SFTP namespace is a Rexx object, not a host process. */
backend=.SftpMemoryBackend~new
backend~mkdir('/mail')
backend~put('/mail/hello.txt','hello from Rexx space')
endpoint=.SftpEndpoint~new(backend)
service=.SftpChannelService~new(endpoint)
say 'SFTP endpoint object ready:' endpoint
say 'No shell or external sftp-server was started.'
exit 0
::requires '../src/SftpCore.cls'
