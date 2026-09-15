signal on syntax name failed
System = bsf.importClass("java.lang.System")
say "JAVA" System~getProperty("java.version")
ignore = bsf.loadClass("javax.jms.Message")
ignore = bsf.loadClass("com.solacesystems.jndi.SolJNDIInitialContextFactory")
say "BSF/JMS PROVIDER CLASSPATH PASS"
exit 0
failed:
  say "BSF/JMS PROVIDER CLASSPATH FAIL" condition("D")
  if .BSF_ERROR_MESSAGE \== .nil then say .BSF_ERROR_MESSAGE
  exit 1
::requires "BSF.CLS"
