import logging
import aiohttp
import json

logger = logging.getLogger(__name__)

class LyricCoWriter:
    def __init__(self):
        self.ollama_url = "http://localhost:11434/api/generate"
        
    async def generate_lyrics(self, context: str, prompt: str) -> str:
        """
        Uses a local LLM via Ollama to generate or refine lyrics.
        """
        logger.info(f"[LyricCoWriter] Generating lyrics for: '{prompt}'")
        
        # Stub response if Ollama is not running
        stub_response = "Here are some AI generated rhymes:\n\nWalking through the neon rain,\nTrying to forget the pain,\nBut your memory is a stain,\nDriving me insane."
        
        payload = {
            "model": "llama3", 
            "prompt": f"Context: {context}\nRequest: {prompt}\nWrite high quality song lyrics.",
            "stream": False
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(self.ollama_url, json=payload, timeout=5) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        return data.get('response', stub_response)
                    else:
                        logger.warning(f"[LyricCoWriter] Ollama returned {resp.status}. Using stub.")
                        return stub_response
        except Exception as e:
            logger.warning(f"[LyricCoWriter] Ollama not reachable ({e}). Using stub.")
            return stub_response
