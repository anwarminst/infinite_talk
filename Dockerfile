# use specified CUDA base image
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04

# Set Python version
ENV PYTHON_VERSION=3.11

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    supervisor \
    git \
    ffmpeg \
    software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.11 python3.11-venv python3.11-dev && \
    rm -rf /var/lib/apt/lists/*

# Set Python 3.11 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1

# Install pip for Python 3.11
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11

# Update pip
RUN python -m pip install --upgrade pip

# Install Python packages with specific versions
RUN pip install --no-cache-dir \
    runpod==1.6.0 \
    python-dotenv==1.0.0 \
    requests==2.31.0 \
    Pillow==10.0.0 \
    numpy==1.24.3

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

# Create necessary directories
RUN mkdir -p /src /input /var/log

# Copy core files
WORKDIR /src
COPY handler.py rp_handler.py settings.py start_comfy.py ./
COPY nodes_name.txt ./

# Copy input directory contents (preserving directory structure)
COPY input /input

# Copy RunPod worker files
COPY runpod_worker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY runpod_worker/requirements.txt /requirements.txt
COPY runpod_worker/src/infinitetalk_workflow.json /src/

# Ensure correct permissions
RUN chmod 644 /src/* && \
    chmod 755 /src

# Install requirements (with version check to avoid conflicts)
RUN pip install --no-cache-dir -r /requirements.txt && \
    pip freeze | grep -i "runpod\|python-dotenv\|requests\|numpy\|pillow"

# Copy and set up entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create log files
RUN touch /var/log/comfyui.err.log /var/log/comfyui.out.log \
    /var/log/worker.err.log /var/log/worker.out.log && \
    chmod 666 /var/log/*.log

# Environment variables
ENV COMFYUI_API_URL="http://127.0.0.1:8188"
ENV PYTHONUNBUFFERED=1

# Verify installation
RUN python -c "import runpod; import dotenv; import requests; import numpy; import PIL; \
    print(f'Python {".".join(map(str, PIL.__version__.split(".")))} environment verified with all required packages')"

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://127.0.0.1:8188/ || exit 1

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

