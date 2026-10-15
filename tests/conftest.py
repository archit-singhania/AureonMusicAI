"""Select isolated storage before any test module imports service settings."""
import os
from pathlib import Path
from tempfile import TemporaryDirectory

_data = TemporaryDirectory(prefix="aureon-suite-", ignore_cleanup_errors=True)
os.environ["AUREON_DATA_DIR"] = _data.name
os.environ["DATABASE_URL"] = "sqlite:///" + (Path(_data.name) / "studio.db").as_posix()
os.environ["AUREON_INTERNAL_KEY"] = "isolated-test-internal-key"
