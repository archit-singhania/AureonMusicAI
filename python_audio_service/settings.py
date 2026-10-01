"""One storage/configuration boundary for API, workers and exports."""
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = Path(os.getenv('AUREON_DATA_DIR', str(ROOT / 'data'))).resolve()
DATA.mkdir(parents=True, exist_ok=True)
ASSETS = DATA / 'assets'
ASSETS.mkdir(exist_ok=True)
DATABASE_URL = os.getenv('DATABASE_URL', f'sqlite:///{DATA / "studio.db"}')
REDIS_URL = os.getenv('REDIS_URL', '')
INTERNAL_KEY = os.getenv('AUREON_INTERNAL_KEY', '')
MAX_UPLOAD = 50 * 1024 * 1024
MAX_DURATION = 180
ORIGINS = os.getenv('AUREON_ORIGINS', 'http://localhost:3005,http://localhost:8080').split(',')

