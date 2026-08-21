import os
import asyncio
import logging

logger = logging.getLogger(__name__)

class MusicGenService:
    def __init__(self):
        self.is_loaded = False

    async def generate_beat(self, prompt: str, output_path: str, duration: int = 15) -> str:
        """
        Generates an instrumental track using Meta's AudioCraft (MusicGen).
        Zero-Cost Stub: Mocks generation to prevent freezing without a GPU.
        """
        logger.info(f"[MusicGen] Generating {duration}s beat for prompt: '{prompt}'")
        
        # Simulate MusicGen generation time (usually ~1s per second of audio on GPU)
        await asyncio.sleep(3.0)
        
        # Mock: Create a simple sine wave or copy a preset beat to output_path
        # For stubbing, we generate 1 second of silence/tone using FFmpeg
        import subprocess
        try:
            cmd = [
                'ffmpeg', '-y', '-f', 'lavfi', '-i', f'sine=frequency=100:duration={duration}',
                '-acodec', 'pcm_s16le', '-ar', '44100', '-ac', '2', output_path
            ]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            logger.info(f"[MusicGen] Generation complete. Saved to {output_path}")
        except Exception as e:
            logger.error(f"[MusicGen] Failed to generate stub beat: {e}")
            
        return output_path
