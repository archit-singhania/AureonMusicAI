#!/bin/bash
set -e
echo "=== Aureon .NET Backend ==="
echo "Restoring packages..."
dotnet restore AureonApi/AureonApi.csproj
echo "Building..."
dotnet build AureonApi/AureonApi.csproj -c Release
echo ""
echo "Run with: dotnet run --project AureonApi/AureonApi.csproj"
echo "Swagger UI: http://localhost:5000/swagger"
