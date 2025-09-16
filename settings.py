import os
from dotenv import load_dotenv

load_dotenv()

# ComfyUI API endpoint - get from environment variable with a fallback
COMFYUI_API_URL = os.getenv('COMFYUI_API_URL')
if COMFYUI_API_URL is None:
    raise ValueError("COMFYUI_API_URL environment variable is not set")
CLIENT_ID = "9f1c4011d72e415e9cbd9be0b3a859fc"

# Default values
DEFAULT_FRAME_RATE = 25
DEFAULT_VIDEO_LENGTH = 21  # seconds
