::class ExternalTool public
::method run
  before = "command-anchor-before"
  address system "echo NEW"
  after = "command-anchor-after"
  return 1
