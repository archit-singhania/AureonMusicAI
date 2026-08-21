Write-Host "Starting Aureon Music AI Backend Services..." -ForegroundColor Cyan

# Start Python API
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd python_audio_service; Write-Host 'Starting Python AI Core...'; pip install fastapi uvicorn aiofiles requests; python main.py" -WindowStyle Normal

# Start .NET API
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd dotnet_backend/AureonApi; Write-Host 'Starting .NET 9 API Gateway...'; dotnet run" -WindowStyle Normal

Write-Host "Backends are booting up in separate windows!" -ForegroundColor Green
Write-Host "You can now run your Flutter app."
