support = .AlchemyTestSupport
base = support~tempDir("alchemy-local")
src = base || "/source"
work = base || "/work"
support~mkdir(src)
support~mkdir(work)
support~write(src || "/integration.json", '{"schema":"alchemy.autobuild.integration/0.2"}')
support~write(src || "/payload.txt", "LOCAL_PAYLOAD")

context = .AlchemyTransportContext~new(work)
source = .AlchemyTransportSource~new("local-directory", src)
mat = .AlchemyLocalDirectoryTransport~new~materialize(source, context)
support~assertTrue(.AlchemyTransportFs~isFile(mat~manifestPath), "manifest materialized")
support~assertEq("LOCAL_PAYLOAD", support~read(mat~root || "/payload.txt"), "payload copied")
support~assertEq("local-directory", mat~source~kind, "source kind")
support~remove(base)
say "PASS test_local_directory_transport"
exit 0

::requires "AlchemyTransport.cls"
::requires "TestSupport.cls"
