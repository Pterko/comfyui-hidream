# Choose an NVIDIA CUDA base image.
FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive

# Set working directory for ComfyUI
WORKDIR /opt/ComfyUI

# Install dependencies: git, python, pip, wget, netcat (for health check) and other utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    python3 \
    python3-pip \
    wget \
    netcat-openbsd \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Clone ComfyUI repository
RUN git clone https://github.com/comfyanonymous/ComfyUI.git .

# Install ComfyUI Python dependencies
RUN pip3 install --no-cache-dir -r requirements.txt \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 \
    xformers

# Install ComfyUI Manager
RUN cd custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    cd ComfyUI-Manager && \
    pip3 install --no-cache-dir -r requirements.txt

# Create directories for models (downloads will happen at runtime)
RUN mkdir -p /opt/ComfyUI/models/text_encoders \
               /opt/ComfyUI/models/vae \
               /opt/ComfyUI/models/diffusion_models \
               /opt/ComfyUI/models/checkpoints \
               /opt/ComfyUI/models/loras \
               /opt/ComfyUI/models/upscale_models

# Install Cloudflared
ARG CLOUDFLARED_VERSION=2024.5.0 # You can update this to the latest stable version
RUN wget -q https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared-linux-amd64.deb && \
    rm cloudflared-linux-amd64.deb

# Copy the entrypoint script
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

# Expose ComfyUI port (internal to Docker, Cloudflared will tunnel this)
EXPOSE 8188

# Environment variables
ENV COMFYUI_PORT=8188

ENTRYPOINT ["/opt/entrypoint.sh"]