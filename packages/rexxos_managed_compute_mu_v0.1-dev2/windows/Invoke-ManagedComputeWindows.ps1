# Constrained, local Windows-side test agent. No remote listener or bootstrap here.
# Windows host with a functioning Windows-container daemon is mandatory.
param(
  [Parameter(Mandatory=$true)][string]$RequestPath,
  [Parameter(Mandatory=$true)][string]$PolicyPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') { throw 'WINDOWS_HOST_REQUIRED' }
$request = Get-Content -LiteralPath $RequestPath -Raw | ConvertFrom-Json
$policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
if ($request.schema -cne 'rexxos.mu.windows-test/0.1') { throw 'SCHEMA_UNSUPPORTED' }
if ($policy.schema -cne 'rexxos.mu.windows-policy/0.1') { throw 'POLICY_UNSUPPORTED' }
if ($request.request_id -cnotmatch '^[A-Za-z0-9._-]{1,80}$') { throw 'INVALID_REQUEST_ID' }
if ($request.placement_id -cnotmatch '^[A-Za-z0-9._-]{1,120}$') { throw 'PLACEMENT_REQUIRED' }
if ($request.workload_digest -cnotmatch '^sha256:[a-fA-F0-9]{64}$') { throw 'WORKLOAD_DIGEST_INVALID' }
if ($request.image -cnotmatch '^[-a-zA-Z0-9._/]+@sha256:[a-f0-9]{64}$') { throw 'IMAGE_NOT_PINNED' }
if ($request.isolation -cnotin @('process','hyperv')) { throw 'ISOLATION_UNSUPPORTED' }
if ($request.image -cnotin @($policy.images)) { throw 'IMAGE_NOT_ALLOWED' }
if ($request.isolation -cnotin @($policy.isolation)) { throw 'ISOLATION_NOT_ALLOWED' }
$seconds = [int]$request.timeout_seconds
if ($seconds -lt 1 -or $seconds -gt [int]$policy.max_seconds) { throw 'TIMEOUT_OUT_OF_POLICY' }
if ([int]$policy.max_seconds -gt 1800 -or [int]$policy.max_seconds -lt 1) { throw 'POLICY_TIMEOUT_INVALID' }
# The workload entrypoint comes exclusively from the pinned container image.
# No arbitrary command, host mount, credential or network access is passed through.
$arguments = @('run','--rm','--pull=never','--network=none',"--isolation=$($request.isolation)","--name=mu-$($request.request_id)", $request.image)
$stdout = [IO.Path]::GetTempFileName()
$stderr = [IO.Path]::GetTempFileName()
try {
  $p = Start-Process -FilePath 'docker.exe' -ArgumentList $arguments -Wait:$false -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  if (-not $p.WaitForExit($seconds * 1000)) {
    & docker.exe rm -f "mu-$($request.request_id)" *> $null
    try { $p.Kill() } catch { }
    throw 'EXECUTION_UNCERTAIN_TIMEOUT'
  }
  [pscustomobject]@{
    schema = 'rexxos.mu.windows-result/0.1'
    request_id = $request.request_id
    placement_id = $request.placement_id
    code = $(if ($p.ExitCode -eq 0) { 'COMPLETED' } else { 'FAILED' })
    exit_code = $p.ExitCode
    # Caller owns archival of a bounded, redacted log. Raw output is not returned.
  } | ConvertTo-Json -Compress
} finally {
  Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
}
