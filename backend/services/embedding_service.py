from langchain_together import TogetherEmbeddings
from config.settings import settings
from typing import List
from utils.logger import logger
import os
import asyncio
import requests
from concurrent.futures import ThreadPoolExecutor


class EmbeddingService:
    """
    High-performance embedding service with dedicated thread pool.

    Optimizations:
    - Dedicated thread pool (not shared default executor)
    - Configurable worker count for parallel API calls
    - Connection reuse via persistent client
    """

    # Optimal workers for I/O-bound embedding API calls
    MAX_WORKERS = 10

    def __init__(self):
        os.environ["TOGETHER_API_KEY"] = settings.TOGETHER_API_KEY
        
        # Validate API key before initializing
        self._validate_api_key()
        
        self.embeddings = TogetherEmbeddings(
            model=settings.EMBEDDING_MODEL, together_api_key=settings.TOGETHER_API_KEY
        )
        # Dedicated thread pool for embedding calls - much faster than default
        self._executor = ThreadPoolExecutor(
            max_workers=self.MAX_WORKERS, thread_name_prefix="embedding_worker"
        )
        logger.info(f"[EmbeddingService] Initialized with {self.MAX_WORKERS} workers")
    
    def _validate_api_key(self):
        """Validate Together AI API key"""
        try:
            logger.info("[EmbeddingService] Validating Together AI API key...")
            response = requests.get(
                "https://api.together.ai/v1/models",
                headers={
                    "Authorization": f"Bearer {settings.TOGETHER_API_KEY}",
                    "Content-Type": "application/json"
                },
                timeout=10
            )
            if response.status_code == 200:
                models = response.json().get('data', [])
                model_ids = [m.get('id', '') for m in models]
                logger.info(f"[EmbeddingService] API key valid. {len(models)} models available")
                
                # Check if embedding model is available
                if settings.EMBEDDING_MODEL in model_ids:
                    logger.info(f"[EmbeddingService] Embedding model '{settings.EMBEDDING_MODEL}' is AVAILABLE")
                else:
                    logger.warning(f"[EmbeddingService] Embedding model '{settings.EMBEDDING_MODEL}' NOT found!")
                    logger.info(f"[EmbeddingService] Available embedding models: {[m for m in model_ids if 'embed' in m.lower() or 'bge' in m.lower()][:10]}")
            elif response.status_code == 401:
                logger.error("[EmbeddingService] API key INVALID (401 Unauthorized)")
            else:
                logger.warning(f"[EmbeddingService] API validation returned {response.status_code}")
        except Exception as e:
            logger.warning(f"[EmbeddingService] Could not validate API key: {e}")

    async def generate_embeddings(self, texts: List[str]) -> List[List[float]]:
        """
        Generate embeddings for a batch of texts.

        Uses dedicated thread pool for faster concurrent API calls.
        """
        try:
            if not texts:
                return []

            loop = asyncio.get_running_loop()

            # Run embedding in dedicated thread pool (Together API is sync)
            texts_copy = list(texts)
            embeddings = await loop.run_in_executor(
                self._executor,  # Use dedicated pool, not None (default)
                self.embeddings.embed_documents,
                texts_copy,
            )
            return embeddings

        except Exception as e:
            logger.error(f"Error generating embeddings: {str(e)}")
            raise

    async def generate_embedding(self, text: str) -> List[float]:
        """Generate embedding for a single text"""
        try:
            loop = asyncio.get_running_loop()
            return await loop.run_in_executor(
                self._executor,  # Use dedicated pool
                self.embeddings.embed_query,
                text,
            )
        except Exception as e:
            logger.error(f"Error generating embedding: {str(e)}")
            raise

    def shutdown(self):
        """Cleanup thread pool on shutdown"""
        if self._executor:
            self._executor.shutdown(wait=False)
            logger.info("[EmbeddingService] Thread pool shut down")


embedding_service = EmbeddingService()
