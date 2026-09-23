param(
  [Parameter(Mandatory=$true)][string]$OoRexxRoot,
  [string]$Build="build",
  [string]$Stage="stage"
)
$ErrorActionPreference="Stop"
& "$PSScriptRoot\stage-windows-runtime.ps1" -OoRexxRoot $OoRexxRoot -Stage $Stage
$bin=Join-Path $Stage "bin"; New-Item -ItemType Directory -Force $bin | Out-Null
Copy-Item -Force (Join-Path $Build "Release\wire_ui_windows.exe") (Join-Path $bin "wire-ui.exe")
foreach($dir in @("rexx","definitions","contracts","assets")){Copy-Item -Recurse -Force (Join-Path $PSScriptRoot "..\$dir") $Stage}
Write-Host "Staged runnable Wire UI Windows application at $Stage"
