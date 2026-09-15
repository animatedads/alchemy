support = .AlchemyTestSupport
base = support~tempDir("alchemy-zip")
src = base || "/source"
work = base || "/work"
support~mkdir(src)
support~mkdir(work)
support~write(src || "/integration.json", '{"schema":"alchemy.autobuild.integration/0.2"}')
support~write(src || "/payload.txt", "ZIP_PAYLOAD")
zipPath = base || "/package.zip"
rc = support~sh("cd " || .AlchemyShell~quote(src) || " && zip -q " || .AlchemyShell~quote(zipPath) || " integration.json payload.txt")
support~assertEq(0, rc, "zip creation")

context = .AlchemyTransportContext~new(work)
source = .AlchemyTransportSource~new("managed-zip", zipPath)
mat = .AlchemyManagedZipTransport~new~materialize(source, context)
support~assertEq("ZIP_PAYLOAD", support~read(mat~root || "/payload.txt"), "zip payload")
support~assertEq("managed-zip", mat~source~kind, "source kind")
support~remove(base)
say "PASS test_managed_zip_transport"
exit 0

::requires "AlchemyTransport.cls"
::requires "TestSupport.cls"
