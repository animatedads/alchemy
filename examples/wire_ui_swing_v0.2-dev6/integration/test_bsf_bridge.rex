say "ooRexx=" version
runtime=bsf.loadClass("org.alchemy.wireui.swing.WireSwingRuntime")~create
hello=runtime~hello("bsf-app", "bsf-session", "swing-desktop")
say "helloType=" hello~get("type")
say "protocol=" hello~get("protocolVersion")
caps=hello~get("renderCapabilities")
say "toolkit=" caps~get("uiToolkit")
say "headlessRootClass=" runtime~rootComponent~getClass~getName
if hello~get("type")<>"UI_HELLO" then exit 11
if caps~get("uiToolkit")<>"JAVA_SWING" then exit 12
exit 0
::requires "BSF.CLS"
