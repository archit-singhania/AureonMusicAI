"""Private file profile with optional S3-compatible durability.

Workers retain their local rendering cache. No public bucket is required.
"""
import os
from pathlib import Path
from settings import ASSETS

def client():
    if not os.getenv('S3_BUCKET'): return None
    import boto3
    return boto3.client('s3',endpoint_url=os.getenv('S3_ENDPOINT') or None,region_name=os.getenv('AWS_DEFAULT_REGION','us-east-1'))

def persist(path):
    remote=client()
    if remote:
        key=Path(path).resolve().relative_to(ASSETS).as_posix()
        remote.upload_file(str(path),os.environ['S3_BUCKET'],key)

def recover(path):
    remote=client()
    if remote and not Path(path).exists():
        key=Path(path).resolve().relative_to(ASSETS).as_posix()
        Path(path).parent.mkdir(parents=True,exist_ok=True)
        remote.download_file(os.environ['S3_BUCKET'],key,str(path))
