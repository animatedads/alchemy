support = .AlchemyTestSupport
runner = .AlchemyCommandRunner~new
r = runner~require(.array~of("printf", "%s", "a b'c"))
support~assertEq("a b'c", r~stdout, "argv quoting")
base = support~tempDir("alchemy-hash")
support~write(base || "/x", "abc")
support~assertEq("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", .AlchemyChecksumTool~sha256(base || "/x", runner), "sha256")
support~remove(base)

safe = .array~of("integration.json", "src/A.cls", "tests/")
support~assertTrue(.AlchemyArchivePathPolicy~assertEntries(safe), "safe archive names")

bad = .array~of("../escape")
raised = .false
signal on syntax name badPath
.AlchemyArchivePathPolicy~assertEntries(bad)
signal off syntax
say "FAIL traversal accepted"
exit 1
badPath:
signal off syntax
say "PASS test_command_and_policy"
exit 0

::requires "AlchemyTransport.cls"
::requires "TestSupport.cls"
