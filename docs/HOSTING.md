# Hosting Aureon on an existing account

## Discovered targets

The repository establishes only `git@github.com:archit-singhania/AureonMusicAI.git`. It contains no linked Vercel/Netlify/Firebase project IDs and no hosted web or .NET gateway domain. Existing account/project mapping is required before deployment; no target name has been invented and no deployment has been made.

The local URLs (`localhost:3005`, `localhost:5000`, and `localhost:8103`) are development targets. The current local web artifact contains a localhost gateway URL and must be rebuilt before public hosting.

## Static frontend

Root `vercel.json` and `netlify.toml` build the Flutter app and publish `flutter_app/aureon/build/web`, with SPA routing that preserves real static files. The `web/` directory also contains Vercel artifact routing and Netlify `_redirects`/`_headers`, copied into future Flutter builds for deploying a prebuilt static directory. No provider account/project identifiers are stored in these configs.

Set `API_BASE_URL` to the **mapped public HTTPS .NET gateway origin**, without a path, trailing slash, credentials, or query. This value is public in the compiled client. Never put database passwords, internal keys, Sarvam keys, AWS credentials, account tokens, or private worker addresses into frontend environment values or Dart defines.

Hosted build command:

```sh
python3 tools/build_hosted_web.py
```

The builder uses Flutter on PATH or `FLUTTER_CMD`. On a fresh Linux x86_64 builder it downloads `FLUTTER_VERSION` (default 3.47.3) from the official stable SDK archive, verifies the archive SHA256, and extracts it under ignored `.hosting/`. It refuses an unset, local, credential-bearing, or non-HTTPS public gateway. The cloud SDK bootstrap has not been executed in this workspace; a missing official release or builder resource limit fails explicitly.

On the verified Windows workspace, `FLUTTER_CMD` can point to the installed `flutter.bat`. Use `--skip-pub` only with the already resolved dependency cache when Windows Developer Mode symlinks are unavailable. The script still builds with `--no-pub` after dependency resolution. For local-only verification, `--allow-local --gateway-url http://localhost:5000` is available and must never be used for public deployment.

Map the existing provider project and account before publishing a build. For a provider CLI upload, select the existing project explicitly and deploy the freshly built static directory. Do not let a CLI create an unrelated project, change a custom domain, or substitute a localhost artifact.

## Runtime environment mapping

| Location | Required configuration |
|---|---|
| Static frontend build | `API_BASE_URL`: mapped HTTPS .NET gateway origin. `FLUTTER_VERSION` and optional installed `FLUTTER_CMD` configure SDK only. |
| .NET gateway | `AudioService__BaseUrl`: private reachable Python service URL; `AUREON_INTERNAL_KEY`: same private outbox key as Python; `AllowedOrigins`: exact public frontend origins, comma-separated. Preserve WebSocket support for `/hub/music`. |
| Python worker/API | Persistent `AUREON_DATA_DIR` or mounted data volume; private `AUREON_INTERNAL_KEY`; `DATABASE_URL` for managed Postgres or persistent SQLite. `AUREON_ORIGINS` should list permitted origins if Python is directly reachable. |
| Optional queue | `REDIS_URL` to the existing private Redis instance. Database queue remains authoritative without it. |
| Optional private object storage | `S3_BUCKET`, `S3_ENDPOINT`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, configured only on Python. Keep bucket objects private. |
| Optional speech/lyrics | `SARVAM_API_KEY`, `OLLAMA_URL`, `OLLAMA_MODEL`, configured only on Python. Missing providers remain visibly gated; the original instrumental workflow works without them. |

The static hosting configs serve the frontend. The .NET gateway, durable Python DSP worker, database and private media need suitable long-running/container services on the mapped existing hosting account. Existing Dockerfiles and Compose define that runtime boundary. A static deployment alone cannot provide music generation or collaboration. Keep internal workers/databases private, persistent media/signing keys intact, and align service ports with the selected provider.

## Acceptance after mapping

1. Verify the selected account/project IDs and domain ownership, then rebuild with the actual HTTPS gateway origin.
2. Confirm the gateway `/health` and `/api/v1/capabilities` endpoints, and CORS response for the exact public frontend origin.
3. Exercise authenticated WSS `/hub/music` negotiation/events, not merely the static welcome page.
4. On the public HTTPS frontend, use a fresh guest fixture to generate an original composition, play real audio, change/render the mix, reopen the session, and download a decodable WAV. Microphone capture requires HTTPS and browser permission.
5. Verify database/media persistence across a service restart and private asset access. Keep provider, storage, and model requirements honest in the capability screen.

Configuration references: [Vercel project configuration](https://vercel.com/docs/project-configuration), [Netlify file-based configuration](https://docs.netlify.com/build/configure-builds/file-based-configuration/), and [Flutter web deployment](https://docs.flutter.dev/deployment/web).
