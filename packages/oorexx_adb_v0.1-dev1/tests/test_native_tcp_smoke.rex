
/* Bridge qualification only: create an unconnected native socket wrapper and close it. */
t=.LinuxAdbTcpTransport~new('127.0.0.1',1)
/* open is expected to fail unless something is listening, but it must cross Foreign Runtime cleanly. */
opened=t~open
t~close
say 'ADB NATIVE TCP FOREIGN BRIDGE: OK'

::requires "AdbNativeTcp.cls"
