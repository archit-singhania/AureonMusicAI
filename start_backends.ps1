# Compatibility entry point; the maintained launcher verifies service readiness.
param([string]$Python = 'python', [string]$Dotnet = 'dotnet')
& (Join-Path $PSScriptRoot 'start-local.ps1') -Python $Python -Dotnet $Dotnet
