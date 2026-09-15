::class ExternalTool public
::method run
  before = "command-anchor-before"
  address system "echo OLD"
  after = "command-anchor-after"
  return 1
