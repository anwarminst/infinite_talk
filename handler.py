import runpod
import base64
import requests
import json
from settings import COMFYUI_API_URL, CLIENT_ID, DEFAULT_FRAME_RATE, DEFAULT_VIDEO_LENGTH

def create_workflow_payload(input_data):
    """Create the ComfyUI workflow payload with the input data"""
    
    # Extract inputs with defaults
    image_base64 = input_data.get("image")
    audio_base64 = input_data.get("audio")
    text_prompt = input_data.get("text_prompt", "A person is talking")
    video_length = int(input_data.get("video_length", DEFAULT_VIDEO_LENGTH))
    frame_rate = int(input_data.get("frame_rate", DEFAULT_FRAME_RATE))
    width = int(input_data.get("width", 640))
    height = int(input_data.get("height", 832))
    total_frames = frame_rate * video_length

    # Load the base workflow
    import os
    print(f"Current working directory: {os.getcwd()}")
    print(f"Files in /src: {os.listdir('/src')}")
    workflow_path = "/src/infinitetalk_workflow.json"
    print(f"Checking if workflow file exists: {os.path.exists(workflow_path)}")
    with open(workflow_path, "r") as f:
        workflow = json.load(f)

    # Update the workflow with input data
    payload = {
        "client_id": CLIENT_ID,
        "prompt": {
            # Width and Height Constants
            "210": {
                "inputs": {
                    "value": width
                },
                "class_type": "INTConstant"
            },
            "211": {
                "inputs": {
                    "value": height
                },
                "class_type": "INTConstant"
            },
            # MultiTalk Model Loader
            "120": {
                "inputs": {
                    "model": "Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors"
                },
                "class_type": "MultiTalkModelLoader"
            },
            # WanVideo Model Loader
            "122": {
                "inputs": {
                    "model": "Wan14Bi2vFusioniX.safetensors",
                    "base_precision": "bf16",
                    "quantization": "disabled",
                    "load_device": "main_device",
                    "attention_mode": "sdpa",
                    "block_swap_args": ["134", 0],
                    "multitalk_model": ["120", 0]
                },
                "class_type": "WanVideoModelLoader"
            },
            # Load Image
            "207": {
                "inputs": {
                    "image": image_base64,
                    "upload": "image"
                },
                "class_type": "LoadImage"
            },
            # Image Resize
            "171": {
                "inputs": {
                    "width": ["210", 0],
                    "height": ["211", 0],
                    "image": ["207", 0],
                    "upscale_method": "lanczos",
                    "keep_proportion": "pad_edge",
                    "pad_color": "0, 0, 0",
                    "crop_position": "center",
                    "divisible_by": 2,
                    "device": "cpu"
                },
                "class_type": "ImageResizeKJv2"
            },
            # Load Audio
            "217": {
                "inputs": {
                    "audio": audio_base64,
                    "upload": "audio"
                },
                "class_type": "LoadAudio"
            },
            # Text Encode
            "135": {
                "inputs": {
                    "positive_prompt": text_prompt,
                    "negative_prompt": "bright tones, overexposed, static, blurred details, poor quality",
                    "force_offload": True,
                    "use_disk_cache": False,
                    "device": "gpu",
                    "t5": ["136", 0]
                },
                "class_type": "WanVideoTextEncode"
            },
            # Audio Crop
            "159": {
                "inputs": {
                    "start_time": "0:00",
                    "end_time": f"0:{video_length}",
                    "audio": ["217", 0]
                },
                "class_type": "AudioCrop"
            },
            # MultiTalk Wav2Vec Embeds
            "194": {
                "inputs": {
                    "normalize_loudness": True,
                    "num_frames": total_frames,
                    "fps": frame_rate,
                    "audio_scale": 1.2,
                    "audio_cfg_scale": 1.2,
                    "multi_audio_type": "add",
                    "wav2vec_model": ["137", 0],
                    "audio_1": ["170", 3]
                },
                "class_type": "MultiTalkWav2VecEmbeds"
            }
        }
    }

    return payload

def handler(event):
    """Handle the RunPod event"""
    try:
        # Validate input
        if not event.get("input"):
            return {"error": "No input provided"}

        input_data = event["input"]
        required_fields = ["image", "audio"]
        
        for field in required_fields:
            if field not in input_data:
                return {"error": f"Missing required field: {field}"}

        # Create workflow payload
        payload = create_workflow_payload(input_data)

        # Send request to ComfyUI
        response = requests.post(
            f"{COMFYUI_API_URL}/queue/prompt",
            json=payload,
            headers={"Content-Type": "application/json"}
        )

        if response.status_code != 200:
            return {
                "error": f"ComfyUI API error: {response.status_code}",
                "details": response.text
            }

        result = response.json()
        
        return {
            "prompt_id": result.get("prompt_id"),
            "status": "success",
            "output": result
        }

    except Exception as e:
        return {"error": str(e)}

runpod.serverless.start({"handler": handler})
