param([ValidateRange(1024, 65535)][int]$GatewayPort = 5000)
$ErrorActionPreference = 'Stop'
$studioStatePath = Join-Path $PSScriptRoot "logs/local-processes-$GatewayPort.json"
if (-not (Test-Path -LiteralPath $studioStatePath)) { throw 'No services recorded by start-local.ps1 for this gateway port.' }
foreach ($studioEntry in @(Get-Content -LiteralPath $studioStatePath -Raw | ConvertFrom-Json)) {
  $studioProcess = Get-Process -Id $studioEntry.pid -ErrorAction SilentlyContinue
  if ($studioProcess -and $studioProcess.StartTime.ToUniversalTime().Ticks.ToString() -eq $studioEntry.started) {
    Stop-Process -Id $studioProcess.Id
  }
}
Remove-Item -LiteralPath $studioStatePath
Write-Output 'Stopped only the processes recorded by the Aureon launcher.'
