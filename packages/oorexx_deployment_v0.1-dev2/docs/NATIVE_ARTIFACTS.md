# Native artifact deployment

Native deployment is governed by **target loadability**, not filename equality and not controller/build-host ABI. A supplied `.so` may be reused when its declared target probe succeeds. If the probe fails and policy permits rebuilding, Deployment uses the supplied source and target toolchain, then reruns the same probe. If rebuilding is not allowed or the rebuilt object still fails, deployment fails closed.

This specifically handles libc drift. Parsing GLIBC symbol versions is useful evidence but is not the acceptance test; the final authority is the application-declared load/use probe on the target runtime.
