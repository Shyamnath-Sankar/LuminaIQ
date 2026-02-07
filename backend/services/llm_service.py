from langchain_together import ChatTogether
from config.settings import settings
from typing import List, Dict, Any
from utils.logger import logger
import os
import requests

class LLMService:
    def __init__(self):
        os.environ['TOGETHER_API_KEY'] = settings.TOGETHER_API_KEY
        
        # Validate API key before initializing
        self._validate_api_key()
        
        self.client = ChatTogether(
            model=settings.LLM_MODEL,
            together_api_key=settings.TOGETHER_API_KEY,
            temperature=0.7 # Default temperature, can be overridden
        )
        self.model = settings.LLM_MODEL
    
    def _validate_api_key(self):
        """Validate Together AI API key by making a test request"""
        try:
            logger.info("Validating Together AI API key...")
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
                logger.info(f"API key valid. Available models: {len(models)} total")
                
                # Check if our model is available
                if settings.LLM_MODEL in model_ids:
                    logger.info(f"Model '{settings.LLM_MODEL}' is AVAILABLE")
                else:
                    logger.warning(f"Model '{settings.LLM_MODEL}' NOT found in available models!")
                    logger.info(f"Showing first 20 available models: {model_ids[:20]}")
            elif response.status_code == 401:
                logger.error("API key INVALID (401 Unauthorized)")
            elif response.status_code == 429:
                logger.warning("API rate limited (429)")
            else:
                logger.error(f"API validation failed with status {response.status_code}: {response.text}")
        except requests.exceptions.RequestException as e:
            logger.error(f"Network error during API validation: {e}")
        except Exception as e:
            logger.error(f"Error validating API key: {e}")
    
    async def chat_completion(
        self,
        messages: List[Dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 1000
    ) -> str:
        """Generate chat completion"""
        try:
            response = await self.client.ainvoke(
                messages,
                temperature=temperature,
                max_tokens=max_tokens
            )
            
            answer = response.content
            logger.info(f"Generated completion with {len(answer)} characters")
            
            return answer
            
        except Exception as e:
            logger.error(f"Error in chat completion: {str(e)}")
            raise
    
    async def chat_completion_stream(
        self,
        messages: List[Dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 1000
    ):
        """Generate streaming chat completion"""
        try:
            async for chunk in self.client.astream(
                messages,
                temperature=temperature,
                max_tokens=max_tokens
            ):
                if chunk.content:
                    yield chunk.content
                    
        except Exception as e:
            logger.error(f"Error in streaming completion: {str(e)}")
            raise

llm_service = LLMService()
