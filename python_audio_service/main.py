"""ASGI entrypoint. Experimental legacy modules are outside the core API."""
from studio_api import app

if __name__ == '__main__':
    import uvicorn
    uvicorn.run('main:app', host='0.0.0.0', port=8000)
