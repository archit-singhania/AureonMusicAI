$ErrorActionPreference='Stop'
$qaRoot=Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $qaRoot
$qaData=Join-Path $qaRoot ('.tools/gateway-audit-20261021-'+[guid]::NewGuid().ToString('N'))
foreach($qaPort in @(8114,5094,3094)){if(Get-NetTCPConnection -State Listen -LocalPort $qaPort -ErrorAction SilentlyContinue){throw "QA port $qaPort is already occupied"}}
New-Item -ItemType Directory -Path $qaData | Out-Null
$env:AUREON_DATA_DIR=$qaData
$env:DATABASE_URL='sqlite:///'+(Join-Path $qaData 'studio.db').Replace('\','/')
$env:AUREON_INTERNAL_KEY=[guid]::NewGuid().ToString('N')+[guid]::NewGuid().ToString('N')
$env:AUREON_ORIGINS='http://localhost:3094'
$env:AllowedOrigins=$env:AUREON_ORIGINS
$env:AudioService__BaseUrl='http://127.0.0.1:8114'
$qaWorker=$null;$qaGateway=$null;$qaWeb=$null
try{
 $qaWorker=Start-Process -FilePath (Join-Path $qaRoot '.runtime311/Scripts/python.exe') -ArgumentList @('-m','uvicorn','main:app','--host','127.0.0.1','--port','8114') -WorkingDirectory (Join-Path $qaRoot 'python_audio_service') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $qaData 'worker.log') -RedirectStandardError (Join-Path $qaData 'worker-errors.log')
 $qaGateway=Start-Process -FilePath 'D:/remaining-4-git-projs/.tooling/dotnet/dotnet.exe' -ArgumentList @((Join-Path $qaRoot '.tools/gateway-advanced-2026-10-13/AureonApi.dll'),'--urls','http://127.0.0.1:5094') -WorkingDirectory $qaRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $qaData 'gateway.log') -RedirectStandardError (Join-Path $qaData 'gateway-errors.log')
 $qaReady=$false
 for($qaAttempt=0;$qaAttempt -lt 60;$qaAttempt++){try{$qaHealth=Invoke-RestMethod http://127.0.0.1:5094/health -TimeoutSec 2;$qaAudio=Invoke-RestMethod http://127.0.0.1:8114/health -TimeoutSec 2;if($qaHealth.status -eq 'ok'){$qaReady=$true;break}}catch{}; Start-Sleep -Milliseconds 500}
 if(-not $qaReady){throw 'Isolated gateway/worker did not become ready'}
 $env:AUREON_GATEWAY_URL='http://127.0.0.1:5094'
 $qaWeb=Start-Process -FilePath (Join-Path $qaRoot '.runtime311/Scripts/python.exe') -ArgumentList @('-m','http.server','3094','--bind','127.0.0.1') -WorkingDirectory (Join-Path $qaRoot 'flutter_app/aureon/build/web') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $qaData 'web.log') -RedirectStandardError (Join-Path $qaData 'web-errors.log')
 $env:PLAYWRIGHT_MODULE='C:/Users/dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright'
 $env:AUREON_ACCEPTANCE_OUTPUT=Join-Path $qaData 'browser'
 & 'C:/Program Files/nodejs/node.exe' tools/mastering_acceptance.cjs
 if($LASTEXITCODE -ne 0){throw 'Mastering browser acceptance failed'}
 Write-Output "Evidence: $qaData"
}finally{foreach($qaProcess in @($qaWeb,$qaGateway,$qaWorker)){if($qaProcess -and -not $qaProcess.HasExited){$qaCurrent=Get-Process -Id $qaProcess.Id -ErrorAction SilentlyContinue;if($qaCurrent -and $qaCurrent.StartTime -eq $qaProcess.StartTime){Stop-Process -Id $qaProcess.Id}}}}


