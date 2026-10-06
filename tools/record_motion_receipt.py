"""Record current source/build evidence without changing Git state."""
from pathlib import Path
import hashlib
import json
import re
import zipfile
from datetime import datetime, timezone

root = Path(__file__).resolve().parents[1]
app = root / "flutter_app/aureon"

def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()

def artifact(path):
    stat = path.stat()
    return {"path": str(path), "bytes": stat.st_size,
            "modified_utc": datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat(),
            "sha256": digest(path)}

def log(name):
    return (root / ".tools" / name).read_text(encoding="utf-8-sig", errors="replace")

analyzer = log("aureon-motion-analyze.log")
tests = log("aureon-motion-tests.log")
web = log("aureon-motion-web-build.log")
android = log("aureon-motion-android-build.log")
visual_path = root / "docs/screenshots/premium-motion-2026-10-06/visual-receipt.json"
visual = json.loads(visual_path.read_text(encoding="utf-8"))
feature_path = root / "docs/demo/premium-motion-feature-2026-10-06/guest-workflow-evidence.json"
feature = json.loads(feature_path.read_text(encoding="utf-8"))
js = artifact(app / "build/web/main.dart.js")
apk_path = app / "build/app/outputs/apk/debug/app-debug.apk"
apk = artifact(apk_path)
with zipfile.ZipFile(apk_path) as archive:
    kernel = archive.read("assets/flutter_assets/kernel_blob.bin")
    apk["has_emulator_origin"] = b"http://10.0.2.2:5000" in kernel
    apk["has_motion_and_palettes"] = all(value in kernel for value in [b"StudioSections", b"StudioEntrance", b"Copper", b"Tide"])
    apk["manrope_matches_source"] = hashlib.sha256(archive.read("assets/flutter_assets/assets/fonts/Manrope-Variable.ttf")).hexdigest() == digest(app / "assets/fonts/Manrope-Variable.ttf")
count = re.search(r"\+(\d+): All tests passed", tests)
seconds = re.search(r"Compiling lib.*?([\d.]+)s", web)
tasks = re.search(r"(\d+) actionable tasks: (.*)", android)
sources = ["lib/main.dart", "lib/studio_ui.dart", "lib/studio_model.dart", "lib/studio_theme.dart", "lib/studio_motion.dart", "lib/liquid_glass.dart", "test/studio_motion_test.dart"]
receipt = {
    "date_utc": datetime.now(timezone.utc).isoformat(),
    "analyzer": "No issues found" if "No issues found" in analyzer else "Review log",
    "flutter_tests_passed": int(count.group(1)) if count else None,
    "web_build_passed": "Built build" in web,
    "web_build_seconds": float(seconds.group(1)) if seconds else None,
    "android_build_passed": "BUILD SUCCESSFUL" in android,
    "android_build_summary": tasks.group(0) if tasks else None,
    "android_environment": "Prepared Flutter SDK; JDK 21; existing project Gradle cache; assembleDebug --offline --no-daemon",
    "web": js, "android_apk": apk,
    "source_sha256": {name: digest(app / name) for name in sources},
    "visual": {"receipt": str(visual_path.relative_to(root)), "checks": len(visual["checks"]),
        "captures": len(visual["captures"]), "page_errors": visual["page_errors"], "failure": visual["failure"],
        "matches_current_js": visual["main_js_sha256"] == js["sha256"], "actual_job_states": visual["actual_job_states"],
        "inspected": ["welcome-iris.png", "library-retained-search.png", "settings-copper-light.png", "settings-tide-dark.png", "phone-master-normal.png", "phone-master-comfort.png", "phone-settings-comfort.png", "sheet-open.png", "phone-sheet-entering.png", "phone-sheet-open.png", "consent-keyboard-focus.png"],
        "screenshot_sha256": {name: digest(visual_path.parent / name) for name in visual["captures"]}},
    "feature_journey": {"receipt": str(feature_path.relative_to(root)), "steps_passed": len(feature["completed"]),
        "page_errors": feature["page_errors"], "failure": feature["failure"], "completed_jobs": feature["completed_jobs"],
        "download_responses": feature["download_responses"], "frame_sample": feature["frame_sample"]},
    "limitations": ["Headless Chrome frame scheduling and visual captures do not establish native GPU performance.", "Android compilation passed; native device execution was not performed."],
    "manual_expectations": "See PREMIUM-MOTION-2026-10-06.md. Motion is brief, layout remains stable, all palette/comfort choices persist, real progress and playback remain authoritative.",
}
target = root / "docs/PREMIUM-MOTION-2026-10-06.json"
target.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"receipt": str(target), "tests": receipt["flutter_tests_passed"], "web_sha256": js["sha256"], "apk_sha256": apk["sha256"], "current_visual": receipt["visual"]["matches_current_js"], "feature_steps": receipt["feature_journey"]["steps_passed"]}, indent=2))
