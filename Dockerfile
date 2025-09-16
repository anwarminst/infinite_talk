# use specified CUDA base image
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04

# Set Python version
ENV PYTHON_VERSION=3.11
# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    supervisor \
    python3 \
    python3-pip \
    python-is-python3 \
    git && \
    rm -rf /var/lib/apt/lists/*

# Update pip
RUN python3 -m pip install --upgrade pip

# Install Python packages
RUN pip install --no-cache-dir runpod python-dotenv requests Pillow numpy

WORKDIR /
# Clone ComfyUI and set up
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd /ComfyUI && \
    pip install -r requirements.txt

RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/Comfy-Org/ComfyUI-Manager.git && \
    cd ComfyUI-Manager && \
    pip install -r requirements.txt

# Install ComfyUI custom nodes
RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/kijai/ComfyUI-KJNodes && \
    cd ComfyUI-KJNodes && \
    pip install -r requirements.txt

RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper && \
    cd ComfyUI-WanVideoWrapper && \
    pip install -r requirements.txt

RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/christian-byrne/audio-separation-nodes-comfyui && \
    cd audio-separation-nodes-comfyui && \
    pip install -r requirements.txt

RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite && \
    cd ComfyUI-VideoHelperSuite && \
    pip install -r requirements.txt

# Create model directories
RUN mkdir -p /ComfyUI/models/diffusion_models && \
    mkdir -p /ComfyUI/models/clip_vision && \
    mkdir -p /ComfyUI/models/text_encoders && \
    mkdir -p /ComfyUI/models/vae

# Download required models
WORKDIR /ComfyUI/models/diffusion_models
# Download Image-to-Video diffusion model
RUN wget -O Wan14Bi2vFusioniX.safetensors \
    https://huggingface.co/vrgamedevgirl84/Wan14BT2VFusioniX/resolve/main/Wan14Bi2vFusioniX.safetensors

# Download Audio-to-Video diffusion model (InfiniteTalk head)
RUN wget -O Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors \
    https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors

WORKDIR /ComfyUI/models/clip_vision
# Download CLIP-Vision
RUN wget -O clip_vision_h.safetensors \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors?download=true"

WORKDIR /ComfyUI/models/text_encoders
# Download T5 text encoder
RUN wget -O umt5-xxl-enc-fp8_e4m3fn.safetensors \
    https://huggingface.co/Kijai/WanVideo_comfy/resolve/431c404152d2f589da0326f6b86063f62a6b155c/umt5-xxl-enc-fp8_e4m3fn.safetensors

WORKDIR /ComfyUI/models/vae
# Download VAE
RUN wget -O wan_2.1_vae.safetensors \
    https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors

# Set up RunPod worker
WORKDIR /
# Create src directory
RUN mkdir -p /src

# Copy all necessary Python files
COPY handler.py /src/handler.py
COPY rp_handler.py /src/rp_handler.py
COPY settings.py /src/settings.py
COPY start_comfy.py /src/start_comfy.py
COPY nodes_name.txt /src/nodes_name.txt


# Copy RunPod worker files
COPY runpod_worker/src /src
COPY runpod_worker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY runpod_worker/requirements.txt /requirements.txt
RUN pip install -r /requirements.txt

# Copy workflow and other files
COPY runpod_worker/src/infinitetalk_workflow.json /src/infinitetalk_workflow.json
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV COMFYUI_API_URL="http://127.0.0.1:8188"
ENV PYTHONUNBUFFERED=1

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

