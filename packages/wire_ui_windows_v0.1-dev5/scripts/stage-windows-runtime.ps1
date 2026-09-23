param([Parameter(Mandatory=$true)][string]$OoRexxRoot,[string]$Stage="stage")
$ErrorActionPreference="Stop"
if (!(Test-Path $OoRexxRoot)) { throw "ooRexx root not found: $OoRexxRoot" }
$dest=Join-Path $Stage "runtime\oorexx"; New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item -Recurse -Force (Join-Path $OoRexxRoot "*") $dest
# Wire has no ooDialog dependency. Remove it from the staged product so this is
# mechanically testable rather than merely an architectural statement.
$ood=@("ooDialog.cls","ooDialog.com","ooDialog.exe","ooShapes.cls","oodPlain.cls","oodWin32.cls","oodialog.dll","ooshapes.dll")
foreach($name in $ood){$p=Join-Path $dest "bin\$name";if(Test-Path $p){Remove-Item -Force $p}}
Write-Host "Staged private ooRexx runtime (ooDialog-free) at $dest"
