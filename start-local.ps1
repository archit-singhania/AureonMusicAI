param(
  [string]$Python = 'python',
  [string]$Dotnet = 'dotnet',
  [ValidateRange(1024, 65535)][int]$PythonPort = 8103,
  [ValidateRange(1024, 65535)][int]$GatewayPort = 5000,
  [string]$UiOrigin = 'http://localhost:3005'
)
$ErrorActionPreference = 'Stop'
$studioRoot = $PSScriptRoot
if ($PythonPort -eq $GatewayPort) { throw 'Python and gateway need different ports.' }
foreach ($studioPort in @($PythonPort, $GatewayPort)) {
  $studioProbe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $studioPort)
  $studioProbe.Server.ExclusiveAddressUse = $true
  try { $studioProbe.Start() }
  catch { throw "Port $studioPort is already in use. Keep the existing service, stop its owner, or supply another -PythonPort/-GatewayPort." }
  finally { $studioProbe.Stop() }
}
$studioLogRoot = Join-Path $studioRoot 'logs'
New-Item -ItemType Directory -Path $studioLogRoot -Force | Out-Null
$studioProject = Join-Path $studioRoot 'dotnet_backend/AureonApi/AureonApi.csproj'
$studioGatewayBuild = Join-Path $studioLogRoot "gateway-$GatewayPort-release"
& $Dotnet build $studioProject -c Release --nologo -p:UseAppHost=false --output $studioGatewayBuild
if ($LASTEXITCODE -ne 0) { throw 'Gateway build failed; no service was started.' }
$studioPrevious = @{}
foreach ($studioName in @('AUREON_INTERNAL_KEY', 'AUREON_ORIGINS', 'AllowedOrigins', 'AudioService__BaseUrl')) {
  $studioPrevious[$studioName] = [Environment]::GetEnvironmentVariable($studioName, 'Process')
}
if (-not $env:AUREON_INTERNAL_KEY) { $env:AUREON_INTERNAL_KEY = [Guid]::NewGuid().ToString('N') + [Guid]::NewGuid().ToString('N') }
$env:AUREON_ORIGINS = "$UiOrigin,http://localhost:8080"
$env:AllowedOrigins = $env:AUREON_ORIGINS
$env:AudioService__BaseUrl = "http://127.0.0.1:$PythonPort"
$studioServices = @()
$studioSucceeded = $false
function Wait-StudioService($Process, [string]$Url) {
  for ($studioAttempt = 0; $studioAttempt -lt 60; $studioAttempt++) {
    if ($Process.HasExited) { throw "Service startup failed. See $studioLogRoot." }
    try {
      $studioHealth = Invoke-RestMethod "$Url/health" -TimeoutSec 1
      if ($studioHealth.status -eq 'ok') { return $studioHealth }
    } catch {}
    Start-Sleep -Milliseconds 500
  }
  throw "Service did not become ready at $Url. See $studioLogRoot."
}
try {
  $studioPython = Start-Process -FilePath $Python -ArgumentList @('-m', 'uvicorn', 'main:app', '--host', '127.0.0.1', '--port', "$PythonPort") -WorkingDirectory (Join-Path $studioRoot 'python_audio_service') -WindowStyle Hidden -RedirectStandardOutput (Join-Path $studioLogRoot "python-$PythonPort-output.log") -RedirectStandardError (Join-Path $studioLogRoot "python-$PythonPort-error.log") -PassThru
  $studioServices += $studioPython
  $studioHealth = Wait-StudioService $studioPython "http://127.0.0.1:$PythonPort"
  if (-not $studioHealth.ffmpeg) { throw 'Install FFmpeg on PATH or imageio-ffmpeg in the selected Python environment, then restart.' }
  $studioDll = Join-Path $studioGatewayBuild 'AureonApi.dll'
  $studioGateway = Start-Process -FilePath $Dotnet -ArgumentList @("`"$studioDll`"", '--urls', "http://127.0.0.1:$GatewayPort") -WorkingDirectory $studioRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $studioLogRoot "gateway-$GatewayPort-output.log") -RedirectStandardError (Join-Path $studioLogRoot "gateway-$GatewayPort-error.log") -PassThru
  $studioServices += $studioGateway
  $null = Wait-StudioService $studioGateway "http://127.0.0.1:$GatewayPort"
  $studioState = @($studioServices | ForEach-Object { @{ pid = $_.Id; started = $_.StartTime.ToUniversalTime().Ticks.ToString() } })
  ConvertTo-Json -InputObject $studioState | Set-Content -LiteralPath (Join-Path $studioLogRoot "local-processes-$GatewayPort.json")
  $studioSucceeded = $true
  Write-Output "Studio ready: gateway http://localhost:$GatewayPort; Python http://127.0.0.1:$PythonPort."
  Write-Output "Run Flutter with --dart-define=API_BASE_URL=http://localhost:$GatewayPort and the browser origin $UiOrigin."
  Write-Output "Stop these services with .\stop-local.ps1 -GatewayPort $GatewayPort. Logs: $studioLogRoot"
} finally {
  if (-not $studioSucceeded) {
    foreach ($studioProcess in $studioServices) { if (-not $studioProcess.HasExited) { Stop-Process -Id $studioProcess.Id } }
  }
  foreach ($studioName in $studioPrevious.Keys) { [Environment]::SetEnvironmentVariable($studioName, $studioPrevious[$studioName], 'Process') }
}
