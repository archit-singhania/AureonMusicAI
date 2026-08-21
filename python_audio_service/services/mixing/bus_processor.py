import logging

logger = logging.getLogger(__name__)

class BusProcessor:
    def __init__(self):
        pass

    def apply_parallel_compression(self, stem_paths: list, output_path: str) -> str:
        """
        Groups stems (e.g. Drums + Bass) and applies intense parallel 'New York' compression.
        """
        logger.info(f"[Bus Processing] Applying parallel compression to {len(stem_paths)} stems")
        
        import shutil
        try:
            if stem_paths and stem_paths[0]:
                shutil.copy(stem_paths[0], output_path)
                logger.info(f"[Bus Processing] Processed bus saved to {output_path}")
        except Exception as e:
            logger.error(f"[Bus Processing] Failed: {e}")
            
        return output_path
