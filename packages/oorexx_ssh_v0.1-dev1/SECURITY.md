# Security

* Shell is denied unless an application explicitly installs a shell endpoint.
* Authentication and endpoint authorization are separate decisions.
* Unknown subsystem and exec requests fail closed.
* Passwords/private keys are never part of endpoint request names or logs.
* Native provider version is inspected before server mode.  dev1 defaults to libssh >= 0.11.5 for server use; newer supported security releases should be preferred.
* Provider-native handles are Foreign Runtime managed resources.
* Server callbacks/channel dispatch must not call foreign/native code while holding application registry locks in future concurrent cuts.
