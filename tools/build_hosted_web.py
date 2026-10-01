"""Build a public static frontend only after an HTTPS gateway is mapped.

Downloads a checksum-verified official Flutter SDK on Linux when absent. No
provider or account secrets are accepted as frontend build configuration.
"""

from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OFFICIAL_RELEASES = "https://storage.googleapis.com/flutter_infra_release/flutter/"


def gateway_origin(value: str, allow_local: bool = False) -> str:
    parsed = urllib.parse.urlsplit(value.strip())
    if (
        not parsed.hostname
        or parsed.username
        or parsed.password
        or parsed.query
        or parsed.fragment
        or parsed.path not in ("", "/")
    ):
        raise ValueError(
            "API_BASE_URL must be a gateway origin without credentials, path, query, or fragment."
        )
    # Validate the public value before passing it to a Windows Flutter batch
    # launcher as well as to the compiler. Hostnames cannot carry shell syntax.
    parsed.port
    try:
        ipaddress.ip_address(parsed.hostname)
    except ValueError:
        if not re.fullmatch(r"[A-Za-z0-9.-]+", parsed.hostname):
            raise ValueError("The gateway hostname is invalid.")
    local = parsed.hostname.lower() in ("localhost", "localhost.localdomain")
    try:
        local = local or not ipaddress.ip_address(parsed.hostname).is_global
    except ValueError:
        local = local or parsed.hostname.lower().endswith((".local", ".localhost"))
    if parsed.scheme != "https" and not (
        allow_local and local and parsed.scheme == "http"
    ):
        raise ValueError(
            "Public builds require an HTTPS gateway origin; localhost is allowed only with --allow-local."
        )
    if local and not allow_local:
        raise ValueError(
            "A local gateway cannot power a public demo. Map the existing hosted gateway first."
        )
    return urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, "", "", ""))


def flutter_command() -> str:
    configured = os.environ.get("FLUTTER_CMD")
    if configured:
        if not Path(configured).is_file():
            raise ValueError(
                "FLUTTER_CMD does not point to an installed Flutter executable."
            )
        return configured
    existing = shutil.which("flutter")
    if existing:
        return existing
    if sys.platform != "linux" or platform.machine() not in ("x86_64", "AMD64"):
        raise ValueError(
            "Install Flutter on PATH or set FLUTTER_CMD. Automatic hosted bootstrap requires Linux x86_64."
        )
    version = os.environ.get("FLUTTER_VERSION", "3.47.3")
    cache = ROOT / ".hosting"
    sdk = cache / "flutter"
    marker = cache / "flutter-version"
    if (
        (sdk / "bin/flutter").exists()
        and marker.exists()
        and marker.read_text().strip() == version
    ):
        return str(sdk / "bin/flutter")
    if sdk.exists():
        raise ValueError(
            "A different cached SDK exists. Use an installed FLUTTER_CMD or a fresh build cache."
        )
    with urllib.request.urlopen(
        OFFICIAL_RELEASES + "releases_linux.json", timeout=60
    ) as response:
        manifest = json.load(response)
    release = next(
        (
            entry
            for entry in manifest["releases"]
            if entry["version"] == version
            and entry.get("channel") == "stable"
            and entry.get("dart_sdk_arch", "x64") == "x64"
        ),
        None,
    )
    if not release:
        raise ValueError(
            "The selected Flutter version is absent from the official stable Linux archive."
        )
    archive_name = release["archive"]
    if not archive_name.startswith("stable/linux/") or ".." in archive_name:
        raise ValueError("The official SDK archive metadata was unexpected.")
    cache.mkdir(exist_ok=True)
    archive = cache / "flutter-sdk.tar.xz"
    digest = hashlib.sha256()
    with (
        urllib.request.urlopen(
            OFFICIAL_RELEASES + archive_name, timeout=120
        ) as response,
        archive.open("wb") as output,
    ):
        while chunk := response.read(1024 * 1024):
            digest.update(chunk)
            output.write(chunk)
    if digest.hexdigest() != release["sha256"]:
        archive.unlink(missing_ok=True)
        raise ValueError(
            "Flutter SDK checksum verification failed; extraction was refused."
        )
    with tarfile.open(archive) as bundle:
        # Python's data filter rejects traversal and links outside the cache.
        bundle.extractall(cache, filter="data")
    archive.unlink()
    marker.write_text(version)
    return str(sdk / "bin/flutter")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gateway-url", default=os.environ.get("API_BASE_URL", ""))
    parser.add_argument(
        "--allow-local",
        action="store_true",
        help="Local verification only; never use for a public deployment.",
    )
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument(
        "--skip-pub",
        action="store_true",
        help="Use already resolved workspace dependencies; intended for verified local build caches.",
    )
    options = parser.parse_args()
    try:
        origin = gateway_origin(options.gateway_url, options.allow_local)
        if options.validate_only:
            print(
                "Frontend gateway configuration is valid; no build or deployment was performed."
            )
            return 0
        flutter = flutter_command()
        workspace = ROOT / "flutter_app/aureon"
        if options.skip_pub:
            if not (workspace / ".dart_tool/package_config.json").exists():
                raise ValueError(
                    "Resolve Flutter dependencies before using --skip-pub."
                )
        else:
            subprocess.run([flutter, "pub", "get"], cwd=workspace, check=True)
        subprocess.run(
            [
                flutter,
                "build",
                "web",
                "--release",
                "--no-wasm-dry-run",
                "--no-pub",
                "--dart-define=API_BASE_URL=" + origin,
            ],
            cwd=workspace,
            check=True,
        )
        print(
            "Static frontend built. Hosting destination/linkage must be verified before deployment."
        )
        return 0
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
