FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY ["AureonApi/AureonApi.csproj", "AureonApi/"]
RUN dotnet restore "AureonApi/AureonApi.csproj"
COPY . .
WORKDIR "/src/AureonApi"
RUN dotnet build "AureonApi.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "AureonApi.csproj" -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
COPY --from=publish /app/publish .
EXPOSE 5000
ENTRYPOINT ["dotnet", "AureonApi.dll"]
