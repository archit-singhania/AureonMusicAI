param([string]$Python = "python", [string]$Dotnet = "dotnet")
$ErrorActionPreference = "Stop"
$studioRoot = $PSScriptRoot
if (-not $env:AUREON_INTERNAL_KEY) { $env:AUREON_INTERNAL_KEY = [Guid]::NewGuid().ToString("N") + [Guid]::NewGuid().ToString("N") }
Start-Process -FilePath $Python -ArgumentList @("-m", "uvicorn", "main:app", "--host", "127.0.0.1", "--port", "8103") -WorkingDirectory (Join-Path $studioRoot "python_audio_service") -WindowStyle Hidden
Start-Process -FilePath $Dotnet -ArgumentList @("run", "--project", "dotnet_backend/AureonApi", "--urls", "http://localhost:5000") -WorkingDirectory $studioRoot -WindowStyle Hidden
Write-Output "Studio services started. Run Flutter with --dart-define=API_BASE_URL=http://localhost:5000."

